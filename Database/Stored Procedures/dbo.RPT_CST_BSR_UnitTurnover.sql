SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_CST_BSR_UnitTurnover]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null,
	@monthsBack int = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #Properties (
		PropertyID uniqueidentifier NOT NULL,
		PropEndDate [Date] NULL)
		
	INSERT #Properties
		SELECT Value, pap.EndDate FROM @propertyIDs p
			INNER JOIN PropertyAccountingPeriod pap ON p.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			
		
	CREATE TABLE #PropertiesAndDates (
		PropertyAccountingPeriodID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		DatePartInt int not null,
		Closed bit not null,
		StartDate date not null,
		EndDate date not null)
		
	DECLARE @minEndDate DATE = (SELECT TOP 1 DATEADD(MONTH, (-1 * (@monthsBack - 1)), CAST(DATEPART(Year, ap.EndDate) AS nvarchar(4)) + '-' + CAST(DATEPART(MONTH, ap.EndDate) AS nvarchar(4)) + '-1')
								FROM AccountingPeriod ap
								WHERE ap.AccountingPeriodID = @accountingPeriodID)

	INSERT #PropertiesAndDates 
		SELECT TOP ((SELECT COUNT(*) FROM #Properties) * @monthsBack) pap1.PropertyAccountingPeriodID, pap1.PropertyID, DATEPART(MONTH, pap1.EndDate), pap1.Closed, pap1.StartDate, pap1.EndDate
			FROM PropertyAccountingPeriod pap1
				INNER JOIN PropertyAccountingPeriod papEnd ON papEnd.AccountingPeriodID = @accountingPeriodID AND papEnd.PropertyID = pap1.PropertyID
				INNER JOIN #Properties #p ON #p.PropertyID = pap1.PropertyID
			WHERE pap1.EndDate <= papEnd.EndDate
				AND pap1.EndDate >= @minEndDate
			ORDER BY pap1.EndDate DESC



	SELECT DISTINCT 			
			p.Name AS 'PropertyName',
			p.PropertyID,	
			ap.EndDate 'PeriodEndDate',
			COUNT(DISTINCT l.LeaseID) AS 'MoveOuts'
		FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON p.PropertyID = b.PropertyID
			INNER JOIN Person per on p.RegionalManagerPersonID = per.PersonID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID		
			INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID						
			LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pl.MoveOutDate >= pap.StartDate AND pl.MoveOutDate <= pap.EndDate
			LEFT JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
			INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
		WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
								  FROM PersonLease pl2
								  WHERE pl2.LeaseID = l.LeaseID
									AND pl.ResidencyStatus IN ('Former', 'Evicted')
								  ORDER BY pl2.MoveOutDate DESC, pl2.OrderBy, pl2.PersonID)
		  AND pl.MoveOutDate >= #pad.StartDate
		  AND pl.MoveOutDate <= #pad.EndDate
		  AND pl.ResidencyStatus IN ('Former', 'Evicted')
		  AND l.LeaseStatus IN ('Former', 'Evicted')
		GROUP BY ap.EndDate, ap.Name, p.Name, p.PropertyID

END
GO
