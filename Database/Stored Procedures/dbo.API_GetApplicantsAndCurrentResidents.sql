SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Craig Perkins
-- Create date: July 14, 2014
-- Description:	Gets applicants and current residents
-- =============================================
CREATE PROCEDURE [dbo].[API_GetApplicantsAndCurrentResidents] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier = null,
	@residentID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT DISTINCT
		l.LeaseID,
		p.PersonID,
		l.LeaseStatus AS 'Status',
		p.LastModified,
		b.PropertyID,
		ulg.UnitLeaseGroupID,
		p.FirstName,
		p.LastName,
		u.Number AS 'Unit',
		b.Name AS 'Building',
		p.Email,
		CASE WHEN (p.Phone1Type = 'Mobile') THEN p.Phone1
			 WHEN (p.Phone2Type = 'Mobile') THEN p.Phone2
			 WHEN (p.Phone3Type = 'Mobile') THEN p.Phone3
			 ELSE null END AS 'MobilePhone',
		CASE WHEN (p.Phone1Type = 'Home') THEN p.Phone1
			 WHEN (p.Phone2Type = 'Home') THEN p.Phone2
			 WHEN (p.Phone3Type = 'Home') THEN p.Phone3
			 ELSE null END AS 'HomePhone',
		CASE WHEN (p.Phone1Type = 'Work') THEN p.Phone1
			 WHEN (p.Phone2Type = 'Work') THEN p.Phone2
			 WHEN (p.Phone3Type = 'Work') THEN p.Phone3
			 ELSE null END AS 'WorkPhone',
		l.LeaseStartDate,
		l.LeaseEndDate,	
		pl.MoveInDate,
		pl.MoveOutDate
		
		--(SELECT SUM(lli.Amount)
		--	FROM LeaseLedgerItem lli
		--		JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
		--		JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
		--	WHERE l.LeaseID = lli.LeaseID
		--		AND lit.IsRent = 1
		--		AND lli.StartDate <= l.LeaseEndDate) AS 'Rent',
		--((SELECT ISNULL(SUM(t.Amount), 0)
		--	FROM [Transaction] t
		--		INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
		--	WHERE t.ObjectID = ulg.UnitLeaseGroupID
		--		AND tt.Name IN ('Deposit', 'Balance Transfer Deposit', 'Deposit Applied to Deposit')) -
		--	(SELECT ISNULL(SUM(tb.Amount), 0)
		--		FROM [Transaction] tb
		--			INNER JOIN TransactionType ttb ON tb.TransactionTypeID = ttb.TransactionTypeID
		--		WHERE tb.ObjectID = ulg.UnitLeaseGroupID
		--			AND ttb.Name IN ('Deposit Refund'))) AS 'DepositsHeld'
	FROM Person p
		INNER JOIN PersonLease pl ON pl.PersonID = p.PersonID
		INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u ON u.UnitID = ulg.UnitID
		INNER JOIN Building b ON b.BuildingID = u.BuildingID
	WHERE 
		p.AccountID = @accountID
		AND (@residentID IS NULL OR pl.PersonID = @residentID)
		AND (@propertyID IS NULL OR b.PropertyID = @propertyID)
		AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
						 FROM Lease l2
							INNER JOIN Ordering o ON o.Value = l2.LeaseStatus
						 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
						 ORDER BY o.OrderBy)
		AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Pending', 'Pending Renewal', 'Approved', 'Pending Transfer')
	END
	
	SELECT  
		ac.ParentPersonID AS 'PersonID',
		ac.PreferredName AS 'AlternateContactName',
		ac.Phone1 AS 'AlternateContactPhone',
		ac.Phone2 AS 'AlternateContactWorkPhone',
		ac.Email AS 'AlternateContactEmail',
		aca.StreetAddress AS 'AlternateContactAddress',
		aca.City AS 'AlternateContactCity',
		aca.[State] AS 'AlternateContactState',
		aca.Zip AS 'AlternateContactZip',
		aca.Country AS 'AlternateContactCountry',
		ac.AlternatePersonType AS 'AlternateContactRelationship'
		
	FROM Person p
		INNER JOIN PersonLease pl ON pl.PersonID = p.PersonID
		INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u ON u.UnitID = ulg.UnitID
		INNER JOIN Building b ON b.BuildingID = u.BuildingID
		INNER JOIN Property prop ON b.PropertyID = prop.PropertyID
		INNER JOIN Person ac ON p.PersonID = ac.ParentPersonID
		INNER JOIN [Address] aca ON ac.PersonID = aca.ObjectID
		WHERE 
		p.AccountID = @accountID
		AND (@residentID IS NULL OR pl.PersonID = @residentID)
		AND (@propertyID IS NULL OR b.PropertyID = @propertyID)
		AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
						 FROM Lease l2
							INNER JOIN Ordering o ON o.Value = l2.LeaseStatus
						 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
						 ORDER BY OrderBy)
		AND pl.ResidencyStatus IN ('Current', 'Pending Renewal', 'Under Eviction')

		
	SELECT  
		pe.PersonID,
		pe.Name AS 'PetName',
		pe.[Type] AS 'PetType',
		pe.Breed AS 'PetBreed',
		pe.Color AS 'PetColor',
		pe.Age AS 'PetAge',
		pe.[Weight] AS 'PetWeight',
		pe.Notes AS 'PetNotes',
		pe.RegistrationType AS 'PetRegistrationType',
		pe.RegistrationIssuedBy AS 'PetRegistrationIssuer',
		pe.RegistrationNumber AS 'PetRegistrationNumber',
		pe.ProofOfVaccinations AS 'PetProofVaccination',
		pe.VaccinationExpirationDate AS 'PetVaccinationExpiration',
		pe.ValidationOfDogBreed AS 'PetProofBreed'
	FROM Person p
		INNER JOIN PersonLease pl ON pl.PersonID = p.PersonID
		INNER JOIN Lease l ON l.LeaseID = pl.LeaseID
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u ON u.UnitID = ulg.UnitID
		INNER JOIN Building b ON b.BuildingID = u.BuildingID
		INNER JOIN Property prop ON b.PropertyID = prop.PropertyID
		INNER JOIN Pet pe ON p.PersonID = pe.PersonID
		WHERE 
		p.AccountID = @accountID
		AND (@residentID IS NULL OR pl.PersonID = @residentID)
		AND (@propertyID IS NULL OR b.PropertyID = @propertyID)
		AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
						 FROM Lease l2
							INNER JOIN Ordering o ON o.Value = l2.LeaseStatus
						 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
						 ORDER BY OrderBy)
		AND pl.ResidencyStatus IN ('Current', 'Pending Renewal', 'Under Eviction')
GO
