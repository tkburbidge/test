SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[RPT_AFF_UnitDemographics]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@effectiveDate datetime,
	@propertyIDs GuidCollection READONLY
AS

DECLARE @accountingPeriodID uniqueidentifier = null

BEGIN


	CREATE TABLE #MyProperties (
		PropertyID uniqueidentifier not null
	)

	CREATE TABLE #LeasesAndUnits (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(50) null,
		OccupiedUnitLeaseGroupID uniqueidentifier null,
		OccupiedLastLeaseID uniqueidentifier null,
		OccupiedMoveInDate date null,
		OccupiedNTVDate date null,
		OccupiedMoveOutDate date null,
		OccupiedIsMovedOut bit null,
		PendingUnitLeaseGroupID uniqueidentifier null,
		PendingLeaseID uniqueidentifier null,
		PendingApplicationDate date null,
		PendingMoveInDate date null)

	CREATE TABLE #Person(
		PersonID uniqueIdentifier,
		UnitNumber nvarchar(20),
		BuildingName nvarchar(15),
		PropertyName nvarchar(50),
		FirstName nvarchar(30),
		LastName varchar(20),
		HouseholdStatus nvarchar(30),
		Birthdate datetime,
		SSNDisplay nvarchar(200),
		Race int,
		Ethnicity int,
		Disabled bit,
		Elderly bit,
		FullTimeStudent bit,
		CertEffectiveDate datetime,
		UnitID uniqueIdentifier,
		PropertyID uniqueIdentifier,
		)


	INSERT #MyProperties
		SELECT Value FROM @propertyIDs

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @effectiveDate, @accountingPeriodID, @propertyIDs	

	SELECT	#lau.PropertyID,
			prop.Name AS 'PropertyName',
			u.UnitID,
			u.Number AS 'UnitNumber',
			u.PaddedNumber AS 'PaddedUnitNumber',
			pl.LeaseID,
			per.PersonID,
			per.LastName + ', ' + per.PreferredName AS 'ResidentName',
			pl.HouseholdStatus AS 'Status',
			per.Birthdate,
			DATEDIFF(YEAR, per.Birthdate, @effectiveDate) AS 'Age',
			ISNULL(per.SSNDisplay, affPer.AlienRegistrationDisplay) AS 'SSN',
			affPer.Race,
			affPer.Ethnicity,
			CASE WHEN (affPer.DisabledHearing = 1 OR affPer.DisabledMobility = 1 OR affPer.DisabledRefused = 1 OR affPer.DisabledVisual = 1 OR affPer.DisabledMental = 1) THEN CAST(1 AS bit)
				 ELSE CAST(0 AS bit)
				 END AS 'Disabled',
			affPer.Elderly,
			affPer.FullTimeStudent,
			(SELECT SUM(CASE WHEN (sal.SalaryPeriod = 'Monthly') THEN sal.Amount * 12
							 WHEN (sal.SalaryPeriod = 'Weekly') THEN sal.Amount * 52
							 ELSE sal.Amount END)
				FROM Salary sal
					INNER JOIN Employment emp ON sal.EmploymentID = emp.EmploymentID AND pl.PersonID = emp.PersonID
				WHERE emp.StartDate <= @effectiveDate  OR (emp.StartDate IS NULL)
				  AND ((emp.EndDate >= @effectiveDate) OR (emp.EndDate IS NULL))) AS 'Income',
			(SELECT STUFF((SELECT ', ' + Employer
							  FROM Employment
							  WHERE PersonID = per.PersonID
							  FOR XML PATH ('')), 1, 2, '')) AS 'Employer'
		FROM #LeasesAndUnits #lau
			--CROSS APPLY GetCertificationIDByUnitID(#lau.UnitID, @effectiveDate, 0) [Certs]
			--INNER JOIN Certification certif ON #lau.UnitID = certif.UnitID
			INNER JOIN PersonLease pl ON #lau.OccupiedLastLeaseID = pl.LeaseID
			INNER JOIN Person per ON pl.PersonID = per.PersonID
			INNER JOIN AffordablePerson affPer ON per.PersonID = affPer.PersonID
			INNER JOIN Unit u ON #lau.UnitID = u.UnitID
			INNER JOIN Property prop ON #lau.PropertyID = prop.PropertyID
			--LEFT JOIN Employment emp ON per.PersonID = emp.PersonID AND emp.StartDate < @effectiveDate
			--												AND ((emp.EndDate IS NULL) OR (emp.EndDate >= @effectiveDate))
		WHERE pl.ResidencyStatus NOT IN ('Cancelled', 'Denied')
		ORDER BY #lau.PropertyID, u.PaddedNumber, 'ResidentName'

END
GO
