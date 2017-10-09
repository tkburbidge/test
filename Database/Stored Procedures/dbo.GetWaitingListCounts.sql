SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 23, 2012
-- Description:	Gets the WaitingListCounts
-- =============================================
CREATE PROCEDURE [dbo].[GetWaitingListCounts] 
	-- Add the parameters for the stored procedure here
	@leaseID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF (NULL = (SELECT TOP 1 PersonLeaseID FROM PersonLease WHERE LeaseID = @leaseID AND MoveOutDate IS NULL))
	BEGIN
		SELECT wl.ObjectID AS 'ObjectID', u.Number AS 'ObjectName', 'Unit' AS 'ObjectType',
				(SELECT COUNT(*) FROM WaitingList WHERE ObjectID = u.UnitID) AS 'Count'
			FROM WaitingList wl
				INNER JOIN Unit u ON wl.ObjectID = u.UnitID
				INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			WHERE l.LeaseID = @leaseID
			  AND wl.DateRemoved IS NULL
			  AND wl.DateSatisfied IS NULL
			
		UNION
			
		SELECT wl.ObjectID AS 'ObjectID', ut.Name AS 'ObjectName', 'UnitType' AS 'ObjectType',
				(SELECT COUNT(*) FROM WaitingList WHERE ObjectID = ut.UnitTypeID) AS 'Count'
			FROM WaitingList wl
				INNER JOIN UnitType ut ON wl.ObjectID = ut.UnitTypeID 
				INNER JOIN Unit u ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.LeaseID
			WHERE l.LeaseID = @leaseID
			  AND wl.DateRemoved IS NULL
			  AND wl.DateSatisfied IS NULL			
			
		UNION
		
		SELECT wl.ObjectID AS 'ObjectID', li.Description AS 'ObjectName', 'Rentable Item' AS 'ObjectType',
				(SELECT COUNT(*) FROM WaitingList WHERE ObjectID = li.LedgerItemID) AS 'Count'
			FROM WaitingList wl
				INNER JOIN LedgerItem li ON wl.ObjectID = li.LedgerItemID
				INNER JOIN LeaseLedgerItem lli ON lli.LedgerItemID = li.LedgerItemID
				INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
			WHERE l.LeaseID = @leaseID
			  AND lli.EndDate >= l.LeaseEndDate
			  AND wl.DateRemoved IS NULL
			  AND wl.DateSatisfied IS NULL			  
			  
		UNION
		
		SELECT wl.ObjectID AS 'ObjectID', lip.Name AS 'ObjectName', 'Rentable Item Type' AS 'ObjectType',
				(SELECT COUNT(*) FROM WaitingList WHERE ObjectID = lip.LedgerItemPoolID) AS 'Count'
			FROM WaitingList wl
				INNER JOIN LedgerItemPool lip ON wl.ObjectID = lip.LedgerItemPoolID
				INNER JOIN LedgerItem li ON lip.LedgerItemPoolID = li.LedgerItemPoolID
				INNER JOIN LeaseLedgerItem lli ON li.LedgerItemID = lli.LedgerItemID
				INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
			WHERE l.LeaseID = @leaseID
			  AND lli.EndDate >= l.LeaseEndDate
			  AND wl.DateRemoved IS NULL
			  AND wl.DateSatisfied IS NULL			  
	END
	
 
END
GO
