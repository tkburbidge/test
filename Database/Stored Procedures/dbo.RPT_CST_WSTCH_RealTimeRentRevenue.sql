SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_CST_WSTCH_RealTimeRentRevenue] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS

DECLARE @currentAccountingPeriod uniqueidentifier = (SELECT AccountingPeriodID FROM AccountingPeriod WHERE StartDate <= @date AND EndDate >= @date)
DECLARE @accountingPeriodID uniqueidentifier = null
DECLARE @minDate date
DECLARE @accountID bigint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	CREATE TABLE #RealTimeRevenue (
		PropertyID uniqueidentifier null,
		PropertyName nvarchar(100) null,
		Month1RentCharged money null,
		Month2RentCharged money null,
		Month3RentCharged money null,
		Occupancy decimal(13, 5) null,
		Exposure decimal(13, 5) null,
		SignedFutureLeases int null,
		SignedFutureLeasesMonth1 int null,
		SignedFutureLeasesMonth2 int null,
		SignedFutureLeasesMonth3 int null,
		SignedFutureLeasesMonth4 int null,
		SignedRenewalLeases int null,
		SignedRenewalLeasesMonth1 int null,
		SignedRenewalLeasesMonth2 int null,
		SignedRenewalLeasesMonth3 int null,
		SignedRenewalLeasesMonth4 int null,
		FutureIncome money null)

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

	CREATE TABLE #MyOccupancyWorksheet (
		PropertyID uniqueidentifier not null,
		UnitCount decimal(13, 5) null,
		Occupied decimal(13, 5) null,
		Vacant decimal(13, 5) null,
		VacantPreleased decimal(13, 5) null,
		NTV decimal(13, 5) null,
		NTVPreleased decimal(13, 5) null)

	CREATE TABLE #PastAccountingPeriods (
		[Sequence] int identity,
		AccountingPeriodID uniqueidentifier null)

	CREATE TABLE #PastPropertiesAndDates (
		[Sequence] int null,
		PropertyID uniqueidentifier null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #FutureAccountingPeriods (
		[Sequence] int identity,
		AccountingPeriodID uniqueidentifier null)

	CREATE TABLE #FuturePropertiesAndDates (
		[Sequence] int null,
		PropertyID uniqueidentifier null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #FutureIncomeLeases (
		PropertyID uniqueidentifier null,
		UnitID uniqueidentifier null,
		LeaseID uniqueidentifier null)

	CREATE TABLE #MyTransaction (
		TransactionID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		LedgerItemTypeID uniqueidentifier null,
		Amount money null, 
		TransactionDate date null)

	INSERT #PastAccountingPeriods
		SELECT AccountingPeriodID
			FROM (SELECT TOP 3 *
					  FROM AccountingPeriod
					  WHERE EndDate <= (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @currentAccountingPeriod)
					  ORDER BY EndDate DESC) [MySorter]
			ORDER BY EndDate

	INSERT #FutureAccountingPeriods
		SELECT TOP 4 AccountingPeriodID
			FROM AccountingPeriod 
			WHERE EndDate >= (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @currentAccountingPeriod)
			ORDER BY EndDate
	
	INSERT #PastPropertiesAndDates
		SELECT	#pastAPs.[Sequence], pIDs.Value, pap.StartDate, pap.EndDate
			FROM @propertyIDs pIDs
				INNER JOIN #PastAccountingPeriods #pastAPs ON 1=1
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND #pastAPs.AccountingPeriodID = pap.AccountingPeriodID

	INSERT #FuturePropertiesAndDates
		SELECT	#futureAPs.[Sequence], pIDs.Value, pap.StartDate, pap.EndDate
			FROM @propertyIDs pIDs
				INNER JOIN #FutureAccountingPeriods #futureAPs ON 1=1
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND #futureAPs.AccountingPeriodID = pap.AccountingPeriodID

	SET @minDate = (SELECT MIN(StartDate) FROM #PastPropertiesAndDates)
	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT PropertyID FROM #PastPropertiesAndDates))

	INSERT #MyTransaction
		SELECT	TransactionID,
				t.PropertyID,
				LedgerItemTypeID,
				Amount,
				TransactionDate
			FROM [Transaction] t
				INNER JOIN #PastPropertiesAndDates #ppad ON t.PropertyID = #ppad.PropertyID 
												AND #ppad.[Sequence] = 1					-- We really just need this propertyID, but because of [Sequence] we could get 3 of them
			WHERE TransactionDate >= @minDate

	INSERT #RealTimeRevenue 
		SELECT	DISTINCT
				prop.PropertyID,
				prop.Name,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null
			FROM #PastPropertiesAndDates #ppads
				INNER JOIN Property prop ON #ppads.PropertyID = prop.PropertyID
	
	UPDATE #RealTimeRevenue SET Month1RentCharged = ISNULL((SELECT SUM(t.Amount)
															  FROM #MyTransaction t
																   INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
																   INNER JOIN #PastPropertiesAndDates #ppad ON t.TransactionDate >= #ppad.StartDate AND t.TransactionDate <= #ppad.EndDate
														  													AND t.PropertyID = #ppad.PropertyID AND #ppad.[Sequence] = 1
															  WHERE t.PropertyID = #RealTimeRevenue.PropertyID), 0)
														  
	UPDATE #RealTimeRevenue SET Month2RentCharged = ISNULL((SELECT SUM(t.Amount)
															  FROM #MyTransaction t
																   INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
																   INNER JOIN #PastPropertiesAndDates #ppad ON t.TransactionDate >= #ppad.StartDate AND t.TransactionDate <= #ppad.EndDate
														  													AND t.PropertyID = #ppad.PropertyID AND #ppad.[Sequence] = 2
															  WHERE t.PropertyID = #RealTimeRevenue.PropertyID), 0)
	UPDATE #RealTimeRevenue SET Month3RentCharged = ISNULL((SELECT SUM(t.Amount)
															  FROM #MyTransaction t
																   INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
																   INNER JOIN #PastPropertiesAndDates #ppad ON t.TransactionDate >= #ppad.StartDate AND t.TransactionDate <= #ppad.EndDate
														  													AND t.PropertyID = #ppad.PropertyID AND #ppad.[Sequence] = 3
															  WHERE t.PropertyID = #RealTimeRevenue.PropertyID), 0)
														  				
	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @date, @accountingPeriodID, @propertyIDs	

	INSERT #MyOccupancyWorksheet
		SELECT DISTINCT PropertyID, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 
			FROM #LeasesAndUnits
		
	UPDATE #MyOccupancyWorksheet SET UnitCount = (SELECT CAST(COUNT(DISTINCT UnitID) AS decimal(13, 5))
													 FROM #LeasesAndUnits
													 WHERE #MyOccupancyWorksheet.PropertyID = PropertyID)								  

	UPDATE #MyOccupancyWorksheet SET Occupied = (SELECT CAST(COUNT(DISTINCT OccupiedUnitLeaseGroupID) AS decimal(13, 5))
													FROM #LeasesAndUnits
													WHERE #MyOccupancyWorksheet.PropertyID = PropertyID)

	UPDATE #MyOccupancyWorksheet SET Vacant = (SELECT CAST(COUNT(DISTINCT UnitID) AS decimal (13, 5))
												   FROM #LeasesAndUnits
												   WHERE OccupiedUnitLeaseGroupID IS NULL
												     AND #MyOccupancyWorksheet.PropertyID = PropertyID)

	UPDATE #MyOccupancyWorksheet SET VacantPreleased = (SELECT CAST(COUNT(DISTINCT UnitID) AS decimal (13, 5))
															FROM #LeasesAndUnits
															WHERE OccupiedUnitLeaseGroupID IS NULL
															  AND PendingUnitLeaseGroupID IS NOT NULL
															  AND #MyOccupancyWorksheet.PropertyID = PropertyID)

	UPDATE #MyOccupancyWorksheet SET NTV = (SELECT CAST(COUNT(DISTINCT UnitID) AS decimal (13, 5))
												FROM #LeasesAndUnits
												WHERE OccupiedUnitLeaseGroupID IS NOT NULL
												  AND OccupiedNTVDate > @date
												  AND #MyOccupancyWorksheet.PropertyID = PropertyID)

	UPDATE #MyOccupancyWorksheet SET NTVPreleased = (SELECT CAST(COUNT(DISTINCT UnitID) AS decimal (13, 5))
														 FROM #LeasesAndUnits
														 WHERE OccupiedUnitLeaseGroupID IS NOT NULL
														   AND OccupiedNTVDate > @date
														   AND PendingUnitLeaseGroupID IS NOT NULL
														   AND #MyOccupancyWorksheet.PropertyID = PropertyID)

	UPDATE #RealTimeRevenue SET Occupancy = (SELECT Occupied / UnitCount
												 FROM #MyOccupancyWorksheet
												 WHERE #RealTimeRevenue.PropertyID = PropertyID)

	UPDATE #RealTimeRevenue SET Exposure = (SELECT (Occupied - Vacant + VacantPreleased - NTV + NTVPreleased) / UnitCount
												FROM #MyOccupancyWorksheet
												WHERE #RealTimeRevenue.PropertyID = PropertyID)

	UPDATE #RealTimeRevenue SET SignedFutureLeases = (SELECT COUNT(DISTINCT #lau.UnitID)
														  FROM #LeasesAndUnits #lau
															  INNER JOIN Lease l ON #lau.PendingLeaseID = l.LeaseID
															  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
															  LEFT JOIN PersonLease plMinSignedDate ON l.LeaseID = plMinSignedDate.LeaseID 
																						AND plMinSignedDate.LeaseSignedDate < pl.LeaseSignedDate
														  WHERE pl.LeaseSignedDate <= @date
														    AND #RealTimeRevenue.PropertyID = #lau.PropertyID
															AND plMinSignedDate.PersonLeaseID IS NULL)

	UPDATE #RealTimeRevenue SET SignedFutureLeasesMonth1 = (SELECT COUNT(DISTINCT #lau.UnitID)
																FROM #LeasesAndUnits #lau
																	INNER JOIN Lease l ON #lau.PendingLeaseID = l.LeaseID
																	INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
																	INNER JOIN #FuturePropertiesAndDates #fpad ON #lau.PropertyID = #fpad.PropertyID
																						AND #fpad.[Sequence] = 1
																	LEFT JOIN PersonLease plMinSignedDate ON l.LeaseID = plMinSignedDate.LeaseID
																						AND plMinSignedDate.LeaseSignedDate < pl.LeaseSignedDate
																WHERE pl.LeaseSignedDate >= #fpad.StartDate
																  AND pl.LeaseSignedDate <= #fpad.EndDate
																  AND plMinSignedDate.PersonLeaseID IS NULL
																  AND #RealTimeRevenue.PropertyID = #lau.PropertyID)

	UPDATE #RealTimeRevenue SET SignedFutureLeasesMonth1 = (SELECT COUNT(DISTINCT #lau.UnitID)
																FROM #LeasesAndUnits #lau
																	INNER JOIN Lease l ON #lau.PendingLeaseID = l.LeaseID
																	INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
																	INNER JOIN #FuturePropertiesAndDates #fpad ON #lau.PropertyID = #fpad.PropertyID
																						AND #fpad.[Sequence] = 1
																	LEFT JOIN PersonLease plMinSignedDate ON l.LeaseID = plMinSignedDate.LeaseID
																						AND plMinSignedDate.LeaseSignedDate < pl.LeaseSignedDate
																WHERE pl.LeaseSignedDate >= #fpad.StartDate
																  AND pl.LeaseSignedDate <= #fpad.EndDate
																  AND plMinSignedDate.PersonLeaseID IS NULL
																  AND #RealTimeRevenue.PropertyID = #lau.PropertyID)
	
	UPDATE #RealTimeRevenue SET SignedFutureLeasesMonth2 = (SELECT COUNT(DISTINCT #lau.UnitID)
																FROM #LeasesAndUnits #lau
																	INNER JOIN Lease l ON #lau.PendingLeaseID = l.LeaseID
																	INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
																	INNER JOIN #FuturePropertiesAndDates #fpad ON #lau.PropertyID = #fpad.PropertyID
																						AND #fpad.[Sequence] = 2
																	LEFT JOIN PersonLease plMinSignedDate ON l.LeaseID = plMinSignedDate.LeaseID
																						AND plMinSignedDate.LeaseSignedDate < pl.LeaseSignedDate
																WHERE pl.LeaseSignedDate >= #fpad.StartDate
																  AND pl.LeaseSignedDate <= #fpad.EndDate
																  AND plMinSignedDate.PersonLeaseID IS NULL
																  AND #RealTimeRevenue.PropertyID = #lau.PropertyID)	

	UPDATE #RealTimeRevenue SET SignedFutureLeasesMonth3 = (SELECT COUNT(DISTINCT #lau.UnitID)
																FROM #LeasesAndUnits #lau
																	INNER JOIN Lease l ON #lau.PendingLeaseID = l.LeaseID
																	INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
																	INNER JOIN #FuturePropertiesAndDates #fpad ON #lau.PropertyID = #fpad.PropertyID
																						AND #fpad.[Sequence] = 3
																	LEFT JOIN PersonLease plMinSignedDate ON l.LeaseID = plMinSignedDate.LeaseID
																						AND plMinSignedDate.LeaseSignedDate < pl.LeaseSignedDate
																WHERE pl.LeaseSignedDate >= #fpad.StartDate
																  AND pl.LeaseSignedDate <= #fpad.EndDate
																  AND plMinSignedDate.PersonLeaseID IS NULL
																  AND #RealTimeRevenue.PropertyID = #lau.PropertyID)

	UPDATE #RealTimeRevenue SET SignedFutureLeasesMonth4 = (SELECT COUNT(DISTINCT #lau.UnitID)
																FROM #LeasesAndUnits #lau
																	INNER JOIN Lease l ON #lau.PendingLeaseID = l.LeaseID
																	INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
																	INNER JOIN #FuturePropertiesAndDates #fpad ON #lau.PropertyID = #fpad.PropertyID
																						AND #fpad.[Sequence] = 4
																	LEFT JOIN PersonLease plMinSignedDate ON l.LeaseID = plMinSignedDate.LeaseID
																						AND plMinSignedDate.LeaseSignedDate < pl.LeaseSignedDate
																WHERE pl.LeaseSignedDate >= #fpad.StartDate
																  AND pl.LeaseSignedDate <= #fpad.EndDate
																  AND plMinSignedDate.PersonLeaseID IS NULL
																  AND #RealTimeRevenue.PropertyID = #lau.PropertyID)

	UPDATE #RealTimeRevenue SET SignedRenewalLeases = (SELECT COUNT(DISTINCT fl.LeaseID)
														   FROM #LeasesAndUnits #lau
															   INNER JOIN Lease fl ON #lau.OccupiedUnitLeaseGroupID = fl.UnitLeaseGroupID
																						AND fl.LeaseStartDate >= @date AND fl.DateCreated <= @date
															   LEFT JOIN PersonLease fpl ON fl.LeaseID = fpl.LeaseID AND fpl.LeaseSignedDate <= @date
															WHERE fl.LeaseStatus IN ('Pending Renewal', 'Current', 'Under Eviction', 'Evicted', 'Former', 'Renewed')
															  AND fpl.PersonLeaseID IS NOT NULL
															  AND #RealTimeRevenue.PropertyID = #lau.PropertyID)

	UPDATE #RealTimeRevenue SET SignedRenewalLeasesMonth1 = (SELECT COUNT(DISTINCT fl.LeaseID)
																 FROM #LeasesAndUnits #lau
																	 INNER JOIN #FuturePropertiesAndDates #fpad ON #lau.PropertyID = #fpad.PropertyID
																										AND #fpad.[Sequence] = 1
																	 INNER JOIN Lease fl ON #lau.OccupiedUnitLeaseGroupID = fl.UnitLeaseGroupID
																						AND fl.LeaseStartDate >= #fpad.StartDate AND fl.LeaseStartDate <= #fpad.EndDate
																	 LEFT JOIN PersonLease fpl ON fl.LeaseID = fpl.LeaseID AND fpl.LeaseSignedDate IS NOT NULL
																 WHERE fl.LeaseStatus IN ('Pending Renewal', 'Current', 'Under Eviction', 'Evicted', 'Former', 'Renewed')
																   AND fpl.LeaseSignedDate IS NOT NULL
																   AND #RealTimeRevenue.PropertyID = #lau.PropertyID)

	UPDATE #RealTimeRevenue SET SignedRenewalLeasesMonth2 = (SELECT COUNT(DISTINCT fl.LeaseID)
																 FROM #LeasesAndUnits #lau
																	 INNER JOIN #FuturePropertiesAndDates #fpad ON #lau.PropertyID = #fpad.PropertyID
																										AND #fpad.[Sequence] = 2
																	 INNER JOIN Lease fl ON #lau.OccupiedUnitLeaseGroupID = fl.UnitLeaseGroupID
																						AND fl.LeaseStartDate >= #fpad.StartDate AND fl.LeaseStartDate <= #fpad.EndDate
																	 LEFT JOIN PersonLease fpl ON fl.LeaseID = fpl.LeaseID AND fpl.LeaseSignedDate IS NOT NULL
																 WHERE fl.LeaseStatus IN ('Pending Renewal', 'Current', 'Under Eviction', 'Evicted', 'Former', 'Renewed')
																   AND fpl.LeaseSignedDate IS NOT NULL
																   AND #RealTimeRevenue.PropertyID = #lau.PropertyID)

	UPDATE #RealTimeRevenue SET SignedRenewalLeasesMonth3 = (SELECT COUNT(DISTINCT fl.LeaseID)
																 FROM #LeasesAndUnits #lau
																	 INNER JOIN #FuturePropertiesAndDates #fpad ON #lau.PropertyID = #fpad.PropertyID
																										AND #fpad.[Sequence] = 3
																	 INNER JOIN Lease fl ON #lau.OccupiedUnitLeaseGroupID = fl.UnitLeaseGroupID
																						AND fl.LeaseStartDate >= #fpad.StartDate AND fl.LeaseStartDate <= #fpad.EndDate
																	 LEFT JOIN PersonLease fpl ON fl.LeaseID = fpl.LeaseID AND fpl.LeaseSignedDate IS NOT NULL
																 WHERE fl.LeaseStatus IN ('Pending Renewal', 'Current', 'Under Eviction', 'Evicted', 'Former', 'Renewed')
																   AND fpl.LeaseSignedDate IS NOT NULL
																   AND #RealTimeRevenue.PropertyID = #lau.PropertyID)

	UPDATE #RealTimeRevenue SET SignedRenewalLeasesMonth4 = (SELECT COUNT(DISTINCT fl.LeaseID)
																 FROM #LeasesAndUnits #lau
																	 INNER JOIN #FuturePropertiesAndDates #fpad ON #lau.PropertyID = #fpad.PropertyID
																										AND #fpad.[Sequence] = 4
																	 INNER JOIN Lease fl ON #lau.OccupiedUnitLeaseGroupID = fl.UnitLeaseGroupID
																						AND fl.LeaseStartDate >= #fpad.StartDate AND fl.LeaseStartDate <= #fpad.EndDate
																	 LEFT JOIN PersonLease fpl ON fl.LeaseID = fpl.LeaseID AND fpl.LeaseSignedDate IS NOT NULL
																 WHERE fl.LeaseStatus IN ('Pending Renewal', 'Current', 'Under Eviction', 'Evicted', 'Former', 'Renewed')
																   AND fpl.LeaseSignedDate IS NOT NULL
																   AND #RealTimeRevenue.PropertyID = #lau.PropertyID)																   																   																						

	INSERT #FutureIncomeLeases
		SELECT	#lau.PropertyID, #lau.UnitID, #lau.OccupiedLastLeaseID
			FROM #LeasesAndUnits #lau
				INNER JOIN #FuturePropertiesAndDates #fpad ON #lau.PropertyID = #fpad.PropertyID
													AND #fpad.[Sequence] = 2
			WHERE #lau.OccupiedUnitLeaseGroupID IS NOT NULL
			  AND ((#lau.OccupiedMoveOutDate IS NULL) OR (#lau.OccupiedMoveOutDate >= #fpad.StartDate))

	UPDATE #fil	SET LeaseID = #lau.PendingLeaseID
		FROM #FutureIncomeLeases #fil
			INNER JOIN #LeasesAndUnits #lau ON #fil.UnitID = #lau.UnitID
			INNER JOIN #FuturePropertiesAndDates #fpad ON #lau.PropertyID = #fpad.PropertyID
		WHERE #fil.LeaseID IS NULL
		  AND #lau.PendingUnitLeaseGroupID IS NOT NULL
		  AND #lau.PendingMoveInDate < #fpad.StartDate

	UPDATE #fil SET LeaseID = #lau.OccupiedLastLeaseID
		FROM #FutureIncomeLeases #fil
			INNER JOIN #LeasesAndUnits #lau ON #fil.UnitID = #lau.UnitID
		WHERE #fil.LeaseID IS NULL

	UPDATE #RealTimeRevenue SET FutureIncome = ISNULL((SELECT SUM(lli.Amount)
															FROM LeaseLedgerItem lli
																INNER JOIN #FutureIncomeLeases #fil ON lli.LeaseID = #fil.LeaseID
																INNER JOIN #FuturePropertiesAndDates #fpad ON #fil.PropertyID = #fpad.PropertyID
																									AND #fpad.[Sequence] = 2
																INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
																INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
															WHERE lli.StartDate <= #fpad.StartDate
															  AND lli.EndDate >= #fpad.StartDate
															  AND #RealTimeRevenue.PropertyID = #fil.PropertyID), 0)
	
	SELECT * 
		FROM #RealTimeRevenue
		ORDER BY PropertyName


END
GO
