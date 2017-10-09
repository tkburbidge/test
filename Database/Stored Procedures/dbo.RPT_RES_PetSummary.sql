SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 31, 2012
-- Description:	Gets the data for the Resident- Pet Summary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_PetSummary] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@residencyStatuses StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	p.Name AS 'PropertyName',
		    l.LeaseID,
			u.Number AS 'Unit',
			pet.Name AS 'PetName',
			pr.PreferredName + ' ' + pr.LastName AS 'OwnerName',
			pet.[Type] AS 'PetType',
			pet.Breed AS 'Breed',
			pet.Color AS 'Color',
			pet.[Weight] AS 'Weight',
			pet.RegistrationType AS 'RegistrationType',
			pet.RegistrationNumber AS 'RegistrationNumber',
			pet.RegistrationIssuedBy AS 'RegistrationIssuedBy',
			pet.ProofOfVaccinations AS 'ProofOfVaccinations',
			pet.ValidationOfDogBreed AS 'ValidationOfDogBreed',
			pet.Notes AS 'Notes'
		FROM Pet pet
			INNER JOIN Person pr ON pet.PersonID = pr.PersonID
			INNER JOIN PersonLease pl ON pr.PersonID = pl.PersonID
										  AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID 
																	 FROM PersonLease pl1
																		INNER JOIN Ordering o ON o.[Type] = 'ResidencyStatus'
																	 WHERE pl1.PersonID = pr.PersonID
																	   AND pl1.ResidencyStatus IN (SELECT Value FROM @residencyStatuses)
																	 ORDER BY o.OrderBy)
			INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN PersonType pt ON pr.PersonID = pt.PersonID AND pt.[Type] = 'Resident'
			INNER JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID
			INNER JOIN Property p ON ptp.PropertyID = p.PropertyID
		WHERE ptp.PropertyID IN (SELECT Value FROM @PropertyIDs)
		  AND pl.ResidencyStatus IN (SELECT Value FROM @residencyStatuses)
		ORDER BY pet.Name
	
END
GO
