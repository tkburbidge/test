SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: Feb. 16, 2017
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_SuretyBonds] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@propertyIDs GuidCollection READONLY,
	@startDate date = null, 
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate [Date] NOT NULL,
		EndDate [Date] NOT NULL)

	CREATE TABLE #SuretyBondInfo (
		SuretyBondID uniqueidentifier,
		PropertyID uniqueidentifier,
		PropertyName nvarchar(1000),
		Unit nvarchar(100),
		PaddedUnit nvarchar(100),
		Provider nvarchar(1000),
		[Type] nvarchar(1000),
		Price money,
		Coverage money,
		PetCoverage money,
		BondHolders nvarchar(1000),
		DatePaid date,
		Notes nvarchar(4000))

	INSERT #PropertiesAndDates 
		SELECT	pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	INSERT INTO #SuretyBondInfo
		SELECT
			sb.SuretyBondID,
			p.PropertyID,
			p.Name,
			u.Number,
			u.PaddedNumber,
			sb.ProviderName,
			sb.[SuretyBondType],
			sb.Price,
			sb.Coverage,
			sb.PetCoverage,
			NULL,
			sb.PaidDate,
			sb.Notes
		FROM SuretyBond sb
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = sb.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN Property p ON p.PropertyID = b.PropertyID
			INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
		WHERE sb.AccountID = @accountID
		  AND sb.PaidDate >= #pad.StartDate
		  AND sb.PaidDate <= #pad.EndDate

		UPDATE #SuretyBondInfo SET BondHolders = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
															FROM Person p
																INNER JOIN SuretyBondPerson sbp ON p.PersonID = sbp.PersonID														 
															WHERE sbp.SuretyBondID = #SuretyBondInfo.SuretyBondID														   
															FOR XML PATH ('')), 1, 2, '')

	SELECT * 
	FROM #SuretyBondInfo
	ORDER BY PropertyName, PaddedUnit
	
END

GO
