SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Olsen
-- Create date: 6/4/2014
-- Description:	Gets the occupancy status of each unit
--				for a given property
-- =============================================
CREATE PROCEDURE [dbo].[GetConsolodatedOccupancyNumbers]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@date date,
	@accountingPeriodID uniqueidentifier,
	@propertyIDs GuidCollection READONLY	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #OccupantsPropertyIDs ( PropertyID uniqueidentifier, [Date] date )
	INSERT INTO #OccupantsPropertyIDs 
		SELECT pids.Value, COALESCE(pap.EndDate, @date) 
		FROM @propertyIDs pids
			LEFT JOIN PropertyAccountingPeriod pap ON pap.PropertyID = pids.Value AND pap.AccountingPeriodID = @accountingPeriodID

	CREATE TABLE #Occupants 
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		OccupiedUnitLeaseGroupID uniqueidentifier null,
		OccupiedLastLeaseID uniqueidentifier null,
		OccupiedMoveInDate date null,
		OccupiedNTVDate date null,
		OccupiedMoveOutDate date null,
		OccupiedIsMovedOut bit null		
	)

	CREATE TABLE #LeasesWantingToBeInUnits (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		PendingUnitLeaseGroupID uniqueidentifier null,
		PendingLeaseID uniqueidentifier,
		PendingApplicationDate date null,
		PendingMoveInDate date null,
		PendingMoveOutDate date null,
		LeaseStatus nvarchar(100) null)

    INSERT INTO #Occupants
		SELECT PropertyID, UnitID, Number, UnitLeaseGroupID, OccupiedLastLeaseID, MoveInDate, OccupiedNTVDate, MoveOutDate, OccupiedIsMovedOut FROM 
			(SELECT DISTINCT
				b.PropertyID,
				u.UnitID,
				u.Number,
				ulg.UnitLeaseGroupID,
				-- Get the minimum move in date for all people
				-- tied to the UnitLeaseGroup. We don't care what status, just
				-- that they lived there
				MIN(pl.MoveInDate) AS 'MoveInDate',
				-- If everyone on the last lease has a move out date then set
				-- the NTV Date to the max NoticeGivenDate for all the people tied to that lease
				CASE WHEN plmo.PersonLeaseID IS NULL THEN MAX(lastPersonLease.NoticeGivenDate) ELSE NULL END AS 'OccupiedNTVDate',
				-- If everyone on the last lease has a move out date then set
				-- the move out date tot he max move out date for all the people tied to that lease
				CASE WHEN plmo.PersonLeaseID IS NULL THEN MAX(lastPersonLease.MoveOutDate) ELSE NULL END AS 'MoveOutDate',
				-- If there exists a Former or Evicted lease then the residents actually moved out
				-- and we then know that the MoveOutDate is a legitmate hard move out date. Othewise,
				-- the move out date is just an intended move out date.
				CASE WHEN fl.LeaseID IS NULL THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS 'OccupiedIsMovedOut',
				lastLease.LeaseID AS 'OccupiedLastLeaseID',
				#pids.[Date]				
			FROM UnitLeaseGroup ulg
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN #OccupantsPropertyIDs #pids ON #pids.PropertyID = b.PropertyID
			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
			LEFT JOIN Lease fl ON fl.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND fl.LeaseStatus IN ('Former', 'Evicted')
			-- Get the last lease, oldest end date
			INNER JOIN Lease lastLease ON lastLease.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND lastLease.LeaseID = (SELECT TOP 1 LeaseID 
																													 FROM Lease 
																													 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
																														AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed', 'Pending Renewal') 
																												     ORDER BY LeaseEndDate DESC, DateCreated DESC)
			-- Get everyone on the last lease																													 
			INNER JOIN PersonLease lastPersonLease ON lastPersonLease.LeaseID = lastLease.LeaseID
			-- Someone on the last lease that hasn't given a move out date
			LEFT JOIN PersonLease plmo ON plmo.LeaseID = lastLease.LeaseID AND plmo.MoveOutDate IS NULL
			WHERE l.LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed') -- Only deal with actually occupying lease statuses
				AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed') -- Don't get move in date from Pending, Denied, or Cancelled
				AND u.AccountID = @accountID
				AND u.ExcludedFromOccupancy = 0
				AND (u.DateRemoved IS NULL OR u.DateRemoved > #pids.[Date])
				AND u.IsHoldingUnit = 0
			GROUP BY b.PropertyID, ulg.UnitLeaseGroupID, lastLease.LeaseID, u.UnitID, u.Number, u.PaddedNumber, fl.LeaseID, plmo.PersonLeaseID, #pids.[Date]) OccupancyHistory
		-- The residents had to have moved in prior to the report date
		WHERE MoveInDate <= [Date]
		-- There isn't a MoveOutDate so they are still occupied the unit
		-- OR they haven't moved out regardless of the move out date
		-- OR if they have moved out, then the MoveOutDate is after the report date
		AND (MoveOutDate IS NULL OR (OccupiedIsMovedOut = 0) OR (OccupiedIsMovedOut = 1 AND MoveOutDate >= [Date]))

	-- Make sure there is a row for every unit
	INSERT INTO #Occupants
		SELECT b.PropertyID,
			   u.UnitID,
			   u.Number,
			   null,
			   null,
			   null,
			   null, 
			   null,
			   null
		FROM Unit u 
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN #OccupantsPropertyIDs #pids ON #pids.PropertyID = b.PropertyID
			LEFT JOIN #Occupants #o ON #o.UnitID = u.UnitID
		WHERE #o.UnitID IS NULL
			AND u.AccountID = @accountID
			AND u.ExcludedFromOccupancy = 0
			AND (u.DateRemoved IS NULL OR u.DateRemoved > #pids.[Date])
			AND u.IsHoldingUnit = 0

	INSERT #LeasesWantingToBeInUnits
		SELECT PropertyID, UnitID, UnitLeaseGroupID, LeaseID, ApplicationDate, MoveInDate, MoveOutDate, LeaseStatus FROM (
			SELECT	DISTINCT
					b.PropertyID,
					u.UnitID,
					ulg.UnitLeaseGroupID,
					l.LeaseID,
					MIN(pl.ApplicationDate) AS 'ApplicationDate',
					MIN(pl.MoveInDate) AS 'MoveInDate',
					MAX(pl.MoveOutDate) AS 'MoveOutDate',
					l.LeaseStatus,
					#pids.[Date]
				FROM UnitLeaseGroup ulg
					INNER JOIN Unit u ON u.UnitID = ulg.UnitID
					INNER JOIN Building b ON b.BuildingID = u.BuildingID
					INNER JOIN #OccupantsPropertyIDs #pids ON #pids.PropertyID = b.PropertyID
					INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				WHERE l.LeaseID = (SELECT TOP 1 LeaseID 
									FROM Lease
									WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
									ORDER BY DateCreated)
					AND (u.DateRemoved IS NULL OR u.DateRemoved > #pids.[Date])
				GROUP BY b.PropertyID, ulg.UnitLeaseGroupID, l.LeaseID, u.UnitID, u.Number, u.PaddedNumber, l.LeaseStatus, #pids.[Date]) ApplicantHistory
			-- Make sure they applied on or prior to the report date
		WHERE ApplicationDate <= [Date]
			-- If the lease is still pending then count it as pre-leased, otherwise
			-- only count it as pre-leased if they haven't moved in yet
			AND (LeaseStatus IN ('Pending', 'Pending Transfer') OR MoveInDate > [Date])
			-- Make sure if the lease was denied or cancelled, that we don't 
			-- include it in the set if the denied or cancelled date is passed
			AND ((LeaseStatus NOT IN ('Denied', 'Cancelled')) OR (LeaseStatus IN ('Denied', 'Cancelled') AND MoveOutDate > [Date]))

	-- Delete duplicated apps
	DELETE #lwtbiu2
	FROM #LeasesWantingToBeInUnits #lwtbiu2
		INNER JOIN #LeasesWantingToBeInUnits #lwtbiu1 ON #lwtbiu2.UnitID = #lwtbiu1.UnitID AND #lwtbiu2.PendingUnitLeaseGroupID <> #lwtbiu1.PendingUnitLeaseGroupID
	WHERE #lwtbiu1.PendingUnitLeaseGroupID = (SELECT TOP 1 PendingUnitLeaseGroupID
												FROM #LeasesWantingToBeInUnits 
												WHERE UnitID = #lwtbiu1.UnitID
												ORDER BY PendingApplicationDate DESC)	
		
	-- Delete duplicate occupants											
	DELETE #o2
	FROM #Occupants #o2
		INNER JOIN #Occupants #o1 ON #o2.UnitID = #o1.UnitID AND #o1.OccupiedUnitLeaseGroupID <> #o2.OccupiedUnitLeaseGroupID
	WHERE #o1.OccupiedUnitLeaseGroupID = (SELECT TOP 1 OccupiedUnitLeaseGroupID
												FROM #Occupants 
												WHERE UnitID = #o1.UnitID
												ORDER BY OccupiedMoveInDate DESC)														

	SELECT 
		#o.PropertyID,
		#o.UnitID, 
		#o.UnitNumber,		
		#o.OccupiedUnitLeaseGroupID, 
		#o.OccupiedLastLeaseID,
		#o.OccupiedMoveInDate,
		#o.OccupiedNTVDate,
		#o.OccupiedMoveOutDate,
		#o.OccupiedIsMovedOut,
		#lwtbiu.PendingUnitLeaseGroupID,
		#lwtbiu.PendingLeaseID,
		#lwtbiu.PendingApplicationDate,
		#lwtbiu.PendingMoveInDate 
	FROM #Occupants #o
		LEFT JOIN #LeasesWantingToBeInUnits #lwtbiu ON #o.UnitID = #lwtbiu.UnitID
	ORDER BY #o.UnitNumber
END
GO
