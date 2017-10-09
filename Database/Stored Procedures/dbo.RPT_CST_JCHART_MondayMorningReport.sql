SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 11, 2016
-- Description:	Generates the data for the JCHart Monday
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_JCHART_MondayMorningReport] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
	--@startDate date = null,
	--@endDate date = null
AS

DECLARE @accountID bigint = null
DECLARE @accountingPeriodID uniqueidentifier = null
DECLARE @startDate date = DATEADD(DAY, -6, @date)
DECLARE @endDate date = @date
DECLARE @thisMonthStart date = DATEADD(month, DATEDIFF(month, 0, @date), 0)
DECLARE @nextMonthStart date = DATEADD(month, 1, @thisMonthStart)
DECLARE @nextNextMonthStart date = DATEADD(month, 2, @thisMonthStart)

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #SamCantGrowAPonytail (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(500) null,
		UnitTypeID uniqueidentifier null,
		UnitTypeName nvarchar(500) null,
		UnitTypeStyle nvarchar(2000) null,
		TotalUnits int null,
		UnitTypeSquareFeet int null,
		TotalUnitSquareFeet int null,		
		MarketRent money null,
		AvgRent money null,
		RentPerSqFoot decimal(9, 4) null,
		ModelDownAdmin int null,
		Avail2Rent int null,
		OccupiedLastWeek int null,
		MoveIns int null,
		MoveOuts int null,
		OccupiedThisWeek int null,
		ScheduledMoveIns int null,				-- Scheduled MoveIns 1 to 30 days out.
		ScheduledMoveIns30plus int null,
		NoticeToVacate int null,				-- Scheduled Notice to Vacate 1 to 30 days out.
		NoticeToVacate30plus int null,
		ForecastedOccupancy int null,			-- 30 days
		ForecastedOccupancy30plus int null,
		PotentialRenewalsThisMonth int null,
		RenewalsThisMonth int null,
		PotentialRenewalsNextMonth int null,
		RenewalsNextMonth int null,
		PotentialRenewalsNextNextMonth int null,
		RenewalsNextNextMonth int null,
		EmailTraffic int null,
		PhoneTraffic int null,
		FaceToFaceTraffic int null,
		GrossLeases int null,
		CancelledLeases int null,
		DeniedLeases int null)

	CREATE TABLE #UnitsAndTheirType (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		MarketRent money null,
		Rent money null,
		UnitStatus nvarchar(50) null)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)

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




	INSERT #PropertiesAndDates
		SELECT	Value, @startDate, @endDate
			FROM @propertyIDs

	SET @accountID = (SELECT TOP 1 prop.AccountID
						  FROM #PropertiesAndDates #pad
							  INNER JOIN Property prop ON #pad.PropertyID = prop.PropertyID)

	INSERT #UnitsAndTheirType
		SELECT	DISTINCT ut.PropertyID, u.UnitID, ut.UnitTypeID, null, null, null
			FROM Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
			WHERE u.ExcludedFromOccupancy = 0
				AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)

	INSERT #SamCantGrowAPonytail
		SELECT	DISTINCT #utt.PropertyID, prop.Name, #utt.UnitTypeID, ut.Name, ut.Description, null, null, null, null, null, null, null, null, null, null, null, null, null, null,
				 null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null									-- 31 total nulls
			FROM #UnitsAndTheirType #utt
				INNER JOIN Property prop ON #utt.PropertyID = prop.PropertyID
				INNER JOIN UnitType ut ON #utt.UnitTypeID = ut.UnitTypeID

	-- Add a propertyid and null unittype for each property for prospects not associated to a preferred unittype.
	--INSERT #SamCantGrowAPonytail
	--	SELECT	DISTINCT #pad.PropertyID, prop.Name, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null,
	--			 null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null									-- 33 total nulls
	--		FROM #PropertiesAndDates #pad
	--			INNER JOIN Property prop ON #pad.PropertyID = prop.PropertyID

	-- Get a snapshot of our occupied leases at the start of the month.
	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @endDate, @accountingPeriodID, @propertyIDs	

	UPDATE #SamCantGrowAPonytail SET TotalUnits = (SELECT COUNT(DISTINCT #lau.UnitID)
													   FROM #LeasesAndUnits #lau
														   INNER JOIN #UnitsAndTheirType #utt ON #lau.UnitID = #utt.UnitID
													   WHERE #SamCantGrowAPonytail.PropertyID = #lau.PropertyID 
													     AND #SamCantGrowAPonytail.UnitTypeID = #utt.UnitTypeID)

	--UPDATE #SamCantGrowAPonytail SET SquareFeet = (SELECT SUM(CASE WHEN (u.SquareFootage > 0) THEN u.SquareFootage ELSE ut.SquareFootage END)
	--												   FROM #LeasesAndUnits #lau
	--													   INNER JOIN Unit u ON #lau.UnitID = u.UnitID
	--													   INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	--												   WHERE #SamCantGrowAPonytail.PropertyID = #lau.PropertyID
	--												     AND #SamCantGrowAPonytail.UnitTypeID = u.UnitTypeID)

	UPDATE #SamCantGrowAPonytail SET UnitTypeSquareFeet = (SELECT TOP 1 ut.SquareFootage
													   FROM #LeasesAndUnits #lau
														   INNER JOIN Unit u ON #lau.UnitID = u.UnitID
														   INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
													   WHERE #SamCantGrowAPonytail.PropertyID = #lau.PropertyID
													     AND #SamCantGrowAPonytail.UnitTypeID = u.UnitTypeID)

	UPDATE #SamCantGrowAPonytail SET TotalUnitSquareFeet = (SELECT SUM(u.SquareFootage)
															   FROM #LeasesAndUnits #lau
																   INNER JOIN Unit u ON #lau.UnitID = u.UnitID
																   INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
															   WHERE #SamCantGrowAPonytail.PropertyID = #lau.PropertyID
																 AND #SamCantGrowAPonytail.UnitTypeID = u.UnitTypeID)															

	UPDATE #UnitsAndTheirType SET MarketRent = (SELECT Amount 
													FROM GetMarketRentByDate(#UnitsAndTheirType.UnitID, @endDate, 1))

	UPDATE #UnitsAndTheirType SET Rent = (SELECT SUM(lli.Amount)
											  FROM LeaseLedgerItem lli
												  INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
												  INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
												  INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
												  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
											   WHERE #UnitsAndTheirType.UnitID = ulg.UnitID
											     AND lli.StartDate <= @endDate
												 AND lli.EndDate >= @endDate
												 AND l.LeaseStatus IN ('Current', 'Under Eviction'))

	UPDATE #SamCantGrowAPonytail SET MarketRent = (SELECT SUM(MarketRent)
													   FROM #UnitsAndTheirType
													   WHERE #SamCantGrowAPonytail.PropertyID = PropertyID
													     AND #SamCantGrowAPonytail.UnitTypeID = UnitTypeID)

	UPDATE #SamCantGrowAPonytail SET AvgRent = ISNULL((SELECT SUM(Rent)
														   FROM #UnitsAndTheirType
														   WHERE #SamCantGrowAPonytail.PropertyID = PropertyID
															 AND #SamCantGrowAPonytail.UnitTypeID = UnitTypeID), 0)
	

	UPDATE #UnitsAndTheirType SET UnitStatus = (SELECT [Status] FROM GetUnitStatusByUnitID(#UnitsAndTheirType.UnitID, @endDate))

	UPDATE #SamCantGrowAPonytail SET Avail2Rent = (SELECT COUNT(*)
												   FROM #UnitsAndTheirType #u
													INNER JOIN #LeasesAndUnits #lau ON #lau.UnitID = #u.UnitID
												   WHERE #u.UnitStatus = 'Ready'
													AND #lau.OccupiedUnitLeaseGroupID IS NULL
													AND #lau.PendingUnitLeaseGroupID IS NULL
													 AND #lau.PropertyID = #SamCantGrowAPonytail.PropertyID
													 AND #u.UnitTypeID = #SamCantGrowAPonytail.UnitTypeID)

	UPDATE #SamCantGrowAPonytail SET ModelDownAdmin = (SELECT COUNT(DISTINCT UnitID)
														   FROM #UnitsAndTheirType
														   WHERE UnitStatus IN ('Down', 'Model', 'Admin')
														     AND PropertyID = #SamCantGrowAPonytail.PropertyID
															 AND UnitTypeID = #SamCantGrowAPonytail.UnitTypeID)


	-- Good1
	UPDATE #SamCantGrowAPonytail SET MoveIns = (SELECT COUNT(DISTINCT ulg.UnitLeaseGroupID)
											  FROM UnitLeaseGroup ulg
												  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
												  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
												  INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
												  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
												  INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
																					AND pl.MoveInDate >= #pad.StartDate AND pl.MoveInDate <= #pad.EndDate
												  LEFT JOIN (SELECT	pl1.LeaseID, pl1.PersonLeaseID, pl1.MoveInDate
																 FROM PersonLease pl1) [plPrior] ON plPrior.LeaseID = l.LeaseID
																					AND plPrior.MoveInDate < #pad.StartDate 
												  LEFT JOIN Lease lPrior ON ulg.UnitLeaseGroupID = lPrior.UnitLeaseGroupID
																					AND lPrior.LeaseStartDate < l.LeaseStartDate
												WHERE #pad.PropertyID = #SamCantGrowAPonytail.PropertyID
												  AND ut.UnitTypeID = #SamCantGrowAPonytail.UnitTypeID
												  AND plPrior.PersonLeaseID IS NULL
												  AND lPrior.LeaseID IS NULL
												  AND l.LeaseStatus NOT IN ('Pending Approval', 'Pending Transfer', 'Pending Renewal', 'Cancelled', 'Denied'))

	-- Good1	
	UPDATE #SamCantGrowAPonytail SET MoveOuts = (SELECT COUNT(DISTINCT ulg.UnitLeaseGroupID)
											  FROM UnitLeaseGroup ulg
												  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
												  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
												  INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
												  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
												  INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
																					AND pl.MoveOutDate >= #pad.StartDate AND pl.MoveOutDate <= #pad.EndDate
												  LEFT JOIN (SELECT	pl1.LeaseID, pl1.PersonLeaseID, pl1.MoveOutDate
																 FROM PersonLease pl1) [plAfter] ON [plAfter].LeaseID = l.LeaseID
																					AND [plAfter].MoveOutDate > #pad.EndDate
												  LEFT JOIN PersonLease plNull ON l.LeaseID = plNull.LeaseID AND plNull.MoveOutDate IS NULL 
												  --LEFT JOIN Lease lPrior ON ulg.UnitLeaseGroupID = lPrior.UnitLeaseGroupID
														--							AND lPrior.LeaseStartDate < l.LeaseStartDate
												WHERE #pad.PropertyID = #SamCantGrowAPonytail.PropertyID
												  AND ut.UnitTypeID = #SamCantGrowAPonytail.UnitTypeID
												  AND [plAfter].PersonLeaseID IS NULL
												  AND plNull.LeaseID IS NULL
												  AND l.LeaseStatus IN ('Evicted', 'Former'))

	UPDATE #SamCantGrowAPonytail SET OccupiedThisWeek = (SELECT COUNT(DISTINCT #lau.UnitID)
															  FROM #LeasesAndUnits #lau
																  INNER JOIN #UnitsAndTheirType #utt ON #lau.UnitID = #utt.UnitID
															  WHERE #lau.OccupiedUnitLeaseGroupID IS NOT NULL
															    AND #SamCantGrowAPonytail.PropertyID = #lau.PropertyID
																AND #SamCantGrowAPonytail.UnitTypeID = #utt.UnitTypeID)

	UPDATE #SamCantGrowAPonytail SET ScheduledMoveIns = (SELECT COUNT(DISTINCT #lau.UnitID)
															 FROM #LeasesAndUnits #lau
																 INNER JOIN #UnitsAndTheirType #utt ON #lau.UnitID = #utt.UnitID
															 WHERE #lau.PendingUnitLeaseGroupID IS NOT NULL
															   --AND #lau.PendingMoveInDate > @endDate
															   AND #lau.PendingMoveInDate <= DATEADD(DAY, 30, @endDate)
															   AND #SamCantGrowAPonytail.PropertyID = #lau.PropertyID
															   AND #SamCantGrowAPonytail.UnitTypeID = #utt.UnitTypeID)

	UPDATE #SamCantGrowAPonytail SET ScheduledMoveIns30plus = (SELECT COUNT(DISTINCT #lau.UnitID)
																	 FROM #LeasesAndUnits #lau
																		 INNER JOIN #UnitsAndTheirType #utt ON #lau.UnitID = #utt.UnitID
																	 WHERE #lau.PendingUnitLeaseGroupID IS NOT NULL
																	   AND #lau.PendingMoveInDate >= DATEADD(DAY, 31, @endDate)
																	   AND #SamCantGrowAPonytail.PropertyID = #lau.PropertyID
																	   AND #SamCantGrowAPonytail.UnitTypeID = #utt.UnitTypeID)

	UPDATE #SamCantGrowAPonytail SET NoticeToVacate = (SELECT COUNT(DISTINCT #lau.UnitID)
															FROM #LeasesAndUnits #lau
																INNER JOIN #UnitsAndTheirType #utt ON #lau.UnitID = #utt.UnitID
															WHERE #lau.OccupiedUnitLeaseGroupID IS NOT NULL
															  --AND #lau.OccupiedMoveOutDate > @endDate
															  AND #lau.OccupiedMoveOutDate <= DATEADD(DAY, 30, @endDate)
															  AND #SamCantGrowAPonytail.PropertyID = #lau.PropertyID
															  AND #SamCantGrowAPonytail.UnitTypeID = #utt.UnitTypeID)

	UPDATE #SamCantGrowAPonytail SET NoticeToVacate30plus = (SELECT COUNT(DISTINCT #lau.UnitID)
																FROM #LeasesAndUnits #lau
																	INNER JOIN #UnitsAndTheirType #utt ON #lau.UnitID = #utt.UnitID
																WHERE #lau.OccupiedUnitLeaseGroupID IS NOT NULL
																  AND #lau.OccupiedMoveOutDate >= DATEADD(DAY, 31, @endDate)
																  AND #SamCantGrowAPonytail.PropertyID = #lau.PropertyID
																  AND #SamCantGrowAPonytail.UnitTypeID = #utt.UnitTypeID)

	CREATE TABLE #ExpiringLeases
	(
		LeaseID uniqueidentifier,
		UnitLeaseGroupID uniqueidentifier,
		PropertyID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		LeaseEndDate date,
		Renewing bit
	)

	CREATE TABLE #RenewalLeases
	(
		LeaseID uniqueidentifier,
		UnitLeaseGroupID uniqueidentifier,
		PropertyID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		LeaseEndDate date,
		PreviousUnitLeaseGroupID uniqueidentifier
	)

	TRUNCATE TABLE #LeasesAndUnits

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @thisMonthStart, @accountingPeriodID, @propertyIDs	

	INSERT INTO #ExpiringLeases
		SELECT l.LeaseID, ulg.UnitLeaseGroupID, b.PropertyID, u.UnitTypeID, l.LeaseEndDate, 0
		FROM #LeasesAndUnits #lau
			INNER JOIN Lease l ON #lau.OccupiedLastLeaseID = l.LeaseID

			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = b.PropertyID
		WHERE l.LeaseEndDate >= @thisMonthStart
			AND l.LeaseEndDate < DATEADD(MONTH, 1, @nextNextMonthStart)
			--AND l.LeaseStatus NOT IN ('Cancelled', 'Former', 'Denied', 'Evicted', 'Renewed')

	
	INSERT INTO #RenewalLeases	
		SELECT DISTINCT l.LeaseID, ulg.UnitLeaseGroupID, b.PropertyID, u.UnitTypeID, l.LeaseEndDate, ulg.PreviousUnitLeaseGroupID
		FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = b.PropertyID
			LEFT JOIN Lease prevL ON ulg.UnitLeaseGroupID = prevL.UnitLeaseGroupID 
						AND prevL.LeaseEndDate < l.LeaseEndDate
						AND prevL.LeaseID <> l.LeaseID
			INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.LeaseSignedDate IS NOT NULL
		WHERE l.LeaseStatus NOT IN ('Cancelled', 'Former', 'Denied', 'Evicted', 'Renewed')
		AND l.LeaseStartDate >= @thisMonthStart		
		AND ((ulg.PreviousUnitLeaseGroupID IS NOT NULL) OR (prevL.LeaseStatus IS NOT NULL))

	UPDATE #ExpiringLeases SET Renewing = (CASE WHEN (SELECT COUNT(#rl.LeaseID)
											FROM #RenewalLeases #rl
											WHERE (#rl.PreviousUnitLeaseGroupID = #ExpiringLeases.UnitLeaseGroupID
												OR #rl.UnitLeaseGroupID = #ExpiringLeases.UnitLeaseGroupID)
												AND #rl.LeaseEndDate > #ExpiringLeases.LeaseEndDate) > 0 THEN 1 ELSE 0 END)

	UPDATE #SamCantGrowAPonytail SET PotentialRenewalsThisMonth = (SELECT COUNT(DISTINCT l.LeaseID)
																		FROM #ExpiringLeases l																			
																		WHERE l.LeaseEndDate >= @thisMonthStart
																		  AND l.LeaseEndDate < @nextMonthStart																		  
																		  AND #SamCantGrowAPonytail.UnitTypeID = l.UnitTypeID
																		  AND #SamCantGrowAPonytail.PropertyID = l.PropertyID)

	UPDATE #SamCantGrowAPonytail SET RenewalsThisMonth = (SELECT COUNT(DISTINCT l.LeaseID)
																		FROM #ExpiringLeases l																			
																		WHERE l.LeaseEndDate >= @thisMonthStart
																		  AND l.LeaseEndDate < @nextMonthStart																		  
																		  AND #SamCantGrowAPonytail.UnitTypeID = l.UnitTypeID
																		  AND #SamCantGrowAPonytail.PropertyID = l.PropertyID
																		  AND l.Renewing = 1)

	TRUNCATE TABLE #ExpiringLeases

	INSERT INTO #ExpiringLeases
		SELECT l.LeaseID, ulg.UnitLeaseGroupID, b.PropertyID, u.UnitTypeID, l.LeaseEndDate, 0

		FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = b.PropertyID
		WHERE l.LeaseEndDate >= @thisMonthStart
			AND l.LeaseEndDate < DATEADD(MONTH, 1, @nextNextMonthStart)
			AND l.LeaseStatus NOT IN ('Cancelled', 'Former', 'Denied', 'Evicted', 'Renewed')

	UPDATE #ExpiringLeases SET Renewing = (CASE WHEN (SELECT COUNT(#rl.LeaseID)
											FROM #RenewalLeases #rl
											WHERE (#rl.PreviousUnitLeaseGroupID = #ExpiringLeases.UnitLeaseGroupID
												OR #rl.UnitLeaseGroupID = #ExpiringLeases.UnitLeaseGroupID)
												AND #rl.LeaseEndDate > #ExpiringLeases.LeaseEndDate) > 0 THEN 1 ELSE 0 END)

	UPDATE #SamCantGrowAPonytail SET PotentialRenewalsNextMonth = (SELECT COUNT(DISTINCT l.LeaseID)
																		FROM #ExpiringLeases l																			
																		WHERE l.LeaseEndDate >= @nextMonthStart
																		  AND l.LeaseEndDate < @nextNextMonthStart																		  
																		  AND #SamCantGrowAPonytail.UnitTypeID = l.UnitTypeID
																		  AND #SamCantGrowAPonytail.PropertyID = l.PropertyID)

	UPDATE #SamCantGrowAPonytail SET RenewalsNextMonth = (SELECT COUNT(DISTINCT l.LeaseID)
																		FROM #ExpiringLeases l																			
																		WHERE l.LeaseEndDate >= @nextMonthStart
																		  AND l.LeaseEndDate < @nextNextMonthStart																		  
																		  AND #SamCantGrowAPonytail.UnitTypeID = l.UnitTypeID
																		  AND #SamCantGrowAPonytail.PropertyID = l.PropertyID
																		  AND l.Renewing = 1)

	UPDATE #SamCantGrowAPonytail SET PotentialRenewalsNextNextMonth = (SELECT COUNT(DISTINCT l.LeaseID)
																		FROM #ExpiringLeases l																			
																		WHERE l.LeaseEndDate >= @nextNextMonthStart
																		  AND l.LeaseEndDate < DATEADD(MONTH, 1, @nextNextMonthStart)
																		  AND #SamCantGrowAPonytail.UnitTypeID = l.UnitTypeID
																		  AND #SamCantGrowAPonytail.PropertyID = l.PropertyID)

	UPDATE #SamCantGrowAPonytail SET RenewalsNextNextMonth = (SELECT COUNT(DISTINCT l.LeaseID)
																		FROM #ExpiringLeases l																			
																		WHERE l.LeaseEndDate >= @nextNextMonthStart
																		  AND l.LeaseEndDate < DATEADD(MONTH, 1, @nextNextMonthStart)																		  
																		  AND #SamCantGrowAPonytail.UnitTypeID = l.UnitTypeID
																		  AND #SamCantGrowAPonytail.PropertyID = l.PropertyID
																		  AND l.Renewing = 1)

	UPDATE #SamCantGrowAPonytail SET EmailTraffic = (SELECT COUNT(DISTINCT pn.PersonNoteID)
														FROM PersonNote pn
															INNER JOIN Prospect ON Prospect.PersonID = pn.PersonID
															INNER JOIN PersonType pt ON pn.CreatedByPersonID = pt.PersonID AND pt.[Type] IN ('Employee', 'Prospect')
															LEFT JOIN ProspectUnitType put ON Prospect.ProspectID = put.ProspectID
															LEFT JOIN PersonNote pnFirst ON Prospect.PersonID = pnFirst.PersonID AND pnFirst.[Date] < @startDate
																							AND pn.PersonType = 'Prospect' AND pn.ContactType <> 'N/A'
														WHERE pn.PropertyID = #SamCantGrowAPonytail.PropertyID 
														  AND put.UnitTypeID = #SamCantGrowAPonytail.UnitTypeID
														  AND pn.ContactType = 'Email'
														  AND pn.PersonType = 'Prospect'
														  AND pn.[Date] >= @startDate
														  AND pn.[Date] <= @endDate	
														  AND pnFirst.PersonNoteID IS NULL															
														  AND put.ProspectUnitTypeID = (SELECT TOP 1 ProspectUnitTypeID
																							FROM ProspectUnitType 
																							WHERE ProspectID = Prospect.ProspectID))

	UPDATE #SamCantGrowAPonytail SET PhoneTraffic = (SELECT COUNT(DISTINCT pn.PersonNoteID)
														FROM PersonNote pn
															INNER JOIN Prospect ON Prospect.PersonID = pn.PersonID
															INNER JOIN PersonType pt ON pn.CreatedByPersonID = pt.PersonID AND pt.[Type] IN ('Employee', 'Prospect')
															LEFT JOIN ProspectUnitType put ON Prospect.ProspectID = put.ProspectID
															LEFT JOIN PersonNote pnFirst ON Prospect.PersonID = pnFirst.PersonID AND pnFirst.[Date] < @startDate
																							AND pn.PersonType = 'Prospect' AND pn.ContactType <> 'N/A'
														WHERE pn.PropertyID = #SamCantGrowAPonytail.PropertyID 
														  AND put.UnitTypeID = #SamCantGrowAPonytail.UnitTypeID
														  AND pn.ContactType = 'Phone'
														  AND pn.PersonType = 'Prospect'
														  AND pn.[Date] >= @startDate
														  AND pn.[Date] <= @endDate		
														  AND pnFirst.PersonNoteID IS NULL														
														  AND put.ProspectUnitTypeID = (SELECT TOP 1 ProspectUnitTypeID
																							FROM ProspectUnitType 
																							WHERE ProspectID = Prospect.ProspectID))

	UPDATE #SamCantGrowAPonytail SET FaceToFaceTraffic = (SELECT COUNT(DISTINCT pn.PersonNoteID)
															FROM PersonNote pn
																INNER JOIN Prospect ON Prospect.PersonID = pn.PersonID
																INNER JOIN PersonType pt ON pn.CreatedByPersonID = pt.PersonID AND pt.[Type] IN ('Employee', 'Prospect')
																LEFT JOIN ProspectUnitType put ON Prospect.ProspectID = put.ProspectID
															WHERE pn.PropertyID = #SamCantGrowAPonytail.PropertyID 
																AND put.UnitTypeID = #SamCantGrowAPonytail.UnitTypeID
																AND pn.ContactType = 'Face-to-Face'
																AND pn.PersonType = 'Prospect'
																AND pn.[Date] >= @startDate
																AND pn.[Date] <= @endDate
																AND put.ProspectUnitTypeID = (SELECT TOP 1 ProspectUnitTypeID
																								  FROM ProspectUnitType 
																								  WHERE ProspectID = Prospect.ProspectID))

	UPDATE #SamCantGrowAPonytail SET GrossLeases = (SELECT COUNT(DISTINCT l.LeaseID)
														FROM Lease l
															INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
															INNER JOIN Unit u ON ulg.UnitID = u.UnitID
															INNER JOIN Building b ON b.BuildingID = u.BuildingID
															INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = b.PropertyID
															INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
															LEFT JOIN PersonLease plFirstApplied ON l.LeaseID = plFirstApplied.LeaseID 
																						AND plFirstApplied.ApplicationDate < pl.ApplicationDate
														WHERE pl.ApplicationDate > @startDate 
														  AND pl.ApplicationDate <= @endDate
														  AND plFirstApplied.PersonLeaseID IS NULL
														  AND ulg.PreviousUnitLeaseGroupID IS NULL
														  AND #SamCantGrowAPonytail.PropertyID = b.PropertyID
														  AND #SamCantGrowAPonytail.UnitTypeID = u.UnitTypeID
														  AND l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate))

	CREATE TABLE #CancelledLeases
	(
		LeaseID uniqueidentifier,
		PropertyID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		LeaseStatus nvarchar(100)
	)
	
	INSERT #CancelledLeases 
		SELECT	l.LeaseID AS 'LeaseID', 								
				b.PropertyID AS 'ResponsiblePropertyID',
				u.UnitTypeID,
				l.LeaseStatus
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID		
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = b.PropertyID					
			WHERE 
				-- Make sure we only take into account the first lease in a given unit lease group
				l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)
				AND l.LeaseStatus IN ('Cancelled', 'Denied')
				-- Ensure we only get leases that actually applied during the date range
				AND (@startDate <= (SELECT MAX(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
				AND (@endDate >= (SELECT MAX(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
				-- Make sure we don't take into account transferred residents
				AND ulg.PreviousUnitLeaseGroupID IS NULL
		

	UPDATE #SamCantGrowAPonytail SET DeniedLeases = (SELECT COUNT(DISTINCT #cl.LeaseID)
														FROM #CancelledLeases #cl															
														WHERE #SamCantGrowAPonytail.PropertyID = #cl.PropertyID
														  AND #SamCantGrowAPonytail.UnitTypeID = #cl.UnitTypeID
														  AND #cl.LeaseStatus IN ('Denied'))

	UPDATE #SamCantGrowAPonytail SET CancelledLeases = (SELECT COUNT(DISTINCT #cl.LeaseID)
														FROM #CancelledLeases #cl															
														WHERE #SamCantGrowAPonytail.PropertyID = #cl.PropertyID
														  AND #SamCantGrowAPonytail.UnitTypeID = #cl.UnitTypeID
														  AND #cl.LeaseStatus IN ('Cancelled'))

	SELECT * 
		FROM #SamCantGrowAPonytail

END
GO
