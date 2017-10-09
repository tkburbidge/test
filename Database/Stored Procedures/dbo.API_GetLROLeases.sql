SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Craig Perkins
-- Create date: December 6, 2013
-- Description:	Gets lease information required for LRO
-- =============================================
CREATE PROCEDURE [dbo].[API_GetLROLeases] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT
	@propertyID AS 'Community',
	u.Number AS 'UnitNumber',
	u.UnitID AS 'UnitID',
	l.LeaseID AS 'LeaseID',
	(SELECT MIN(pl.ApplicationDate) 
	 FROM PersonLease pl 
	 WHERE pl.LeaseID = l.LeaseID) AS 'ApplicationDate',
	(SELECT MIN(pl.MoveInDate) 
	 FROM PersonLease pl 
	 WHERE pl.LeaseID = l.LeaseID) AS 'MoveInDate',
	 l.LeaseStartDate AS 'StartDate',
	 l.LeaseEndDate AS 'EndDate',
	 (CASE WHEN l.LeaseStatus IN ('Cancelled', 'Denied') THEN 'Cancelled'
			WHEN EXISTS (SELECT LeaseID 
						FROM Lease renewedLease
						WHERE renewedLease.UnitLeaseGroupID = l.UnitLeaseGroupID
							AND renewedLease.LeaseStartDate < l.LeaseStartDate)
				THEN 'Renewed'	-- There exists a renewal lease that started before this lease
			WHEN ulg.PreviousUnitLeaseGroupID IS NOT NULL THEN 'New'		
			ELSE 'New'
	  END) AS 'LeaseType',
	(SELECT MAX(pl.NoticeGivenDate) 
	 FROM PersonLease pl 
		LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.NoticeGivenDate IS NULL
	 WHERE pl.LeaseID = l.LeaseID
		AND plmo.PersonLeaseID IS NULL) AS 'NoticeDate',
	(SELECT MAX(pl.MoveOutDate) 
		FROM PersonLease pl 
		LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.MoveOutDate IS NULL
		WHERE pl.LeaseID = l.LeaseID
		AND plmo.PersonLeaseID IS NULL) AS 'MoveOutDate',  -- this should be null for cancelled leases in the LRO data set
	(SELECT TOP 1 p.FirstName + ' ' + p.LastName 
	 FROM PersonLease pl 
		INNER JOIN Person p ON p.PersonID = pl.PersonID
	 WHERE pl.LeaseID = l.LeaseID
	 ORDER BY pl.OrderBy) AS 'PersonName',
	 (SELECT TOP 1 PersonLease.PersonID FROM PersonLease WHERE PersonLease.LeaseID = l.LeaseID ORDER BY PersonLease.OrderBy, PersonLease.PersonID) AS 'TenantID',
	 (CASE WHEN l.LeaseStatus IN ('Former', 'Evicted') THEN 'Past'
		   WHEN l.LeaseStatus IN ('Current', 'Renewed', 'Pending Transfer', 'Pending Renewal', 'Under Eviction') THEN 'Current'
		   WHEN l.LeaseStatus IN ('Cancelled', 'Denied') THEN 'Cancelled'
		   WHEN l.LeaseStatus IN ('Pending') THEN 'Future'
	 END) AS 'TenantStatus',
	 ut.UnitTypeID AS 'UnitTypeID',
	(SELECT SUM(lli.Amount)
	  FROM LeaseLedgerItem lli
	  INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
	  INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
	  WHERE lli.LeaseID = l.LeaseID
		AND lit.IsRent = 1
		AND lli.StartDate <= l.LeaseEndDate) AS 'Rent',
	(SELECT SUM(lli.Amount)
	  FROM LeaseLedgerItem lli
	  INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
	  INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
	  WHERE lli.LeaseID = l.LeaseID
		AND lit.IsCredit = 1
		AND lit.IsRecurringMonthlyRentConcession = 1
		AND lli.StartDate <= l.LeaseEndDate) AS 'Concessions',	
	(SELECT SUM(lli.Amount)
	  FROM LeaseLedgerItem lli
	  INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
	  INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
	  WHERE lli.LeaseID = l.LeaseID
		AND lit.IsCharge = 1
		AND lit.IsRent = 0
		AND lli.StartDate <= l.LeaseEndDate) AS 'OtherCharges'
	 -- CancelDate is the same as the MOveOutDate if the TenantStatus is Cancelled
FROM Lease l
	INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
	INNER JOIN Unit u ON u.UnitID = ulg.UnitID
	INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	INNER JOIN Building b ON b.BuildingID = u.BuildingID	
WHERE b.PropertyID = @propertyID
	AND b.AccountID = @accountID
	AND u.IsHoldingUnit = 0
	-- Make sure we don't get orphaned leases (temporary fix)
	AND EXISTS (SELECT * FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)
	
END
GO
