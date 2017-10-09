SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 31, 2012
-- Description:	Generates the data for the Resident Contact List report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_ResidentContactList] 
	-- Add the parameters for the stored procedure here
	@residencyStatuses StringCollection READONLY,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT DISTINCT p.Name AS 'PropertyName', pr.Salutation AS 'Salutation', pr.LastName + ', ' + pr.PreferredName AS 'Name',
			pl.ResidencyStatus AS 'ResidencyStatus', pl.HouseholdStatus AS 'HouseholdStatus', 
			CASE
				WHEN pr.Phone1Type = 'Home' THEN pr.Phone1
				WHEN pr.Phone2Type = 'Home' THEN pr.Phone2
				WHEN pr.Phone3Type = 'Home' THEN pr.Phone3
				ELSE NULL
				END AS 'HomePhone',
			CASE
				WHEN pr.Phone1Type = 'Mobile' THEN pr.Phone1
				WHEN pr.Phone2Type = 'Mobile' THEN pr.Phone2
				WHEN pr.Phone3Type = 'Mobile' THEN pr.Phone3
				ELSE NULL
				END AS 'CellPhone',
			CASE
				WHEN pr.Phone1Type = 'Work' THEN pr.Phone1
				WHEN pr.Phone2Type = 'Work' THEN pr.Phone2
				WHEN pr.Phone3Type = 'Work' THEN pr.Phone3
				ELSE NULL
				END AS 'WorkPhone',	
			pr.Email AS 'Email', l.LeaseStartDate AS 'LeaseStartDate', l.LeaseEndDate AS 'LeaseEndDate',
			u.Number AS 'Unit', ut.Name AS 'UnitType', l.LeaseID AS 'LeaseID', pl.PersonID AS 'PersonID'					
		FROM Person pr
			INNER JOIN PersonLease pl ON pr.PersonID = pl.PersonID
			INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
		WHERE pl.ResidencyStatus IN (SELECT Value FROM @residencyStatuses)
		  AND p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND l.LeaseID = ((SELECT TOP 1 LeaseID
								 FROM Lease
								 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								   AND (((SELECT COUNT(*) 
												FROM Lease 
												WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
												  AND LeaseStatus NOT IN ('Cancelled')) = 0)
										OR LeaseStatus NOT IN ('Cancelled'))
								 ORDER BY LeaseEndDate DESC))	  
END
GO
