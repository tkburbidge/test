SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 12, 2016
-- Description:	Gets Credit Builder Subscribers
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRTY_GetCreditBuilderSubscibers] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    CREATE TABLE #CreditBuildingPeeps (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(100) null,
		Unit nvarchar(50) null,
		PaddedUnit nvarchar(100) null,
		LeaseID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		[Name] nvarchar(500) null,
		PhoneNumber nvarchar(50) null,
		Email nvarchar(250) null,
		DateSubscribed date null,
		EndDate date null,
		NumberOnTimePayments int null,
		SubscriptionMethod nvarchar(250) null)

	CREATE TABLE #MyProperties (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(500) null,
		MinimumApplicantAge int null,
		MinBirthdate date null)

	IF (@date IS NULL)
	BEGIN
		SET @date = (SELECT GETDATE())
	END

	INSERT #MyProperties
		SELECT	pIDs.Value,
				prop.Name,
				prop.MinimumApplicantAge,
				DATEADD(YEAR, -prop.MinimumApplicantAge, @date)
			FROM @propertyIDs pIDs
				INNER JOIN Property prop ON pIDs.Value = prop.PropertyID

	INSERT #CreditBuildingPeeps
		SELECT	#myProp.PropertyID,
				#myProp.PropertyName,
				u.Number AS 'Unit',
				u.PaddedNumber,
				l.LeaseID,
				per.PersonID,
				per.PreferredName + ' ' + per.LastName AS 'Name',
				per.Phone1 AS 'PhoneNumber',
				per.Email,
				CASE 
					WHEN (crp.IsActive = 1) THEN crp.StartDate
					ELSE null END AS 'DateSubscribed',
				crp.EndDate,
				(SELECT DATEDIFF(MONTH, firstL.LeaseStartDate, @date) + 1
				 -
				 (SELECT COUNT(DISTINCT ULGAPInformationID)
					FROM ULGAPInformation
					WHERE ObjectID = ulg.UnitLeaseGroupID
					  AND Late = 1)) AS 'NumberOnTimePayments',
				crp.SubscriptionSource AS 'SubscriptionMethod' --still waiting for this column
			FROM UnitLeaseGroup ulg
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID 
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #MyProperties #myProp ON ut.PropertyID = #myProp.PropertyID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')
				INNER JOIN Lease firstL ON ulg.UnitLeaseGroupID = firstL.UnitLeaseGroupID AND firstL.LeaseID = (SELECT TOP 1 LeaseID
																													FROM Lease 
																													WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																													ORDER BY LeaseStartDate)
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ResidencyStatus IN ('Current', 'Under Eviction')
				INNER JOIN Person per ON pl.PersonID = per.PersonID AND per.Birthdate <= #myProp.MinBirthdate
				INNER JOIN CreditReportingPerson crp ON per.PersonID = crp.PersonID
			WHERE crp.IntegrationPartnerItemID = 247 --CB_Premium IntegrationPartnerItemID
			  AND crp.IsActive = 1

	SELECT *
		FROM #CreditBuildingPeeps
		ORDER BY PropertyName, PaddedUnit, Name

END
GO
