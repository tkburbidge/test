SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO









-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Nov. 23, 2015
-- Description:	BSR Box Score / Occupancy
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_BSR_BoxScoreOccupancy] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Occupancy (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) null,
		AverageSqFeet int null,
		AverageRent money null,
		Units int null,
		OccupiedNoNotice int null,
		VacantRented int null,
		VacantUnrented int null,
		NoticeRented int null,
		NoticeUnrented int null,
		Available int null,
		Models int null,
		Down int null,
		[Admin] int null,
		OccupancyWithNonRevenue int null,
		PercentLeased decimal(12, 4) null,
		PercentTrend decimal(12, 4) null)

	CREATE TABLE #Activity (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) null,
		Units int null,
		MoveIns int null,
		MoveOuts int null,
		Notice int null,
		SkipEarlyTermination int null,
		OnSiteTransfer int null,
		MonthToMonth int null,
		Renewals int null,
		Eviction int null)

	CREATE TABLE #Traffic (				-- Note - Traffic is a great movie too!
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) null,
		Traffic int null,
		Shows int null, 
		Applied int null,
		Unqualified int null,
		Approved int null,
		Denied int null)



	CREATE TABLE #LeasesAndUnits (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(50) null,
		OccupiedUnitLeaseGroupID uniqueidentifier null,
		OccupiedLastLeaseID uniqueidentifier null,
		OccupiedMoveInDate date null,
		OccupiedNTVDate date null,
		OccupiedMoveOutDate date null,
		OccupiedIsMovedOut bit null,
		PendingUnitLeaseGroupID uniqueidentifier null,
		PendingLeaseID uniqueidentifier null,
		PendingApplicationDate date null,
		PendingMoveInDate date null)

	CREATE TABLE #UnitFeets (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		Feets int null)

	CREATE TABLE #Rents (
		PropertyID uniqueidentifier not null,
		LeaseID uniqueidentifier not null,
		Rent money null)

	CREATE TABLE #UnitsAndStati (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		[Status] nvarchar(50) null,
		Divider int null)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier null,
		StartDate date null,
		EndDate date null)

	INSERT #PropertiesAndDates
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	INSERT #UnitFeets
		SELECT	ut.PropertyID, u.UnitID, ut.SquareFootage
			FROM Unit u 
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND u.ExcludedFromOccupancy = 0 AND (u.DateRemoved IS NULL OR u.DateRemoved > @endDate)

	INSERT #Rents
		SELECT ut.PropertyID, lli.LeaseID, SUM(lli.Amount)
			FROM LeaseLedgerItem lli
				INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
				INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
			WHERE l.LeaseStatus IN ('Current', 'Under Eviction')
			GROUP BY ut.PropertyID, lli.LeaseID

	INSERT #UnitsAndStati
		SELECT ut.PropertyID, u.UnitID, [Stats].[Status], 0
			FROM Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
				CROSS APPLY GetUnitStatusByUnitID(u.UnitID, #pad.EndDate) [Stats]

	INSERT #Occupancy
		SELECT PropertyID, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null
			FROM #PropertiesAndDates

	INSERT #Activity
		SELECT PropertyID, null, null, null, null, null, null, null, null, null, null
			FROM #PropertiesAndDates	
			
	INSERT #Traffic
		SELECT PropertyID, null, null, null, null, null, null, null	
			FROM #PropertiesAndDates

	--SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT PropertyID FROM #PropertiesAndDates))

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @endDate, @accountingPeriodID, @propertyIDs	

	UPDATE #Occupancy SET Units = (SELECT COUNT(*)
									   FROM #UnitFeets 
									   WHERE PropertyID = #Occupancy.PropertyID)

	UPDATE #Occupancy SET AverageSqFeet = (SELECT AVG(Feets)
											   FROM #UnitFeets
											   WHERE #Occupancy.PropertyID = PropertyID)

	UPDATE #Occupancy SET AverageRent = (SELECT AVG(Rent)
											 FROM #Rents
											 WHERE PropertyID = #Occupancy.PropertyID)

	UPDATE #Occupancy SET OccupiedNoNotice = (SELECT COUNT(*)
												  FROM #LeasesAndUnits
												  WHERE OccupiedUnitLeaseGroupID IS NOT NULL
												    AND OccupiedMoveOutDate IS NULL
													AND PropertyID = #Occupancy.PropertyID)

	UPDATE #Occupancy SET VacantRented = (SELECT COUNT(*)
											  FROM #LeasesAndUnits 
											  WHERE OccupiedUnitLeaseGroupID IS NULL
											    AND PendingUnitLeaseGroupID IS NOT NULL
												AND PropertyID = #Occupancy.PropertyID)

	UPDATE #Occupancy SET VacantUnrented = (SELECT COUNT(*) 
												FROM #LeasesAndUnits
												WHERE OccupiedUnitLeaseGroupID IS NULL
												  AND PendingUnitLeaseGroupID IS NULL
												  AND PropertyID = #Occupancy.PropertyID)

	UPDATE #Occupancy SET NoticeRented = (SELECT COUNT(*)
											  FROM #LeasesAndUnits
											  WHERE OccupiedUnitLeaseGroupID IS NOT NULL
											    AND OccupiedMoveOutDate IS NOT NULL
												AND PendingUnitLeaseGroupID IS NOT NULL
												AND PropertyID = #Occupancy.PropertyID)

	UPDATE #Occupancy SET NoticeUnrented = (SELECT COUNT(*)
											    FROM #LeasesAndUnits
											    WHERE OccupiedUnitLeaseGroupID IS NOT NULL
											      AND OccupiedMoveOutDate IS NOT NULL
												  AND PendingUnitLeaseGroupID IS NULL
												  AND PropertyID = #Occupancy.PropertyID)

	UPDATE #Occupancy SET Models = (SELECT COUNT(*)
										FROM #UnitsAndStati
										WHERE PropertyID = #Occupancy.PropertyID
										  AND [Status] = 'Model')

	UPDATE #Occupancy SET Down = (SELECT COUNT(*)
										FROM #UnitsAndStati
										WHERE PropertyID = #Occupancy.PropertyID
										  AND [Status] = 'Down')

	UPDATE #Occupancy SET [Admin] = (SELECT COUNT(*)
										FROM #UnitsAndStati
										WHERE PropertyID = #Occupancy.PropertyID
										  AND [Status] = 'Admin')

	UPDATE #Occupancy SET OccupancyWithNonRevenue = (SELECT COUNT(*) 
														FROM #LeasesAndUnits
														WHERE OccupiedUnitLeaseGroupID IS NOT NULL
														  AND PropertyID = #Occupancy.PropertyID)

	UPDATE #Occupancy SET OccupancyWithNonRevenue = ISNULL(OccupancyWithNonRevenue, 0) + (SELECT COUNT(*)
																							  FROM #UnitsAndStati
																							  WHERE [Status] IN ('Model', 'Admin', 'Down')
																							    AND PropertyID = #Occupancy.PropertyID)

	UPDATE #occ	SET PercentLeased = CAST(#occ.OccupiedNoNotice + #occ.VacantRented + #occ.NoticeUnrented + #occ.NoticeRented AS decimal(12, 4))
		FROM #Occupancy #occ
			INNER JOIN #LeasesAndUnits #lau ON #occ.PropertyID = #lau.PropertyID

	UPDATE #occ	SET PercentTrend = CAST(#occ.OccupiedNoNotice + #occ.VacantRented + #occ.NoticeRented AS decimal(12, 4))
		FROM #Occupancy #occ
			INNER JOIN #LeasesAndUnits #lau ON #occ.PropertyID = #lau.PropertyID		

	UPDATE #UnitsAndStati SET Divider = ((SELECT COUNT(*) 
											  FROM #UnitsAndStati
											  where #UnitsAndStati.PropertyID = PropertyID)
										 -
										 (SELECT COUNT(*)
											  FROM #UnitsAndStati
											  WHERE [Status] IN ('Model', 'Admin', 'Down')
											    AND PropertyID = #UnitsAndStati.PropertyID))

	UPDATE #occ	SET PercentLeased = PercentLeased / CAST(#uas.Divider AS decimal(12, 4))
		FROM #Occupancy #occ
			INNER JOIN #UnitsAndStati #uas ON #occ.PropertyID = #uas.PropertyID

	UPDATE #occ	SET PercentTrend = PercentTrend / CAST(#uas.Divider AS decimal(12, 4))
		FROM #Occupancy #occ
			INNER JOIN #UnitsAndStati #uas ON #occ.PropertyID = #uas.PropertyID


	UPDATE #Activity SET Units = (SELECT COUNT(*)
									FROM #UnitFeets 
									WHERE PropertyID = #Activity.PropertyID)

	UPDATE #Activity SET MoveIns = (SELECT COUNT(DISTINCT l.LeaseID)
										FROM Lease l
											INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
											INNER JOIN Unit u ON ulg.UnitID = u.UnitID
											INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
											INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
											INNER JOIN PersonLease plMI ON l.LeaseID = plMI.LeaseID AND plMI.MoveInDate >= #pad.StartDate AND plMI.MoveInDate <= #pad.EndDate
											LEFT JOIN PersonLease plMINull ON l.LeaseID = plMINull.LeaseID AND plMINull.MoveInDate < #pad.StartDate
										WHERE #pad.PropertyID = #Activity.PropertyID
										  AND plMINull.PersonLeaseID IS NULL)

	UPDATE #Activity SET MoveOuts = (SELECT COUNT(DISTINCT l.LeaseID)
										FROM Lease l
											INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
											INNER JOIN Unit u ON ulg.UnitID = u.UnitID
											INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
											INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
											INNER JOIN PersonLease plMO ON l.LeaseID = plMO.LeaseID AND plMO.MoveOutDate >= #pad.StartDate AND plMO.MoveOutDate <= #pad.EndDate
											LEFT JOIN PersonLease plMONull ON l.LeaseID = plMONull.LeaseID AND plMONull.MoveOutDate > #pad.EndDate
										WHERE #pad.PropertyID = #Activity.PropertyID
										  AND plMONull.PersonLeaseID IS NULL)

	UPDATE #Activity SET Notice = (SELECT COUNT(DISTINCT l.LeaseID)
										FROM Lease l
											INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
											INNER JOIN Unit u ON ulg.UnitID = u.UnitID
											INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
											INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
											INNER JOIN PersonLease plNo ON l.LeaseID = plNo.LeaseID AND plNo.NoticeGivenDate >= #pad.StartDate AND plNo.NoticeGivenDate <= #pad.EndDate
											LEFT JOIN PersonLease plNoNull ON l.LeaseID = plNoNull.LeaseID AND plNoNull.NoticeGivenDate < #pad.StartDate
										WHERE #pad.PropertyID = #Activity.PropertyID
										  AND plNoNull.PersonLeaseID IS NULL)
										  
	UPDATE #Activity SET SkipEarlyTermination = (SELECT COUNT(DISTINCT l.LeaseID)
													FROM Lease l
														INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
														INNER JOIN Unit u ON ulg.UnitID = u.UnitID
														INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
														INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
														INNER JOIN PersonLease plMO ON l.LeaseID = plMO.LeaseID AND plMO.MoveOutDate >= #pad.StartDate AND plMO.MoveOutDate <= #pad.EndDate
														LEFT JOIN PersonLease plMONull ON l.LeaseID = plMONull.LeaseID AND plMONull.MoveOutDate > #pad.EndDate
													WHERE #pad.PropertyID = #Activity.PropertyID
													  AND plMONull.PersonLeaseID IS NULL
													  AND ((SELECT MAX(MoveOutDate)
															   FROM PersonLease
															   WHERE LeaseID = l.LeaseID
															     AND MoveOutDate <= #pad.EndDate) < l.LeaseEndDate))

	UPDATE #Activity SET OnSiteTransfer = (SELECT COUNT(DISTINCT l.LeaseID)
												FROM Lease l
													INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
													INNER JOIN Unit u ON ulg.UnitID = u.UnitID
													INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
													INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
													INNER JOIN PersonLease plMI ON l.LeaseID = plMI.LeaseID AND plMI.MoveInDate >= #pad.StartDate AND plMI.MoveInDate <= #pad.EndDate
													LEFT JOIN PersonLease plMINull ON l.LeaseID = plMINull.LeaseID AND plMINull.MoveInDate < #pad.StartDate
												WHERE #pad.PropertyID = #Activity.PropertyID
												  AND plMINull.PersonLeaseID IS NULL
												  AND ulg.PreviousUnitLeaseGroupID IS NOT NULL)

	UPDATE #Activity SET MonthToMonth = (SELECT COUNT(l.LeaseID)
											FROM Lease l
												INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
												INNER JOIN Unit u ON ulg.UnitID = u.UnitID
												INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
												INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
											WHERE l.LeaseEndDate < #pad.EndDate
											  AND l.LeaseStatus IN ('Current', 'Under Eviction')
											  AND #pad.PropertyID = #Activity.PropertyID)

	UPDATE #Activity SET Renewals = (SELECT COUNT(DISTINCT l.LeaseID)
										FROM Lease l
											INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
											INNER JOIN Unit u ON ulg.UnitID = u.UnitID
											INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
											INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
											INNER JOIN Lease prevLease ON ulg.UnitLeaseGroupID = prevLease.UnitLeaseGroupID AND prevLease.LeaseStartDate < l.LeaseStartDate
										WHERE #pad.PropertyID = #Activity.PropertyID
										  AND l.LeaseStartDate >= #pad.StartDate
										  AND l.LeaseEndDate <= #pad.EndDate)

	UPDATE #Activity SET Eviction = (SELECT COUNT(DISTINCT l.LeaseID)
										FROM Lease l 
											INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
											INNER JOIN Unit u ON ulg.UnitID = u.UnitID
											INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
											INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
											INNER JOIN PersonLease plMO ON l.LeaseID = plMO.LeaseID AND plMO.MoveOutDate >= #pad.StartDate AND plMO.MoveOutDate <= #pad.EndDate
											LEFT JOIN PersonLease plMONull ON l.LeaseID = plMONull.LeaseID AND plMONull.MoveOutDate > #pad.EndDate
										WHERE #pad.PropertyID = #Activity.PropertyID
										  AND plMONull.PersonLeaseID IS NULL
										  AND l.LeaseStatus = 'Evicted')

	UPDATE #Traffic SET Traffic = (SELECT COUNT(DISTINCT pros.ProspectID)
									   FROM Prospect pros
										   INNER JOIN PersonNote pn ON pros.FirstPersonNoteID = pn.PersonNoteID
										   INNER JOIN #PropertiesAndDates #pad ON pn.PropertyID = #pad.PropertyID AND pn.[Date] >= #pad.StartDate AND pn.[Date] <= #pad.EndDate
									   WHERE #pad.PropertyID = #Traffic.PropertyID)

	UPDATE #Traffic SET Shows = (SELECT COUNT(DISTINCT pros.ProspectID)
									 FROM PersonNote pn
										 INNER JOIN Prospect pros ON pn.PersonID = pros.PersonID
										 INNER JOIN #PropertiesAndDates #pad ON pn.PropertyID = #pad.PropertyID
									 WHERE pn.InteractionType = 'Unit Shown'
									   AND pn.[Date] >= #pad.StartDate
									   AND pn.[Date] <= #pad.EndDate
									   AND #pad.PropertyID = #Traffic.PropertyID)

	UPDATE #Traffic SET Applied = (SELECT COUNT(DISTINCT l.LeaseID)
									   FROM Lease l
										   INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
										   INNER JOIN Unit u ON ulg.UnitID = u.UnitID
										   INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
										   INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
										   INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ApplicationDate >= #pad.StartDate AND pl.ApplicationDate <= #pad.EndDate
										   LEFT JOIN Lease prevL ON ulg.UnitLeaseGroupID = prevL.UnitLeaseGroupID AND prevL.LeaseCreated < l.LeaseCreated
									   WHERE ulg.PreviousUnitLeaseGroupID IS NULL
									     AND prevL.LeaseID IS NULL
										 AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																	 FROM PersonLease
																	 WHERE LeaseID = l.LeaseID
																	 ORDER BY ApplicationDate)
									 AND #pad.PropertyID = #Traffic.PropertyID)

	UPDATE #Traffic SET Unqualified = (SELECT COUNT(DISTINCT pros.ProspectID)
												   FROM Prospect pros
												INNER JOIN PropertyProspectSource pps ON pros.PropertyProspectSourceID = pps.PropertyProspectSourceID
												INNER JOIN #PropertiesAndDates #pad ON pps.PropertyID = #pad.PropertyID AND pros.LostDate >= #pad.StartDate AND pros.LostDate <= #pad.EndDate												
									   WHERE #pad.PropertyID = #Traffic.PropertyID
											AND pros.Unqualified = 1)

	UPDATE #Traffic SET Approved = (SELECT COUNT(DISTINCT #lau.PendingUnitLeaseGroupID)
										FROM #LeasesAndUnits #lau
											INNER JOIN Lease l ON #lau.PendingUnitLeaseGroupID = l.UnitLeaseGroupID
											INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ApprovalStatus IN ('Approved')
										WHERE #Traffic.PropertyID = #lau.PropertyID)

	UPDATE #Traffic SET Denied = (SELECT COUNT(DISTINCT l.LeaseID)
									  FROM Lease l
										  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
										  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
										  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
										  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
										  INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
										  LEFT JOIN PersonLease plMONull ON l.LeaseID = plMONull.LeaseID AND plMONull.MoveOutDate > #pad.EndDate
									  WHERE (pl.MoveOutDate >= #pad.StartDate AND pl.MoveOutDate <= #pad.EndDate)
									    AND l.LeaseStatus IN ('Denied')
										AND plMONull.PersonLeaseID IS NULL
									   AND #pad.PropertyID = #Traffic.PropertyID)

	UPDATE #Occupancy SET PropertyName = (SELECT prop.Name FROM Property prop WHERE #Occupancy.PropertyID = prop.PropertyID)
	UPDATE #Activity SET PropertyName = (SELECT prop.Name FROM Property prop WHERE #Activity.PropertyID = prop.PropertyID)
	UPDATE #Traffic SET PropertyName = (SELECT prop.Name FROM Property prop WHERE #Traffic.PropertyID = prop.PropertyID)

	SELECT * FROM #Occupancy ORDER BY PropertyID
	SELECT * FROM #Activity ORDER BY PropertyID
	SELECT * FROM #Traffic ORDER BY PropertyID

END




GO
