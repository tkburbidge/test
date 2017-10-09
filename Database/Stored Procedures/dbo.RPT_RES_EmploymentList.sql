SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Phillip Lundquist
-- Create date: April 18, 2012
-- Description:	Generates the data for the EmploymentList Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_EmploymentList]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@residentStatus StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	
		u.Number AS 'Unit',
		p.PreferredName + ' ' + p.LastName AS 'Resident', p.PersonID, 
		pl.ResidencyStatus AS 'ResidencyStatus',
		e.Industry AS 'Industry', e.Employer AS 'Employer', e.Title AS 'Title', e.CompanyPhone AS 'Phone',
		prop.Name AS 'PropertyName',
		a.StreetAddress AS 'Address', a.City AS 'City', a.[State] AS 'State', a.Zip AS 'Zip',
		l.LeaseID
		FROM Employment e
			INNER JOIN Person p ON e.PersonID = p.PersonID
			INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID
			INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID	
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property prop ON prop.PropertyID = b.PropertyID	
			LEFT JOIN [Address] a ON e.AddressID = a.AddressID			
		WHERE pl.ResidencyStatus in (SELECT Value FROM @residentStatus) 
		  AND e.[Type] = 'Employment'
		  AND b.PropertyID in (SELECT Value FROM @propertyIDs)
		  AND l.LeaseID = (SELECT TOP 1 LeaseID 
								FROM Lease
									INNER JOIN Ordering o1 ON o1.[Type] = 'Lease'
								WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								ORDER BY o1.OrderBy)
		ORDER BY u.PaddedNumber
		

END
GO
