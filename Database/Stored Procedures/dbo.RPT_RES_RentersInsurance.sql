SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Phillip Lundquist
-- Create date: April 18, 2012
-- Description:	Generates the data for the RentersInsurance Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_RentersInsurance]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@leaseStatus StringCollection READONLY,
	@localDate datetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	SELECT
		p.Name AS 'PropertyName',
		l.LeaseStatus AS 'LeaseStatus',
		l.LeaseID,		
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
		ri.Coverage AS 'Coverage',
		u.Number AS 'Unit'
		FROM RentersInsurance ri
				INNER JOIN UnitLeaseGroup ulg ON ri.UnitLeaseGroupID = ulg.UnitLeaseGroupID								
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
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
			AND (ri.ExpirationDate IS NULL OR ri.ExpirationDate >= @localDate)				 			
		ORDER BY u.PaddedNumber
			
END
GO
