SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Craig Perkins
-- Create date: December 10, 2013
-- Description:	Gets guest cards for LRO
-- =============================================
CREATE PROCEDURE [dbo].[API_GetLROGuestCards] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT 
		prop.PropertyID AS 'SPCommunity',
		pro.PersonID AS 'SPPersonID',
		--put.UnitTypeID, -- From this, you can get the Name and the Bedroom count
		ut.Name AS 'UnitType',
		ut.Bedrooms AS 'NumberOfBedrooms',
		(CASE WHEN l.LeaseID IS NOT NULL THEN DATEDIFF(month, l.LeaseStartDate, l.LeaseEndDate)
			  ELSE 12
		 END) AS 'LeaseTerm',
		(CASE WHEN l.LeaseID IS NOT NULL THEN (SELECT MIN(MoveInDate)
											   FROM PersonLease
											   WHERE LeaseID = l.LeaseID)
			  ELSE pro.DateNeeded
		 END) AS 'SPMoveInDate',
		(CASE WHEN l.LeaseID IS NOT NULL THEN (SELECT MIN(ApplicationDate)
											   FROM PersonLease
											   WHERE LeaseID = l.LeaseID)
			  ELSE (SELECT MIN([Date])
			  FROM PersonNote
			  WHERE PersonNote.PersonID = pro.PersonID
				AND PersonNote.PersonType = 'Prospect')		  
		 END) AS 'SPCardDate',
		 p.LastModified AS 'PersonLastModified',
		 (CASE WHEN l.LeaseID IS NULL AND pro.LostDate IS NOT NULL THEN 'R'
			   WHEN l.LeaseID IS NOT NULL AND l.LeaseStatus IN ('Denied') THEN 'D'
			   WHEN l.LeaseID IS NOT NULL AND l.LeaseStatus IN ('Cancelled') THEN 'R'
			   WHEN l.LeaseID IS NOT NULL AND l.LeaseStatus IN ('Current', 'Renewed', 'Former', 'Evicted', 'Under Eviction') THEN 'L'
			   ELSE ''
		 END) AS 'Status',
		(CASE WHEN l.LeaseID IS NOT NULL THEN (SELECT SUM(lli.Amount)
											   FROM LeaseLedgerItem lli
												INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
												INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
											   WHERE lli.LeaseID = l.LeaseID
												AND lit.IsRent = 1)
			  ELSE 0
		 END) AS 'SPQuotedRent',
		(CASE WHEN l.LeaseID IS NOT NULL THEN (SELECT SUM(lli.Amount)
											   FROM LeaseLedgerItem lli
												INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
												INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
											   WHERE lli.LeaseID = l.LeaseID
												AND lit.IsCredit = 1)
			  ELSE 0
		 END) AS 'SPQuotedConcessions', 
		 ps.Name AS 'ProspectSource',
		 fpn.ContactType AS 'SPContactType',
		 (SELECT TOP 1 pn.[Date]
		 FROM PersonNote pn
		 WHERE pro.PersonID = pn.PersonID
			AND pn.ContactType = 'Face-to-Face'
			AND pn.PersonType = 'Prospect'
			AND pn.PropertyID = prop.PropertyID
		 ORDER BY pn.[Date]
		 ) AS 'SPFaceToFaceDate'
	FROM Prospect pro
	INNER JOIN Person p ON pro.PersonID = p.PersonID
	INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pro.PropertyProspectSourceID
	INNER JOIN ProspectSource ps ON ps.ProspectSourceID = pps.ProspectSourceID
	INNER JOIN Property prop ON prop.PropertyID = pps.PropertyID
	INNER JOIN ProspectUnitType put ON put.ProspectID = pro.ProspectID
	INNER JOIN UnitType ut ON put.UnitTypeID = ut.UnitTypeID
	LEFT JOIN PersonLease pl ON pl.PersonID = pro.PersonID
	LEFT JOIN Lease l ON l.LeaseID = pl.LeaseID	
	LEFT JOIN PersonNote fpn ON pro.FirstPersonNoteID = fpn.PersonNoteID
	WHERE put.ProspectUnitTypeID = (SELECT TOP 1 ProspectUnitTypeID
									FROM ProspectUnitType
									WHERE ProspectID = pro.ProspectID)
		AND (pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
								FROM PersonLease pl2
									INNER JOIN Lease l2 ON l2.LeaseID = pl2.LeaseID
									INNER JOIN UnitLeaseGroup ulg2 on ulg2.UnitLeaseGroupID = l2.UnitLeaseGroupID
									INNER JOIN Unit u2 ON u2.UnitID = ulg2.UnitID
									INNER JOIN Building b2 on b2.BuildingID = u2.BuildingID
								WHERE PersonID = pro.PersonID
									AND b2.PropertyID = prop.PropertyID
								ORDER BY l2.LeaseStartDate) 
			OR pl.PersonLeaseID IS NULL)
		AND prop.PropertyID = @propertyID
		AND pro.AccountID = @accountID
	
END
GO
