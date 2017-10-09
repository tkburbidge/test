SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Jordan Betteridge
-- Create date: November 27, 2013
-- Description:	Generates the data for the RentersInsuranceExceptions Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_RentersInsuranceExceptions]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@leaseStatus StringCollection READONLY,
	@includeExpiringPolicies bit = null,
	@expiringDate date = null,
	@includeMissingPolicies bit = null,
	@date date = null,
	@includeExpiredPolicies bit = null,
	@includeCancelledPolicies bit = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	-- Insert statements for procedure here
	CREATE TABLE #RentersInsuranceData
	(
		ID int identity,
		PropertyName nvarchar(50) not null,
		UnitLeaseGroupID uniqueidentifier not null,		
		Residents nvarchar(500)  null,
		PolicyHolders nvarchar(200) null,
		[Type] nvarchar(50) null,			-- RentersInsuranceType
		Provider nvarchar(100) null,
		PolicyNumber nvarchar(50) null,
		ContactName nvarchar(50) null,
		PhoneNumber nvarchar(25) null,
		ExpirationDate date null,
		CancellationDate date null,
		Coverage money null,
		Unit nvarchar (20) null,
		PaddedUnit nvarchar(50) null,
		InsuranceStatus nvarchar(10) not null,
		PropertyID uniqueidentifier not null,
		LeaseID uniqueidentifier not null
	)

	INSERT INTO #RentersInsuranceData		
		
		-- Select for Expired Policies 
		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				ulg.UnitLeaseGroupID AS 'UnitLeaseGroupID',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				 WHERE PersonLease.LeaseID = l.LeaseID
					   AND PersonType.[Type] = 'Resident'				   
					   AND PersonLease.MainContact = 1				   
				 FOR XML PATH ('')), 1, 2, '')
				AS 'Residents',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN RentersInsurancePerson ON Person.PersonID = RentersInsurancePerson.PersonID							
				 WHERE RentersInsurancePerson.RentersInsuranceID = ri.RentersInsuranceID					   
				 FOR XML PATH ('')), 1, 2, '')
				AS 'PolicyHolders',				
				ri.RentersInsuranceType AS 'Type', 
				ri.OtherProvider AS 'Provider', 
				ri.PolicyNumber AS 'PolicyNumber', 
				ri.ContactName AS 'ContactName', 
				ri.ContactPhoneNumber AS 'PhoneNumber',
				ri.ExpirationDate AS 'ExpirationDate', 
				null AS 'CancellationDate',
				ri.Coverage AS 'Coverage',
				u.Number AS 'Unit',
				u.PaddedNumber,
				'Expired' AS 'InsuranceStatus',
				b.PropertyID AS 'PropertyID',
				l.LeaseID
			FROM RentersInsurance ri
				INNER JOIN UnitLeaseGroup ulg ON ri.UnitLeaseGroupID = ulg.UnitLeaseGroupID								
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID				
				INNER JOIN Property p on b.PropertyID = p.PropertyID
			WHERE 				
				b.PropertyID in (SELECT Value FROM @propertyIDs)								
				AND @includeExpiredPolicies = 1
				AND ri.ExpirationDate IS NOT NULL
				AND ri.ExpirationDate <= @date
				AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
								 FROM Lease l2
								 INNER JOIN Ordering o ON o.Value = l2.LeaseStatus AND o.[Type] = 'Lease'								 
								 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
								 ORDER BY o.OrderBy)
				AND l.LeaseStatus in (SELECT Value FROM @leaseStatus) 
			ORDER BY ri.ExpirationDate DESC
		
	-- Make renters insurances Distinct on UnitLeaseGroupID
    -- by using the insurance with the earliest StartDate.
    DELETE #ri
		FROM #RentersInsuranceData #ri		
		WHERE #ri.ID NOT IN
			(SELECT MIN(#ri2.ID)
				FROM #RentersInsuranceData #ri2
				GROUP BY #ri2.UnitLeaseGroupID)
	
	INSERT INTO #RentersInsuranceData		
		
		-- Select for Expiring Policies
		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				ulg.UnitLeaseGroupID AS 'UnitLeaseGroupID',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				 WHERE PersonLease.LeaseID = l.LeaseID
					   AND PersonType.[Type] = 'Resident'				   
					   AND PersonLease.MainContact = 1				   
				 FOR XML PATH ('')), 1, 2, '')
				AS 'Residents',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN RentersInsurancePerson ON Person.PersonID = RentersInsurancePerson.PersonID							
				 WHERE RentersInsurancePerson.RentersInsuranceID = ri.RentersInsuranceID					   
				 FOR XML PATH ('')), 1, 2, '')
				AS 'PolicyHolders',				
				ri.RentersInsuranceType AS 'Type', 
				ri.OtherProvider AS 'Provider', 
				ri.PolicyNumber AS 'PolicyNumber', 
				ri.ContactName AS 'ContactName', 
				ri.ContactPhoneNumber AS 'PhoneNumber',
				ri.ExpirationDate AS 'ExpirationDate', 
				null AS 'CancellationDate',
				ri.Coverage AS 'Coverage',
				u.Number AS 'Unit',
				u.PaddedNumber,
				'Expiring' AS 'InsuranceStatus',
				b.PropertyID AS 'PropertyID',
				l.LeaseID
			FROM RentersInsurance ri
				INNER JOIN UnitLeaseGroup ulg ON ri.UnitLeaseGroupID = ulg.UnitLeaseGroupID								
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID	
				INNER JOIN Property p on b.PropertyID = p.PropertyID
			WHERE 				
				b.PropertyID in (SELECT Value FROM @propertyIDs)								
				AND @includeExpiringPolicies = 1
				AND ri.ExpirationDate IS NOT NULL
				AND ri.ExpirationDate >= @date
				AND ri.ExpirationDate <= @expiringDate																
				AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
								 FROM Lease l2
								 INNER JOIN Ordering o ON o.Value = l2.LeaseStatus AND o.[Type] = 'Lease'								 
								 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
								 ORDER BY o.OrderBy)
				AND l.LeaseStatus in (SELECT Value FROM @leaseStatus) 
		
	INSERT INTO #RentersInsuranceData		
		
		-- Select for Missing Policies
		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				ulg.UnitLeaseGroupID AS 'UnitLeaseGroupID',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				 WHERE PersonLease.LeaseID = l.LeaseID
					   AND PersonType.[Type] = 'Resident'				   
					   AND PersonLease.MainContact = 1				   
				 FOR XML PATH ('')), 1, 2, '')
				AS 'Residents',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN RentersInsurancePerson ON Person.PersonID = RentersInsurancePerson.PersonID							
				 WHERE RentersInsurancePerson.RentersInsuranceID = ri.RentersInsuranceID					   
				 FOR XML PATH ('')), 1, 2, '')
				AS 'PolicyHolders',				
				ri.RentersInsuranceType AS 'Type', 
				ri.OtherProvider AS 'Provider', 
				ri.PolicyNumber AS 'PolicyNumber', 
				ri.ContactName AS 'ContactName', 
				ri.ContactPhoneNumber AS 'PhoneNumber',
				ri.ExpirationDate AS 'ExpirationDate',
				null AS 'CancellationDate',
				ri.Coverage AS 'Coverage',
				u.Number AS 'Unit',
				u.PaddedNumber,
				'Missing' AS 'InsuranceStatus',
				b.PropertyID AS 'PropertyID',
				l.LeaseID
			FROM Lease l				
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				LEFT JOIN RentersInsurance ri ON ulg.UnitLeaseGroupID = ri.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p on b.PropertyID = p.PropertyID
			WHERE 
				b.PropertyID in (SELECT Value FROM @propertyIDs)
				AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
								 FROM Lease l2
								 INNER JOIN Ordering o ON o.Value = l2.LeaseStatus AND o.[Type] = 'Lease'								 
								 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
								 ORDER BY o.OrderBy)
				AND l.LeaseStatus in (SELECT Value FROM @leaseStatus) 				
				AND @includeMissingPolicies = 1
				AND ri.UnitLeaseGroupID IS NULL

	INSERT INTO #RentersInsuranceData

		-- Select for Cancelled Policies 
		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				ulg.UnitLeaseGroupID AS 'UnitLeaseGroupID',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				 WHERE PersonLease.LeaseID = l.LeaseID
					   AND PersonType.[Type] = 'Resident'				   
					   AND PersonLease.MainContact = 1				   
				 FOR XML PATH ('')), 1, 2, '')
				AS 'Residents',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN RentersInsurancePerson ON Person.PersonID = RentersInsurancePerson.PersonID							
				 WHERE RentersInsurancePerson.RentersInsuranceID = ri.RentersInsuranceID					   
				 FOR XML PATH ('')), 1, 2, '')
				AS 'PolicyHolders',				
				ri.RentersInsuranceType AS 'Type', 
				ri.OtherProvider AS 'Provider', 
				ri.PolicyNumber AS 'PolicyNumber', 
				ri.ContactName AS 'ContactName', 
				ri.ContactPhoneNumber AS 'PhoneNumber',
				null AS 'ExpirationDate',
				ri.CancelDate AS 'CancellationDate', 
				ri.Coverage AS 'Coverage',
				u.Number AS 'Unit',
				u.PaddedNumber,
				'Cancelled' AS 'InsuranceStatus',
				b.PropertyID AS 'PropertyID',
				l.LeaseID
			FROM RentersInsurance ri
				INNER JOIN UnitLeaseGroup ulg ON ri.UnitLeaseGroupID = ulg.UnitLeaseGroupID								
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID				
				INNER JOIN Property p on b.PropertyID = p.PropertyID
			WHERE 				
				b.PropertyID in (SELECT Value FROM @propertyIDs)								
				AND @includeCancelledPolicies = 1
				AND ri.CancelDate IS NOT NULL
				AND ri.CancelDate <= @date
				AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
								 FROM Lease l2
								 INNER JOIN Ordering o ON o.Value = l2.LeaseStatus AND o.[Type] = 'Lease'								 
								 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
								 ORDER BY o.OrderBy)
				AND l.LeaseStatus in (SELECT Value FROM @leaseStatus) 
			ORDER BY ri.CancelDate DESC
		
	-- Make renters insurances Distinct on UnitLeaseGroupID
    -- by using the insurance with the earliest StartDate.
    DELETE #ri
		FROM #RentersInsuranceData #ri		
		WHERE #ri.ID NOT IN
			(SELECT MIN(#ri2.ID)
				FROM #RentersInsuranceData #ri2
				GROUP BY #ri2.UnitLeaseGroupID)

	SELECT * FROM #RentersInsuranceData 
	ORDER BY PaddedUnit
	 
END

GO
