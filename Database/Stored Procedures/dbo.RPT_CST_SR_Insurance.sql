SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Jordan Betteridge
-- Create date: August 26, 2015
-- Description:	Gets the data for the Stern Risk Insurance - Bordereaux Layout Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_SR_Insurance] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT 
		prop.PropertyID,
		prop.Name AS 'PropertyName',
		ri.PolicyNumber,
		p.PersonID,
		p.FirstName,
		p.LastName,
		STUFF((SELECT ', ' + (p2.FirstName + ' ' + p2.LastName)
			   FROM Person p2
			   		INNER JOIN RentersInsurancePerson rip ON p2.PersonID = rip.PersonID		
			   WHERE rip.RentersInsuranceID = ri.RentersInsuranceID
			   		AND rip.PersonID != p.PersonID		   
			   FOR XML PATH ('')), 1, 2, '') AS 'Residents',
		a.StreetAddress,
		a.City,
		a.[State],
		a.Zip,
		b.Name AS 'BuildingName',
		u.Number AS 'UnitNumber',
		ri.StartDate AS 'RentersInsuranceStartDate',
		ri.ExpirationDate AS 'RentersInsuranceExpirationDate'
	FROM Unit u
		INNER JOIN Building b ON b.BuildingID = u.BuildingID
		INNER JOIN Property prop ON prop.PropertyID = b.PropertyID
		LEFT JOIN [Address] a ON a.AddressID = u.AddressID
		-- Join in unit lease groups that have a current lease
		LEFT JOIN UnitLeaseGroup ulg ON ulg.UnitID = u.UnitID AND (SELECT COUNT(*) FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID AND LeaseStatus IN ('Current', 'Under Eviction')) > 0
		-- Join in the current lease
		LEFT JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')
		-- Join in the first main contact
		LEFT JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																					FROM PersonLease pl2
																					WHERE pl2.LeaseID = l.LeaseID
																					AND ResidencyStatus NOT IN ('Cancelled', 'Former', 'Evicted')
																					ORDER BY pl2.OrderBy, pl2.PersonID)
		LEFT JOIN Person p ON pl.PersonID = p.PersonID
		LEFT JOIN RentersInsurance ri ON ri.UnitLeaseGroupID = l.UnitLeaseGroupID
	WHERE u.AccountID = @accountID
	  AND prop.PropertyID IN (SELECT Value FROM @propertyIDs)
	  AND p.PersonID IS NOT NULL
	  AND ri.RentersInsuranceID IS NOT NULL
	  AND ri.RentersInsuranceID = (SELECT TOP 1 RentersInsuranceID
								    FROM RentersInsurance
								    WHERE UnitLeaseGroupID = l.UnitLeaseGroupID
								    ORDER BY DateCreated DESC)

	ORDER BY u.PaddedNumber
END
GO
