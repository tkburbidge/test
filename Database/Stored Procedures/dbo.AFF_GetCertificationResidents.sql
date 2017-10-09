SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[AFF_GetCertificationResidents] 
    -- Add the parameters for the stored procedure here
    @accountID bigint = null,
    @certificationIDs GuidCollection READONLY
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    CREATE TABLE #Residents
    (
        CertificationID uniqueidentifier not null,
        PersonID uniqueidentifier not null,
        LeaseID uniqueidentifier not null,
        PropertyID uniqueidentifier not null,
        Name nvarchar(81) not null,
        Relationship nvarchar(35) not null,
        Race int null,
        Ethnicity int null,
        IsDisabled bit not null,
        IsElderly bit not null,
        Birthdate date null,
        IsFullTimeStudent bit not null,
        SSN nvarchar(50) null,
        DateVerified datetime null
    )
    
    INSERT INTO #Residents
        SELECT
            c.CertificationID AS 'CertificationID',
            p.PersonID AS 'PersonID',
            c.LeaseID AS 'LeaseID',
            b.PropertyID AS 'PropertyID',
            p.PreferredName + ' ' + p.LastName AS 'Name',
            cp.HouseholdStatus AS 'Relationship',
            ap.Race AS 'Race',
            ap.Ethnicity AS 'Ethnicity',
            (CASE WHEN ap.[Disabled] = 1 OR ap.DisabledHearing = 1 OR ap.DisabledMobility = 1 OR ap.DisabledVisual = 1 OR ap.DisabledMental = 1 THEN 1 ELSE 0 END) AS 'IsDisabled',
            (CASE WHEN ap.Elderly IS NULL THEN 0 ELSE ap.Elderly END) AS 'IsElderly',
            (CASE WHEN p.Birthdate IS NULL THEN '01-01-0001' ELSE p.Birthdate END) AS 'Birthdate',
            (CASE WHEN ap.FullTimeStudent IS NULL THEN 0 ELSE ap.FullTimeStudent END) AS 'IsFullTimeStudent',
            p.SSNDisplay AS 'SSN',
            ap.DateVerified AS 'DateVerified'
        FROM Certification c
            INNER JOIN CertificationPerson cp on cp.CertificationID = c.CertificationID
            INNER JOIN Person p on cp.PersonID = p.PersonID
            LEFT JOIN AffordablePerson ap on ap.PersonID = p.PersonID
            INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u on u.UnitID = ulg.UnitID
            INNER JOIN Building b on b.BuildingID = u.BuildingID
        WHERE c.AccountID = @accountID
            AND c.DateCompleted IS NOT NULL
            AND (c.CertificationID IN (SELECT Value FROM @certificationIDs))
            AND cp.HouseholdStatus IN ('Head of Household', 'Co-Head', 'Spouse', 'Dependent', 'Other', 'Foster Child', 'Live-in aide', 'Dependent (child care allowance)', 'Dependent (less than 50%)', 'Dependent (50%)')
          
    INSERT INTO #Residents
        SELECT
            c.CertificationID AS 'CertificationID',
            p.PersonID AS 'PersonID',
            l.LeaseID AS 'LeaseID',
            b.PropertyID AS 'PropertyID',
            p.PreferredName + ' ' + p.LastName AS 'Name',
            pl.HouseholdStatus AS 'Relationship',
            ap.Race AS 'Race',
            ap.Ethnicity AS 'Ethnicity',
            (CASE WHEN ap.[Disabled] = 1 OR ap.DisabledHearing = 1 OR ap.DisabledMobility = 1 OR ap.DisabledVisual = 1 OR ap.DisabledMental = 1 THEN 1 ELSE 0 END) AS 'IsDisabled',
            (CASE WHEN ap.Elderly IS NULL THEN 0 ELSE ap.Elderly END) AS 'IsElderly',
            (CASE WHEN p.Birthdate IS NULL THEN '01-01-0001' ELSE p.Birthdate END) AS 'Birthdate',
            (CASE WHEN ap.FullTimeStudent IS NULL THEN 0 ELSE ap.FullTimeStudent END) AS 'IsFullTimeStudent',
            p.SSNDisplay AS 'SSN',
            ap.DateVerified AS 'DateVerified'
        FROM Certification c
            INNER JOIN Lease l ON c.LeaseID = l.LeaseID
            INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
            INNER JOIN Unit u ON ulg.UnitID = u.UnitID
            INNER JOIN Building b ON u.BuildingID = b.BuildingID
            INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
            INNER JOIN Person p ON pl.PersonID = p.PersonID
            LEFT JOIN AffordablePerson ap ON p.PersonID = ap.PersonID
        WHERE c.AccountID = @accountID
            AND c.DateCompleted IS NULL
            AND (c.CertificationID IN (SELECT Value FROM @certificationIDs))
            AND pl.HouseholdStatus IN ('Head of Household', 'Co-Head', 'Spouse', 'Dependent', 'Other', 'Foster Child', 'Live-in aide', 'Dependent (child care allowance)', 'Dependent (less than 50%)', 'Dependent (50%)')
			AND pl.ResidencyStatus NOT IN ('Denied', 'Cancelled', 'Former', 'Evicted', 'Renewed')
            AND c.LeaseID IS NOT NULL

    INSERT INTO #Residents
        SELECT
            c.CertificationID AS 'CertificationID',
            p.PersonID AS 'PersonID',
            l.LeaseID AS 'LeaseID',
            b.PropertyID AS 'PropertyID',
            p.PreferredName + ' ' + p.LastName AS 'Name',
            pl.HouseholdStatus AS 'Relationship',
            ap.Race AS 'Race',
            ap.Ethnicity AS 'Ethnicity',
            (CASE WHEN ap.[Disabled] = 1 OR ap.DisabledHearing = 1 OR ap.DisabledMobility = 1 OR ap.DisabledVisual = 1 OR ap.DisabledMental = 1 THEN 1 ELSE 0 END) AS 'IsDisabled',
            (CASE WHEN ap.Elderly IS NULL THEN 0 ELSE ap.Elderly END) AS 'IsElderly',
            (CASE WHEN p.Birthdate IS NULL THEN '01-01-0001' ELSE p.Birthdate END) AS 'Birthdate',
            (CASE WHEN ap.FullTimeStudent IS NULL THEN 0 ELSE ap.FullTimeStudent END) AS 'IsFullTimeStudent',
            p.SSNDisplay AS 'SSN',
            ap.DateVerified AS 'DateVerified'
        FROM Certification c
            INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
            INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
            INNER JOIN Unit u ON ulg.UnitID = u.UnitID
            INNER JOIN Building b ON u.BuildingID = b.BuildingID
            INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
            INNER JOIN Person p ON pl.PersonID = p.PersonID
            LEFT JOIN AffordablePerson ap ON p.PersonID = ap.PersonID
        WHERE c.AccountID = @accountID
            AND c.DateCompleted IS NULL
            AND (c.CertificationID IN (SELECT Value FROM @certificationIDs))
            AND c.LeaseID IS NULL
            AND pl.PersonLeaseID IN (SELECT TOP 1 PersonLeaseID
                                        FROM PersonLease pl2
                                            JOIN Lease l2 ON pl2.LeaseID = l2.LeaseID
                                        WHERE pl2.PersonID = p.PersonID
                                            AND pl2.HouseholdStatus IN ('Head of Household', 'Co-Head', 'Spouse', 'Dependent', 'Other', 'Foster Child', 'Live-in aide', 'Dependent (child care allowance)', 'Dependent (less than 50%)', 'Dependent (50%)')
                                            AND pl2.ResidencyStatus IN ('Pending', 'Approved', 'Current', 'Pending Renewal', 'Pending Transfer', 'Under Eviction')
                                        ORDER BY l2.LeaseStartDate DESC)
    SELECT * FROM #Residents

END
GO
