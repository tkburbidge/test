SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Phillip Lundquist
-- Create date: April 18, 2012
-- Description:	Generates the data for the Birthdays Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_Birthdays]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@months IntCollection READONLY,
	@residencyStatus StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT DISTINCT
		p.PreferredName + ' ' + p.LastName AS 'Resident', p.Birthdate AS 'Birthdate', p.PersonID,
		u.Number AS 'Unit',
		l.LeaseID, prop.Name AS 'Property', pli.IsNotOccupant, pl.HouseholdStatus
		FROM Person p
			INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID
			INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property prop ON b.PropertyID = prop.PropertyID	
			LEFT JOIN PickListItem pli ON pl.HouseholdStatus = pli.Name AND pli.[Type] = 'HouseholdStatus' AND pli.AccountID =  prop.AccountID
		WHERE b.PropertyID in (SELECT Value FROM @propertyIDs)
		  AND Month(p.Birthdate) in (SELECT Value FROM @months)
		  AND pl.ResidencyStatus IN (SELECT Value FROM @residencyStatus)
		  AND (pli.IsNotOccupant IS NULL OR pli.IsNotOccupant = 0)		  
		  AND l.LeaseID = (SELECT TOP 1 LeaseID 
								FROM Lease
									INNER JOIN Ordering o1 ON o1.[Type] = 'Lease' AND LeaseStatus = Value
								WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								ORDER BY o1.OrderBy)	
END
GO
