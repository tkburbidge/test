SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: August 16, 2012
-- Description:	Gets the waiting lists and associated counts
-- =============================================
CREATE PROCEDURE [dbo].[GetWaitingListStats]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection	readonly,
	@objectTypes StringCollection readonly
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	
	DECLARE @date date
	SET @date = GETDATE()
	
	CREATE TABLE #WaitingLists
	(
		PropertyID uniqueidentifier,
		PropertyName nvarchar(300),
		ObjectID uniqueidentifier,
		ObjectType nvarchar(100),
		Name nvarchar(300),
		TypeName nvarchar(300),
		OnWaitingList int,
		Vacant int,
		NoticeToVacate int
	)

	INSERT INTO #WaitingLists
		SELECT DISTINCT 
			  (CASE WHEN wl.ObjectType = 'RentableItem' THEN lilip.PropertyID
					WHEN wl.ObjectType = 'RentableItemType' THEN lip.PropertyID
					WHEN wl.ObjectType = 'Unit' THEN uut.PropertyID
					WHEN wl.ObjectType = 'UnitType' THEN ut.PropertyID
				END) AS 'Name',
			   '' AS 'PropertyName',
			   wl.ObjectID,
			   wl.ObjectType,
			  (CASE WHEN wl.ObjectType = 'RentableItem' THEN li.[Description]
					WHEN wl.ObjectType = 'RentableItemType' THEN lip.Name
					WHEN wl.ObjectType = 'Unit' THEN u.Number
					WHEN wl.ObjectType = 'UnitType' THEN ut.Name
				END) AS 'Name',
			  (CASE WHEN wl.ObjectType = 'RentableItem' THEN lilip.Name				
					WHEN wl.ObjectType = 'Unit' THEN uut.Name
					ELSE ''
				END) AS 'Name',
			   0 AS 'OnWaitingList',
			   0 AS 'Vacant',
			   0 AS 'NoticeToVacate'
		FROM WaitingList wl	
		LEFT JOIN LedgerItem li ON li.LedgerItemID = wl.ObjectID
		LEFT JOIN LedgerItemPool lilip ON lilip.LedgerItemPoolID = li.LedgerItemPoolID
		LEFT JOIN LedgerItemPool lip ON lip.LedgerItemPoolID = wl.ObjectID
		LEFT JOIN Unit u ON u.UnitID = wl.ObjectID
		LEFT JOIN UnitType uut ON uut.UnitTypeID = u.UnitTypeID
		LEFT JOIN UnitType ut ON ut.UnitTypeID = wl.ObjectID
		WHERE wl.DateSatisfied IS NULL
			AND wl.DateRemoved IS NULL
			AND ((lilip.PropertyID IN (SELECT Value FROM @propertyIDs)) OR
				 (lip.PropertyID IN (SELECT Value FROM @propertyIDs)) OR
				 (uut.PropertyID IN (SELECT Value FROM @propertyIDs)) OR
				 (ut.PropertyID IN (SELECT Value FROM @propertyIDs)))	
			AND wl.ObjectType IN (SELECT Value FROM @objectTypes)

	UPDATE #WaitingLists SET PropertyName = (SELECT p.Name 
											 FROM Property p
											 WHERE p.PropertyID = #WaitingLists.PropertyID)

	UPDATE #WaitingLists SET OnWaitingList = (SELECT COUNT(*) 
											  FROM WaitingList wl
											  WHERE wl.ObjectID = #WaitingLists.ObjectID
												AND wl.DateSatisfied IS NULL
												AND wl.DateRemoved IS NULL)

	-- Update vacant Rentable Items
	UPDATE #WaitingLists SET Vacant = (SELECT CASE WHEN COUNT(*) > 0 THEN 0 ELSE 1 END
									   FROM LeaseLedgerItem lli
									   INNER JOIN Lease l on l.LeaseID = lli.LeaseID
									   WHERE lli.LedgerItemID = #WaitingLists.ObjectID
											 -- Currently being billed
										AND ((l.LeaseStatus IN ('Current', 'Under Eviction')
											  AND lli.StartDate <= @date
											  AND lli.EndDate >= @date) OR
											 -- Reserved
											 (l.LeaseStatus IN ('Pending', 'Pending Transfer', 'Pending Renewal')
											  AND lli.EndDate >= @date)))
	WHERE ObjectType = 'RentableItem'		

	-- Update notice to vacate Rentable Items
	UPDATE #WaitingLists SET NoticeToVacate = CASE WHEN
												   -- Current lease has given notice
													  (SELECT COUNT(*)
													   FROM LeaseLedgerItem lli
													   INNER JOIN Lease l on l.LeaseID = lli.LeaseID
														-- Person who hasn't given notice
													   LEFT JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.MoveOutDate IS NOT NULL
													   WHERE lli.LedgerItemID = #WaitingLists.ObjectID
															 -- Currently being billed
														AND l.LeaseStatus IN ('Current', 'Under Eviction')
														AND lli.StartDate <= @date
														AND lli.EndDate >= @date
														-- No person that hasn't given notice
														AND pl.PersonID IS NULL) = 0
													AND -- No pending lease												  
													  (SELECT COUNT(*)
													   FROM LeaseLedgerItem lli
													   INNER JOIN Lease l on l.LeaseID = lli.LeaseID											   
													   WHERE lli.LedgerItemID = #WaitingLists.ObjectID													
														AND l.LeaseStatus IN ('Pending', 'Pending Transfer', 'Pending Renewal')												
														AND lli.EndDate >= @date) = 0 
												THEN 1
												ELSE 0
												END
	WHERE ObjectType = 'RentableItem' AND Vacant = 0	


	-- Update vacant Units
	UPDATE #WaitingLists SET Vacant = (SELECT CASE WHEN COUNT(*) > 0 THEN 0 ELSE 1 END
									   FROM Lease l
									   INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
									   WHERE ulg.UnitID = #WaitingLists.ObjectID										 
										AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Pending', 'Pending Transfer', 'Pending Renewal'))
	WHERE ObjectType = 'Unit'		

	-- Update notice to vacate Rentable Items
	UPDATE #WaitingLists SET NoticeToVacate = CASE WHEN 
												  -- Current lease has given notice
												  (SELECT COUNT(*)
												   FROM Lease l
												   INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
												   LEFT JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.MoveOutDate IS NOT NULL
												   WHERE ulg.UnitID = #WaitingLists.ObjectID													 
													AND l.LeaseStatus IN ('Current', 'Under Eviction')
													AND pl.PersonID IS NULL) = 0
												AND 
													-- No pending lease
												  (SELECT COUNT(*)
												   FROM Lease l
												   INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
												   WHERE ulg.UnitID = #WaitingLists.ObjectID										 
													AND l.LeaseStatus IN ('Pending', 'Pending Transfer', 'Pending Renewal')) = 0
												THEN 1
												ELSE 0
												END
	WHERE ObjectType = 'Unit' AND Vacant = 0								
																	

	-- Update vacant Rentable Item Types count
	UPDATE #WaitingLists SET Vacant = (SELECT COUNT(*) FROM LedgerItem li WHERE li.LedgerItemPoolID = #WaitingLists.ObjectID)  - 
									  (SELECT COUNT(DISTINCT li.LedgerItemID)
									   FROM LedgerItemPool lip								   
									   INNER JOIN LedgerItem li on lip.LedgerItemPoolID = li.LedgerItemPoolID
									   INNER JOIN LeaseLedgerItem lli ON li.LedgerItemID = lli.LedgerItemID
									   INNER JOIN Lease l on l.LeaseID = lli.LeaseID
									   WHERE lip.LedgerItemPoolID = #WaitingLists.ObjectID
											 -- Currently being billed
										AND ((l.LeaseStatus IN ('Current', 'Under Eviction')
											  AND lli.StartDate <= @date
											  AND lli.EndDate >= @date) OR
											 -- Reserved
											 (l.LeaseStatus IN ('Pending', 'Pending Transfer', 'Pending Renewal')
											  AND lli.EndDate >= @date)))
	WHERE ObjectType = 'RentableItemType'		
										

	-- Update notice to vacate Rentable Items
	UPDATE #WaitingLists SET NoticeToVacate = 
												-- Get count of leases that are renting an item of the given type
												-- that have given notice and then make sure that item hasn't
												-- been reserved by another lease									
												  (SELECT COUNT(DISTINCT li.LedgerItemID)
												   FROM LedgerItemPool lip								   
												   INNER JOIN LedgerItem li on lip.LedgerItemPoolID = li.LedgerItemPoolID
												   INNER JOIN LeaseLedgerItem lli ON li.LedgerItemID = lli.LedgerItemID
												   INNER JOIN Lease l on l.LeaseID = lli.LeaseID
													-- Person who hasn't given notice
												   LEFT JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.MoveOutDate IS NULL
												   WHERE lip.LedgerItemPoolID = #WaitingLists.ObjectID
														 -- Currently being billed
													AND l.LeaseStatus IN ('Current', 'Under Eviction')
													AND lli.StartDate <= @date
													AND lli.EndDate >= @date
													-- No person that hasn't given notice
													AND pl.PersonID IS NULL
													AND NOT EXISTS (SELECT *
																	FROM LeaseLedgerItem lli2
																	INNER JOIN Lease l2 on l2.LeaseID = lli2.LeaseID
																   WHERE lli2.LedgerItemID = lli.LedgerItemID
																	AND l2.LeaseStatus IN ('Current', 'Under Eviction', 'Pending', 'Pending Transfer', 'Pending Renewal')												
																	AND l2.LeaseID <> l.LeaseID
																	AND lli2.EndDate >= @date))									
	WHERE ObjectType = 'RentableItemType'



	-- Update vacant Unit Types
	UPDATE #WaitingLists SET Vacant = (SELECT COUNT(*) FROM Unit WHERE UnitTypeID = #WaitingLists.ObjectID) -
									  (SELECT COUNT(DISTINCT u.UnitID)
									   FROM UnitType ut 
									   INNER JOIN Unit u ON u.UnitTypeID = ut.UnitTypeID
									   INNER JOIN UnitLeaseGroup ulg ON ulg.UnitID = u.UnitID
									   INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
									   WHERE ut.UnitTypeID = #WaitingLists.ObjectID										 
										AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Pending', 'Pending Transfer', 'Pending Renewal'))
	WHERE ObjectType = 'UnitType'		

	UPDATE #WaitingLists SET NoticeToVacate = 
									  (SELECT COUNT(DISTINCT u.UnitID)
									   FROM UnitType ut 
									   INNER JOIN Unit u ON u.UnitTypeID = ut.UnitTypeID
									   INNER JOIN UnitLeaseGroup ulg ON ulg.UnitID = u.UnitID
									   INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
									   -- Person who hasn't given notice
									   LEFT JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.MoveOutDate IS NULL
									   WHERE ut.UnitTypeID = #WaitingLists.ObjectID										 
										AND l.LeaseStatus IN ('Current', 'Under Eviction')
										AND pl.PersonID IS NULL
										AND NOT EXISTS (SELECT * 
														FROM UnitLeaseGroup ulg2
														INNER JOIN Lease l2 ON l2.UnitLeaseGroupID = ulg2.UnitLeaseGroupID
														WHERE ulg2.UnitID = u.UnitID
															AND l2.LeaseStatus IN ('Current', 'Under Eviction', 'Pending', 'Pending Transfer', 'Pending Renewal')
															AND l2.LeaseID <> l.LeaseID))
	WHERE ObjectType = 'UnitType'		
												
	SELECT * FROM #WaitingLists

END
GO
