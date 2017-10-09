SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Thomas Hutchins
-- Create date: 3/21/2017
-- =============================================

CREATE PROCEDURE [dbo].[GetDisplayablePropertyDemographics] 
	-- Add the parameters for the stored procedure here
	@accountID bigINT = 0, 
	@propertyIDs GuidCollection READONLY,
	@date DATE = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #Properties (PropertyID uniqueidentifier not null)

	INSERT #Properties SELECT Value FROM @propertyIDs
	
	CREATE TABLE #results(
		ahobjectid UNIQUEIDENTIFIER NULL,
		NumberOfPeople INT NULL,
		NumberOfMinors INT NULL, 
        NumberOfAdults INT NULL, 
        IsElderly BIT NULL,
        IsFrail BIT NULL,
        IsDisabled  BIT NULL,
        IsDisabledHearing BIT NULL,
        IsDisabledMobility BIT NULL,
        IsDisabledVisual BIT NULL,
        IsDisabledMental BIT NULL,
        IsDisplacedGovernment BIT NULL,
        IsDisplacedPrivate BIT NULL,
        IsDisplacedDisaster BIT NULL,
        IsVeteran BIT NULL,
        IsFarmworker BIT NULL,
        IsTransitional BIT NULL,
        IsLargeHousehold BIT NULL,
        Races  INT NULL, 
        Ethnicity INT NULL,
        PreviousHousing VARCHAR(MAX) NULL,
	)

	INSERT INTO #results (ahobjectid, IsDisplacedDisaster, IsDisplacedGovernment, IsDisplacedPrivate, IsFarmworker, IsLargeHousehold, IsTransitional, PreviousHousing)
		SELECT 
				ah.ObjectID,
				CASE
					WHEN (ah.DisplacedReason = 'Natural Disaster') THEN CAST(1 AS Bit)
					ELSE CAST(0 AS Bit) END AS 'IsDisplacedDisaster',
				CASE
					WHEN (ah.DisplacedReason = 'Government Action') THEN CAST(1 AS Bit)
					ELSE CAST(0 AS Bit) END AS 'IsDisplacedGovernment',
				CASE
					WHEN (ah.DisplacedReason = 'Private Action') THEN CAST(1 AS Bit)
					ELSE CAST(0 AS Bit) END AS 'IsDisplacedPrivate',
				CASE
					WHEN (ah.HouseholdType = 'Farm Worker') THEN CAST(1 AS Bit)
					ELSE CAST(0 AS Bit) END AS 'IsFarmworker',
				CASE
					WHEN (ah.HouseholdType = 'Large Household') THEN CAST(1 AS Bit)
					ELSE CAST(0 AS Bit) END AS 'IsLargeHousehold',
				CASE
					WHEN (ah.HouseholdType = 'Transitional') THEN CAST(1 AS Bit)
					ELSE CAST(0 AS Bit) END AS 'IsTransitional',
				ah.PreviousHousing
			FROM AffordableHousehold ah
				INNER JOIN Lease l ON ah.ObjectID = l.UnitLeaseGroupID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
			WHERE l.AccountID = @accountID AND
				(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 

	
	UPDATE #results SET NumberOfAdults = ISNULL((SELECT NumberOfAdults FROM (SELECT l.UnitLeaseGroupID, SUM(ap.young) AS 'NumberOfMinors', SUM(ap.old) AS 'NumberOfAdults' FROM 
			(SELECT p.personID,
					CASE
						WHEN (p.Birthdate > @date) THEN CAST(1 AS INT)
						ELSE CAST(0 AS INT) END AS 'young',
					CASE
					WHEN (p.Birthdate <= @date) THEN CAST(1 AS INT)
					ELSE CAST(0 AS INT) END AS 'old' 
				FROM affordablepersON af
					INNER JOIN PersON p ON af.PersonID = p.PersonID) ap
					INNER JOIN PersonLease pl ON ap.PersonID = pl.personID  
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
				WHERE l.AccountID = @accountID AND
					b.PropertyID IN (SELECT * FROM @propertyIDs) AND
					(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
				GROUP BY l.UnitLeaseGroupID
			) S WHERE ahobjectid = S.UnitLeaseGroupID), 0)


	UPDATE #results SET NumberOfPeople = (SELECT COUNT(*) FROM affordablepersON ap
				INNER JOIN PersonLease pl ON ap.PersonID = pl.personID 
			WHERE PL.LeaseID IN (SELECT l.LeaseID
									FROM  Lease l 
										INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
										INNER JOIN Unit u ON ulg.UnitID = u.UnitID
										INNER JOIN Building b ON u.BuildingID = b.BuildingID
										INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
									WHERE l.AccountID = @accountID AND
										(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') AND
										ahobjectid = ulg.UnitLeaseGroupID))


	UPDATE #results SET NumberOfMinors = 
		ISNULL((SELECT NumberOfMinors FROM 
			(SELECT l.UnitLeaseGroupID, SUM(ap.young) AS 'NumberOfMinors', SUM(ap.old) AS 'NumberOfAdults' FROM 
				(SELECT p.personID,
						CASE
						WHEN (p.Birthdate > @date) THEN CAST(1 AS INT)
						ELSE CAST(0 AS INT) END AS 'young',
						CASE
						WHEN (p.Birthdate <= @date) THEN CAST(1 AS INT)
						ELSE CAST(0 AS INT) END AS 'old' 
					FROM affordablepersON af
						INNER JOIN PersON p ON af.PersonID = p.PersonID) ap
						INNER JOIN PersonLease pl ON ap.PersonID = pl.personID
						INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
						INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
						INNER JOIN Unit u ON ulg.UnitID = u.UnitID
						INNER JOIN Building b ON u.BuildingID = b.BuildingID
						INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
					WHERE l.AccountID = @accountID AND
						(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
					GROUP BY l.UnitLeaseGroupID
				) S WHERE ahobjectid = S.UnitLeaseGroupID), 0)

	UPDATE #results SET IsDisabled = 
		ISNULL((SELECT IsDisabled FROM 
			(SELECT l.UnitLeaseGroupID,
					CASE
						WHEN SUM(CAST(ap.[disabled] AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabled',
					CASE
						WHEN SUM(CAST(ap.DisabledHearing AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledHearing',
					CASE
						WHEN SUM(CAST(ap.DisabledMobility AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMobility',
					CASE
						WHEN SUM(CAST(ap.DisabledVisual AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledVisual',
					CASE
						WHEN SUM(CAST(ap.DisabledMental AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMental',
					CASE
						WHEN SUM(CAST(ap.Elderly AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsElderly',
					CASE
						WHEN SUM(CAST(ap.Frail AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsFrail',
					CASE
						WHEN SUM(CAST(ap.Veteran AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsVeteran'
				FROM 
					affordablepersON ap
					INNER JOIN PersonLease pl ON ap.PersonID = pl.personID AND pl.HouseholdStatus IN ('Head of Household', 'Spouse', 'Co-Head')
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
				WHERE l.AccountID = @accountID AND
					(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
				GROUP BY l.UnitLeaseGroupID
			) S  WHERE ahobjectid = S.UnitLeaseGroupID), 0)

	UPDATE #results SET IsDisabledHearing = 
		ISNULL((SELECT IsDisabledHearing FROM 
			(SELECT l.UnitLeaseGroupID,
					CASE
						WHEN SUM(CAST(ap.[disabled] AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabled',
					CASE
						WHEN SUM(CAST(ap.DisabledHearing AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledHearing',
					CASE
						WHEN SUM(CAST(ap.DisabledMobility AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMobility',
					CASE
						WHEN SUM(CAST(ap.DisabledVisual AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledVisual',
					CASE
						WHEN SUM(CAST(ap.DisabledMental AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMental',
					CASE
						WHEN SUM(CAST(ap.Elderly AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsElderly',
					CASE
						WHEN SUM(CAST(ap.Frail AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsFrail',
					CASE
						WHEN SUM(CAST(ap.Veteran AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsVeteran'
				FROM 
					affordablepersON ap
					INNER JOIN PersonLease pl ON ap.PersonID = pl.personID AND pl.HouseholdStatus IN ('Head of Household', 'Spouse', 'Co-Head')
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
				WHERE l.AccountID = @accountID AND
					(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
				GROUP BY l.UnitLeaseGroupID
			) S  WHERE ahobjectid = S.UnitLeaseGroupID), 0)
	
	UPDATE #results SET IsDisabledMobility = 
		ISNULL((SELECT IsDisabledMobility FROM 
			(SELECT l.UnitLeaseGroupID,
					CASE
						WHEN SUM(CAST(ap.[disabled] AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabled',
					CASE
						WHEN SUM(CAST(ap.DisabledHearing AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledHearing',
					CASE
						WHEN SUM(CAST(ap.DisabledMobility AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMobility',
					CASE
						WHEN SUM(CAST(ap.DisabledVisual AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledVisual',
					CASE
						WHEN SUM(CAST(ap.DisabledMental AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMental',
					CASE
						WHEN SUM(CAST(ap.Elderly AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsElderly',
					CASE
						WHEN SUM(CAST(ap.Frail AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsFrail',
					CASE
						WHEN SUM(CAST(ap.Veteran AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsVeteran'
				FROM 
					affordablepersON ap
					INNER JOIN PersonLease pl ON ap.PersonID = pl.personID AND pl.HouseholdStatus IN ('Head of Household', 'Spouse', 'Co-Head')
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
				WHERE l.AccountID = @accountID AND
					(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
				GROUP BY l.UnitLeaseGroupID
			) S  WHERE ahobjectid = S.UnitLeaseGroupID), 0)
	
	UPDATE #results SET IsDisabledVisual = 
		ISNULL((SELECT IsDisabledVisual FROM 
			(SELECT l.UnitLeaseGroupID,
					CASE
						WHEN SUM(CAST(ap.[disabled] AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabled',
					CASE
						WHEN SUM(CAST(ap.DisabledHearing AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledHearing',
					CASE
						WHEN SUM(CAST(ap.DisabledMobility AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMobility',
					CASE
						WHEN SUM(CAST(ap.DisabledVisual AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledVisual',
					CASE
						WHEN SUM(CAST(ap.DisabledMental AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMental',
					CASE
						WHEN SUM(CAST(ap.Elderly AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsElderly',
					CASE
						WHEN SUM(CAST(ap.Frail AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsFrail',
					CASE
						WHEN SUM(CAST(ap.Veteran AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsVeteran'
				FROM 
					affordablepersON ap
					INNER JOIN PersonLease pl ON ap.PersonID = pl.personID AND pl.HouseholdStatus IN ('Head of Household', 'Spouse', 'Co-Head')
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
				WHERE l.AccountID = @accountID AND
					(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
				GROUP BY l.UnitLeaseGroupID
			) S  WHERE ahobjectid = S.UnitLeaseGroupID), 0)
	
	UPDATE #results SET IsDisabledMental = 
		ISNULL((SELECT IsDisabledMental FROM 
			(SELECT l.UnitLeaseGroupID,
					CASE
						WHEN SUM(CAST(ap.[disabled] AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabled',
					CASE
						WHEN SUM(CAST(ap.DisabledHearing AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledHearing',
					CASE
						WHEN SUM(CAST(ap.DisabledMobility AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMobility',
					CASE
						WHEN SUM(CAST(ap.DisabledVisual AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledVisual',
					CASE
						WHEN SUM(CAST(ap.DisabledMental AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMental',
					CASE
						WHEN SUM(CAST(ap.Elderly AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsElderly',
					CASE
						WHEN SUM(CAST(ap.Frail AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsFrail',
					CASE
						WHEN SUM(CAST(ap.Veteran AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsVeteran'
				FROM 
					affordablepersON ap
					INNER JOIN PersonLease pl ON ap.PersonID = pl.personID AND pl.HouseholdStatus IN ('Head of Household', 'Spouse', 'Co-Head')
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
				WHERE l.AccountID = @accountID AND
					(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
				GROUP BY l.UnitLeaseGroupID
			) S  WHERE ahobjectid = S.UnitLeaseGroupID), 0)

	UPDATE #results SET IsElderly = 
		ISNULL((SELECT IsElderly FROM 
			(SELECT l.UnitLeaseGroupID,
					CASE
						WHEN SUM(CAST(ap.[disabled] AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabled',
					CASE
						WHEN SUM(CAST(ap.DisabledHearing AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledHearing',
					CASE
						WHEN SUM(CAST(ap.DisabledMobility AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMobility',
					CASE
						WHEN SUM(CAST(ap.DisabledVisual AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledVisual',
					CASE
						WHEN SUM(CAST(ap.DisabledMental AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMental',
					CASE
						WHEN SUM(CAST(ap.Elderly AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsElderly',
					CASE
						WHEN SUM(CAST(ap.Frail AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsFrail',
					CASE
						WHEN SUM(CAST(ap.Veteran AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsVeteran'
				FROM 
					affordablepersON ap
					INNER JOIN PersonLease pl ON ap.PersonID = pl.personID AND pl.HouseholdStatus IN ('Head of Household', 'Spouse', 'Co-Head')
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
				WHERE l.AccountID = @accountID AND
					(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
				GROUP BY l.UnitLeaseGroupID
			) S  WHERE ahobjectid = S.UnitLeaseGroupID), 0)

	UPDATE #results SET IsFrail = 
		ISNULL((SELECT IsFrail FROM 
			(SELECT l.UnitLeaseGroupID,
					CASE
						WHEN SUM(CAST(ap.[disabled] AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabled',
					CASE
						WHEN SUM(CAST(ap.DisabledHearing AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledHearing',
					CASE
						WHEN SUM(CAST(ap.DisabledMobility AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMobility',
					CASE
						WHEN SUM(CAST(ap.DisabledVisual AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledVisual',
					CASE
						WHEN SUM(CAST(ap.DisabledMental AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMental',
					CASE
						WHEN SUM(CAST(ap.Elderly AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsElderly',
					CASE
						WHEN SUM(CAST(ap.Frail AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsFrail',
					CASE
						WHEN SUM(CAST(ap.Veteran AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsVeteran'
				FROM 
					affordablepersON ap
					INNER JOIN PersonLease pl ON ap.PersonID = pl.personID AND pl.HouseholdStatus IN ('Head of Household', 'Spouse', 'Co-Head')
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
				WHERE l.AccountID = @accountID AND
				(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
				GROUP BY l.UnitLeaseGroupID
			) S  WHERE ahobjectid = S.UnitLeaseGroupID), 0)

	UPDATE #results SET IsVeteran = 
		ISNULL((SELECT IsVeteran FROM 
			(SELECT l.UnitLeaseGroupID,
					CASE
						WHEN SUM(CAST(ap.[disabled] AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabled',
					CASE
						WHEN SUM(CAST(ap.DisabledHearing AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledHearing',
					CASE
						WHEN SUM(CAST(ap.DisabledMobility AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMobility',
					CASE
						WHEN SUM(CAST(ap.DisabledVisual AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledVisual',
					CASE
						WHEN SUM(CAST(ap.DisabledMental AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsDisabledMental',
					CASE
						WHEN SUM(CAST(ap.Elderly AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsElderly',
					CASE
						WHEN SUM(CAST(ap.Frail AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsFrail',
					CASE
						WHEN SUM(CAST(ap.Veteran AS INT)) > 0 THEN CAST(1 AS bit)
						ELSE CAST(0 AS bit) END AS 'IsVeteran'
				FROM 
					affordablepersON ap
					INNER JOIN PersonLease pl ON ap.PersonID = pl.personID AND pl.HouseholdStatus IN ('Head of Household', 'Spouse', 'Co-Head')
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
				WHERE l.AccountID = @accountID AND
					(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
				GROUP BY l.UnitLeaseGroupID
			) S  WHERE ahobjectid = S.UnitLeaseGroupID), 0)
	
	UPDATE #results SET Ethnicity = 
		(SELECT TOP 1 Ethnicity FROM 
			(SELECT l.UnitLeaseGroupID,
					ISNULL(ap.Ethnicity, 0) AS 'Ethnicity'
				FROM affordablepersON ap
					INNER JOIN PersonLease pl ON ap.PersonID = pl.personID AND pl.HouseholdStatus IN ('Head of Household')
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
				WHERE l.AccountID = @accountID AND
					(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
		) S  WHERE ahobjectid = S.UnitLeaseGroupID) 
		WHERE Ethnicity IS NULL

	UPDATE #results SET Ethnicity = 
		(SELECT top 1 Ethnicity FROM 
			(SELECT l.UnitLeaseGroupID,
					ISNULL(ap.Ethnicity, 0) AS 'Ethnicity'
				FROM 
					affordablepersON ap
					INNER JOIN PersonLease pl ON ap.PersonID = pl.personID AND pl.HouseholdStatus IN ('Head of Household', 'Spouse', 'Co-Head')
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
				WHERE l.AccountID = @accountID AND
					(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
		) S  WHERE ahobjectid = S.UnitLeaseGroupID) 
		WHERE Ethnicity IS NULL

	UPDATE #results SET Ethnicity = 
		(SELECT top 1 Ethnicity FROM 
			(SELECT l.UnitLeaseGroupID,
				ISNULL(ap.Ethnicity, 0) AS 'Ethnicity'
			FROM 
				affordablepersON ap
				INNER JOIN PersonLease pl ON ap.PersonID = pl.personID 
				INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
			WHERE l.AccountID = @accountID AND
				(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
		) S  WHERE ahobjectid = S.UnitLeaseGroupID) 
		WHERE Ethnicity IS NULL
	
	UPDATE #results SET Ethnicity = NULL where Ethnicity = 0

	UPDATE #results SET Races = 
	(SELECT TOP 1 Race FROM
		(SELECT l.UnitLeaseGroupID,
				ISNULL(ap.Race, 0) AS 'Race'				
			FROM 
				affordablepersON ap
				INNER JOIN PersonLease pl ON ap.PersonID = pl.personID AND pl.HouseholdStatus IN ('Head of Household')
				INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
			WHERE l.AccountID = @accountID AND
				(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
		) S  WHERE ahobjectid = S.UnitLeaseGroupID) 
		WHERE Races IS NULL

	UPDATE #results SET Races = 
		(SELECT top 1 Race FROM 
			(SELECT l.UnitLeaseGroupID,
					ISNULL(ap.Race, 0) AS 'Race'
				FROM 
					affordablepersON ap
					INNER JOIN PersonLease pl ON ap.PersonID = pl.personID AND pl.HouseholdStatus IN ('Head of Household', 'Spouse', 'Co-Head')
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
				WHERE l.AccountID = @accountID AND
					(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
			) S  WHERE ahobjectid = S.UnitLeaseGroupID)
			 WHERE Races IS NULL
	
	UPDATE #results SET Races = 
		(SELECT top 1 Race FROM 
			(SELECT l.UnitLeaseGroupID,
					ISNULL(ap.Race, 0) AS 'Race'
				FROM 
					affordablepersON ap
					INNER JOIN PersonLease pl ON ap.PersonID = pl.personID
					INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN #Properties #p ON b.PropertyID = #p.PropertyID
				WHERE l.AccountID = @accountID AND
					(l.LeaseStatus = 'Current' OR l.LeaseStatus = 'Under Eviction') 
			) S  WHERE ahobjectid = S.UnitLeaseGroupID) 
			WHERE Races IS NULL


	UPDATE #results SET Races = NULL WHERE Races = 0

	SELECT * FROM #results WHERE NumberOfPeople > 0
						 
END

GO
