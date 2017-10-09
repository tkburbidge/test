SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: May 23, 2014
-- Description:	Gets info for PLP's Data Export Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_PLP_DataExport] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Data2Export (
		PropertyID uniqueidentifier not null,				-- here		
		PropertyName nvarchar(50) null,						-- here				
		NetRentalIncome money null,
		NetOperatingIncome money null,
		--NetRentalRevenueSqFt money null,
		--VacancyLoss money null,
		AmenityAmount money null,
		TotalConcessions money null,						-- here					
		--ConcessionsUnit money null,											
		--OccupancyPercent decimal(5, 2) null,
		--EccOccupancyPercent decimal(5, 2) null,
		--Vacancy int null,
		MIVacancyDays int null,								-- here
		--NTVStatus int null,									-- here
		--PreleasedCount int null,							-- here							
		--PreleasedPercent decimal(5, 2) null,
		--NTRPercent decimal(5, 2) null,
		Exp90DaysPercent decimal(5, 2) null,				-- here
		FirstVisit int null,								-- here						
		--ProspectToVisitConversion decimal(5, 2) null,
		--ClosingPercent decimal(5, 2) null,
		--GainOrLoss decimal(5, 2) null,
		RenewalPercent decimal(5, 2) null,					
		ExpiringLeases int null,							-- here					
		Expiring90DayLeases int null,						-- here
		CurrentLeaseCount int null,
		Renewed int null,									-- here	
		RenewedAndSigned int null,							-- here now, but highly suspect!						
		ExpiringNTV int null,								-- here						
		MTMStatus int null,									-- here
		MoveOuts int null,									-- here							
		--NetToRent int null,
		MoveInLeaseRentAvg money null,
		--MarketRentAvgUnit money null,
		--LeaseRentAvgUnit decimal(5, 2) null,
		NPFollowUp int null,								-- here						
		TTLContacts int null,								-- here						
		UniqueProspects int null,
		ContactsPerProspect int null,						-- here					
		ReturnVisit int null,								-- here
		TotalNumberOfUnits int null,						-- here
		TotalSquareFootage int null)						-- here						

	CREATE TABLE #UnitsAndFeet (
		PropertyID uniqueidentifier null,
		UnitsPerType int null,
		SquareFeets int null)
		
	CREATE TABLE #UniqueProspectCountByProperty (
		PropertyID uniqueidentifier null,
		ProspectCount int null)
		
		



	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate [Date] NULL,
		EndDate [Date] NULL)
	
	INSERT #PropertiesAndDates
		SELECT pids.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pids
				LEFT JOIN PropertyAccountingPeriod pap ON pids.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID


	INSERT #Data2Export
		SELECT	p.PropertyID, Name, 0, 0, 0, null, 0, null, null,  null, null, null, null, null, null, null,
				null, null, null, null, null, null, null, null, null, null
			FROM Property p
			INNER JOIN #PropertiesAndDates #pids ON #pids.PropertyID = p.PropertyID			
	
	DECLARE @netRentalIncomeGLAccountID uniqueidentifier
	SELECT @netRentalIncomeGLAccountID = GLAccountID FROM GLAccount WHERE AccountID = @accountID and Number = '5000'

	UPDATE #Data2Export SET NetRentalIncome = (SELECT ISNULL(SUM(-je.Amount), 0)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID	
													INNER JOIN GLAccount gl ON gl.GLAccountID = je.GLAccountID and gl.ParentGLAccountID = @netRentalIncomeGLAccountID																								
													INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
												WHERE
												  -- Don't include closing the year entries
												   t.Origin NOT IN ('Y', 'E')
												  AND je.AccountingBookID IS NULL
												  AND t.TransactionDate >= #pad.StartDate
												  AND t.TransactionDate <= #pad.EndDate
												  AND t.PropertyID = #Data2Export.PropertyID
												  AND je.AccountingBasis = 'Accrual')

	UPDATE #Data2Export SET NetOperatingIncome = (SELECT ISNULL(SUM(-je.Amount), 0)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID	
													INNER JOIN GLAccount gl ON gl.GLAccountID = je.GLAccountID
													INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
												WHERE
												  -- Don't include closing the year entries
												   t.Origin NOT IN ('Y', 'E')
												  AND je.AccountingBookID IS NULL
												  AND t.TransactionDate >= #pad.StartDate
												  AND t.TransactionDate <= #pad.EndDate
												  AND t.PropertyID = #Data2Export.PropertyID
												  AND gl.GLAccountType IN ('Income', 'Expense')
												  AND je.AccountingBasis = 'Accrual')													

	INSERT #UnitsAndFeet
		SELECT	DISTINCT p.PropertyID, 
				(SELECT COUNT(u.UnitID)
					FROM Unit u
					WHERE u.UnitTypeID = ut.UnitTypeID
					  AND u.ExcludedFromOccupancy = 0
					  AND (u.DateRemoved IS NULL OR u.DateRemoved < #pids.EndDate)),
				ut.SquareFootage
			FROM Property p
				INNER JOIN UnitType ut ON p.PropertyID = ut.PropertyID
				INNER JOIN #PropertiesAndDates #pids ON #pids.PropertyID = p.PropertyID			

	-- X
	UPDATE #Data2Export SET TotalNumberOfUnits = (SELECT SUM(UnitsPerType)
												FROM #UnitsAndFeet 
												WHERE PropertyID = #Data2Export.PropertyID
												GROUP BY PropertyID)
	
	-- X		
	--UPDATE #Data2Export SET TotalSquareFootage = (SELECT SUM(UnitsPerType * SquareFeets)
	--												   FROM #UnitsAndFeet
	--												   WHERE PropertyID = #Data2Export.PropertyID)
	
	-- X
	UPDATE #Data2Export SET TotalSquareFootage = (SELECT SUM(u.SquareFootage)
													  FROM Unit u
														  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
														  INNER JOIN #PropertiesAndDates #pids ON ut.PropertyID = #pids.PropertyID
													  WHERE ut.PropertyID = #Data2Export.PropertyID
														AND u.ExcludedFromOccupancy = 0
														AND (u.DateRemoved IS NULL OR u.DateRemoved > #pids.EndDate)
													  GROUP BY ut.PropertyID)
													  
	-- X												   			
	-- Preleased count
	--UPDATE #Data2Export SET PreleasedCount = (SELECT COUNT(DISTINCT l.LeaseID)
	--											   FROM Lease l	
	--													INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
	--													INNER JOIN Unit u ON u.UnitID = ulg.UnitID
	--													INNER JOIN Buliding b ON b.BulidingID = u.BulidingID
	--											   WHERE l.LeaseStatus IN ('Pending', 'Pending Transfer')
	--												AND b.PropertyID = #Data2Export.PropertyID
	--												AND u.ExcludedFromOccupancy = 0)
	
	-- X
	UPDATE #Data2Export SET FirstVisit = (SELECT COUNT(*)
											FROM PersonNote pn																	
											INNER JOIN #PropertiesAndDates #pads ON pn.PropertyID = #pads.PropertyID
											WHERE pn.PropertyID = #Data2Export.PropertyID
												AND pn.PersonType = 'Prospect'
												AND pn.ContactType = 'Face-to-Face'																	  
												AND pn.[Date] >= #pads.StartDate

												AND pn.[Date] <= #pads.EndDate

												-- Make sure this Face-to-Face contact is the first Face-to-Face contact
												AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
																		FROM PersonNote pn2 
																		WHERE pn2.PropertyID = #Data2Export.PropertyID
																			AND pn2.PersonID = pn.PersonID
																			AND pn2.PersonType = 'Prospect'
																			AND pn2.ContactType = 'Face-to-Face'
																		ORDER BY [Date], DateCreated))
										  
	
	-- X
	-- Renewed 
	UPDATE #Data2Export SET Renewed = (SELECT COUNT(DISTINCT l.LeaseID)
												  FROM Lease l
													  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID 																								
													  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
													  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
													  LEFT JOIN Lease previousLease ON previousLease.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND previousLease.LeaseStatus = 'Renewed' AND previousLease.DateCreated < l.DateCreated
													  INNER JOIN #PropertiesAndDates #pads ON ut.PropertyID = #pads.PropertyID
												  WHERE l.LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
												    AND l.LeaseStartDate >= #pads.StartDate

												    AND l.LeaseStartDate <= #pads.EndDate

													-- Either a transfer or a previous lease existed
													AND (ulg.PreviousUnitLeaseGroupID IS NOT NULL OR previousLease.LeaseID IS NOT NULL)
												    AND ut.PropertyID = #Data2Export.PropertyID)
												    
---- Renewed AND Signed Leases, needed for the Renewel%-age.	
--	UPDATE #Data2Export SET Renewed = (SELECT COUNT(DISTINCT l.LeaseID)
--												  FROM Lease l
--													  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID 
--																								AND ulg.PreviousUnitLeaseGroupID IS NOT NULL
--													  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
--													  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
--													  LEFT JOIN PersonLease plls ON l.LeaseID = plls.LeaseID 
--																							AND plls.LeaseSignedDate IS NOT NULL
--												  WHERE l.LeaseStatus IN ('Current', 'Under Eviction', 'Renewed')
--												    AND l.LeaseEndDate >= @startDate
--												    AND l.LeaseEndDate <= @endDate
--												    AND plls.PersonLeaseID IS NOT NULL
--												    AND ut.PropertyID = #Data2Export.PropertyID)										    
												    
	-- New Prospect Follow-up (NPFollowup)
	UPDATE #Data2Export SET NPFollowUp = (SELECT COUNT(pn.PersonNoteID)
											   FROM PersonNote pn
												   INNER JOIN Prospect pros ON pn.PersonID = pros.PersonID
												   LEFT JOIN PersonLease plNULL ON pn.PersonID = plNULL.PersonID AND plNULL.ResidencyStatus NOT IN ('Current')
													INNER JOIN #PropertiesAndDates #pads ON pn.PropertyID = #pads.PropertyID
											   WHERE pn.InteractionType IN ('Follow-Up')
											     AND plNULL.PersonLeaseID IS NULL
											     AND pn.[Date] >= #pads.StartDate

											     AND pn.[Date] <= #pads.EndDate

											     AND pn.PropertyID = #Data2Export.PropertyID)		
	-- X										     
	-- Total Contacts to Prospects.	
	UPDATE #Data2Export SET TTLContacts = (SELECT COUNT(pn.PersonNoteID)
												FROM PersonNote pn
													INNER JOIN Prospect pros ON pn.PersonID = pros.PersonID --AND pros.LostReasonPickListItemID IS NULL
													--LEFT JOIN PersonLease pl ON pn.PersonID = pl.PersonID 
													INNER JOIN #PropertiesAndDates #pads ON pn.PropertyID = #pads.PropertyID
												WHERE pn.PropertyID = #Data2Export.PropertyID
												  --AND ((pl.MoveInDate IS NULL) OR (pn.[Date] <= pl.MoveInDate))
												  AND pn.[Date] <= #pads.EndDate
												  AND pn.[Date] >= #pads.StartDate


												  AND pn.PersonType = 'Prospect'
												  AND pn.ContactType <> 'N/A')
	-- X
	-- Unique Prospects.	
	UPDATE #Data2Export SET UniqueProspects = (SELECT COUNT(DISTINCT pn.PersonID)
												FROM PersonNote pn
													INNER JOIN Prospect pros ON pn.PersonID = pros.PersonID --AND pros.LostReasonPickListItemID IS NULL
													--LEFT JOIN PersonLease pl ON pn.PersonID = pl.PersonID 
													INNER JOIN #PropertiesAndDates #pads ON pn.PropertyID = #pads.PropertyID
												WHERE pn.PropertyID = #Data2Export.PropertyID
												  --AND ((pl.MoveInDate IS NULL) OR (pn.[Date] <= pl.MoveInDate))
												  AND pn.[Date] <= #pads.EndDate
												  AND pn.[Date] >= #pads.StartDate


												  AND pn.PersonType = 'Prospect'
												  AND pn.ContactType <> 'N/A')
	-- X
	UPDATE #Data2Export SET ContactsPerProspect = 	CASE WHEN UniqueProspects = 0 THEN 0
													ELSE CAST(#Data2Export.TTLContacts AS decimal(9, 4)) / CAST(#Data2Export.UniqueProspects AS decimal(9, 4))
													END						  
	--INSERT #UniqueProspectCountByProperty
	--	SELECT pn.PropertyID, COUNT(DISTINCT pn.PersonID)
	--		FROM PersonNote pn
	--			INNER JOIN Prospect pros ON pn.PersonID = pros.PersonID --AND pros.LostReasonPickListItemID IS NULL
	--			--LEFT JOIN PersonLease pl ON pn.PersonID = pl.PersonID 
	--		WHERE pn.PropertyID IN (SELECT Value FROM @propertyIDs)
	--		  --AND ((pl.MoveInDate IS NULL) OR (pn.[Date] <= pl.MoveInDate))		
	--		GROUP BY pn.PropertyID
												  
	--UPDATE #Data2Export SET ContactsPerProspect = (SELECT CASE 
	--														  WHEN ProspectCount = 0 THEN 0
	--														  ELSE CAST(#d2e.TTLContacts AS decimal(9, 4)) / CAST(#upcbp.ProspectCount AS decimal(9, 4))
	--														  END
	--													FROM #Data2Export #d2e
	--														INNER JOIN #UniqueProspectCountByProperty #upcbp ON #d2e.PropertyID = #upcbp.PropertyID
	--													WHERE #d2e.PropertyID = #Data2Export.PropertyID)
-- Return Visits
	--UPDATE #Data2Export SET ReturnVisit = (SELECT COUNT(pn.PersonNoteID)
	--											FROM PersonNote pn
	--												INNER JOIN Prospect pros ON pn.PersonID = pros.PersonID
	--												LEFT JOIN PersonLease pl ON pn.PersonID = pl.PersonID
	--												LEFT JOIN PersonNote pnFirst ON pn.PersonID = pnFirst.PersonID AND pnFirst.ContactType = 'Face-to-face'
	--																		AND pnFirst.PersonNoteID = (SELECT TOP 1 PersonNoteID
	--																										FROM PersonNote
	--																										WHERE PersonID = pn.PersonID
	--																										  AND ContactType = 'Face-to-face'
	--																										ORDER BY DateCreated)
	--											WHERE pn.PropertyID = #Data2Export.PropertyID
	--											  AND pnFirst.PersonNoteID IS NOT NULL
	--											  AND ((pl.PersonLeaseID IS NULL) OR (pn.[Date] <= pl.MoveInDate))
	--											  AND pn.ContactType = 'Face-to-face'
	--											  AND pn.[Date] <= @endDate
	--											  AND pn.[Date] >= @startDate)

	-- X
	UPDATE #Data2Export SET ReturnVisit = (SELECT COUNT(*)
											FROM PersonNote pn																				
											INNER JOIN #PropertiesAndDates #pads ON pn.PropertyID = #pads.PropertyID

											WHERE pn.PropertyID = #Data2Export.PropertyID
												AND pn.PersonType = 'Prospect'
												AND pn.ContactType = 'Face-to-Face'																			  
												AND pn.[Date] >= #pads.StartDate
												AND pn.[Date] <= #pads.EndDate


												-- Make sure this Face-to-Face contact is not the first Face-to-Face contact
												AND pn.PersonNoteID <> (SELECT TOP 1 pn2.PersonNoteID 
																		FROM PersonNote pn2 
																		WHERE pn2.PropertyID = #Data2Export.PropertyID
																			AND pn2.PersonID = pn.PersonID 
																			AND pn2.ContactType = 'Face-to-Face'
																			AND pn2.PersonType = 'Prospect'
																		ORDER BY [Date], DateCreated))
	-- X										    
	-- Expiring Leases
	CREATE TABLE #ExpiringLeases 
	(
		PropertyID uniqueidentifier,
		LeaseID uniqueidentifier,
		IsRenewing bit
	)

	
	INSERT INTO #ExpiringLeases
		SELECT ut.PropertyID, 
			   l.LeaseID,
			   CASE WHEN (SELECT TOP 1 rl.LeaseID
							FROM Lease rl
								INNER JOIN PersonLease rpl ON rpl.LeaseID = rl.LeaseID and rpl.LeaseSignedDate IS NOT NULL
							WHERE rl.UnitLeaseGroupID = l.UnitLeaseGroupID
								AND rl.DateCreated > l.DateCreated
								AND rl.LeaseStatus IN ('Current', 'Pending Renewal', 'Under Eviction', 'Former', 'Evicted', 'Renewed')) IS NOT NULL THEN CAST (1 AS BIT)
					ELSE CAST(0 AS BIT)
				END
		FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN #PropertiesAndDates #pids ON #pids.PropertyID = ut.PropertyID
			LEFT JOIN Lease renewalLease ON renewalLease.UnitLeaseGroupID = l.UnitLeaseGroupID AND renewalLease.DateCreated > l.DateCreated AND renewalLease.LeaseStatus IN ('Current', 'Pending Renewal', 'Under Eviction', 'Former', 'Evicted', 'Renewed')

		WHERE l.LeaseEndDate >= #pids.StartDate
			AND l.LeaseEndDate <= #pids.EndDate
			AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Renewed')

			

	UPDATE #Data2Export SET ExpiringLeases = (SELECT COUNT(DISTINCT LeaseID)
											  FROM #ExpiringLeases
											  WHERE PropertyID = #Data2Export.PropertyID)

	UPDATE #Data2Export SET RenewalPercent = (SELECT COUNT(DISTINCT LeaseID)
											  FROM #ExpiringLeases
											  WHERE PropertyID = #Data2Export.PropertyID
												AND IsRenewing = 1) / CAST(#Data2Export.ExpiringLeases AS decimal(9, 4))
	WHERE #Data2Export.ExpiringLeases <> 0
	-- X											     
	-- Expiring NoticeToVacate
	UPDATE #Data2Export SET ExpiringNTV = (SELECT COUNT(DISTINCT l.LeaseID)
												FROM Lease l
													LEFT JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.MoveOutDate IS NULL
													INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
													INNER JOIN Unit u ON ulg.UnitID = u.UnitID
													INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
													INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID

												WHERE l.LeaseEndDate >= #pad.StartDate
												  AND l.LeaseEndDate <= #pad.EndDate
												  AND l.LeaseStatus IN ('Current', 'Under Eviction')


												  AND pl.PersonLeaseID IS NULL
												  AND ut.PropertyID = #Data2Export.PropertyID)
	-- X											  
	-- MoveOuts
	UPDATE #Data2Export SET MoveOuts = (SELECT COUNT(DISTINCT l.LeaseID)
											 FROM Lease l												 
												 INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
												 INNER JOIN Unit u ON ulg.UnitID = u.UnitID
												 INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
												 INNER JOIN #PropertiesAndDates #pads ON ut.PropertyID = #pads.PropertyID
											  WHERE ut.PropertyID = #Data2Export.PropertyID
												AND l.LeaseStatus IN ('Former', 'Evicted')

												AND (SELECT TOP 1 pl.MoveOutDate FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID ORDER BY pl.MoveOutDate DESC) >= #pads.StartDate
												AND (SELECT TOP 1 pl.MoveOutDate FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID ORDER BY pl.MoveOutDate DESC) <= #pads.EndDate)



	-- X										  
	-- NTVStatus
	--UPDATE #Data2Export SET NTVStatus = (SELECT COUNT(DISTINCT l.LeaseID)
	--										FROM Lease l
	--											LEFT JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.MoveOutDate IS NULL
	--											INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--											INNER JOIN Unit u ON ulg.UnitID = u.UnitID
	--											INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	--										WHERE l.LeaseStatus IN ('Current', 'Under Eviction')
	--											AND pl.PersonLeaseID IS NULL
	--											AND ut.PropertyID = #Data2Export.PropertyID)
	-- X											  												  
	-- Concessions & Concessions per unit
	UPDATE #Data2Export SET TotalConcessions = (SELECT ISNULL(SUM(lli.Amount), 0)
													FROM LeaseLedgerItem lli
														INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
														INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID 
														INNER JOIN LedgerItemType alit ON lit.AppliesToLedgerItemTypeID = alit.LedgerItemTypeID AND alit.IsRent = 1
														INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
														INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
														INNER JOIN Unit u ON ulg.UnitID = u.UnitID
														INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
														LEFT JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
													WHERE ut.PropertyID = #Data2Export.PropertyID
													  AND lli.StartDate <= #pad.EndDate

													  AND lli.EndDate >= #pad.EndDate

													  AND l.LeaseStatus IN ('Current', 'Under Eviction'))

-- I gave bad direction on this.  This is totally not the right calculation although it may have been 
-- had this been the calculation they wanted
-- Highly Suspect Code added by Rick just before going to Lake Powell!!!
-- Include upfront Rent Concessions in the Total Concessions Calculation.													  
	--UPDATE #Data2Export SET TotalConcessions = ISNULL(TotalConcessions, 0) + 
	--												(SELECT ISNULL(SUM(pay.Amount), 0)
	--													FROM Payment pay
	--														INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
	--														INNER JOIN [Transaction] ta ON pt.TransactionID = ta.TransactionID
	--														INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID
	--																					AND tta.Name IN ('Credit')  AND tta.[Group] IN ('Lease')
	--														--INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID 
	--														--INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID 
	--														--							AND lit.IsRent = 1
	--														INNER JOIN LedgerItemType lita ON ta.LedgerItemTypeID = lita.LedgerItemTypeID
	--														INNER JOIN LedgerItemType litar ON lita.AppliesToLedgerItemTypeID = litar.LedgerItemTypeID
	--																					AND litar.IsRent = 1)
	

	CREATE TABLE #Occupants 
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null
	)

    INSERT INTO #Occupants
		SELECT PropertyID, UnitID, Number, UnitLeaseGroupID, MoveInDate, MoveOutDate FROM 
			(SELECT  
				b.PropertyID,
				u.UnitID,
				u.Number,
				ulg.UnitLeaseGroupID,
				MIN(pl.MoveInDate) AS 'MoveInDate',
				CASE WHEN fl.LeaseID IS NOT NULL THEN MAX(fpl.MoveOutDate) ELSE NULL END AS 'MoveOutDate',
				#pids.EndDate
			FROM UnitLeaseGroup ulg
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN #PropertiesAndDates #pids ON #pids.PropertyID = b.PropertyID
			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
			LEFT JOIN Lease fl ON fl.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND fl.LeaseStatus IN ('Former', 'Evicted')
			LEFT JOIN PersonLease fpl ON fpl.LeaseID = fl.LeaseID
			WHERE l.LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
				AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
				AND u.AccountID = @accountID
				AND u.ExcludedFromOccupancy = 0				
				AND (u.DateRemoved IS NULL OR u.DateRemoved > #pids.EndDate)			
			GROUP BY b.PropertyID, ulg.UnitLeaseGroupID, u.UnitID, u.Number, u.PaddedNumber, fl.LeaseID, #pids.EndDate) OccupancyHistory
		WHERE MoveInDate <= OccupancyHistory.EndDate
			
	CREATE TABLE #MoveIns 
	(
		PropertyID uniqueidentifier,	
		UnitID uniqueidentifier,
		MoveInDate datetime,
		Rent money,
		LastMoveOutDate datetime
	)

	INSERT INTO #MoveIns
		SELECT #o.PropertyID, 
			   UnitID, 
			   MoveInDate, 
			   ISNULL((SELECT SUM(lli.Amount)
				FROM LeaseLedgerItem lli 
					INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
					INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
					INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
				WHERE l.UnitLeaseGroupID = #o.UnitLeaseGroupID
					AND lit.IsRent = 1
					AND lli.StartDate <= l.LeaseEndDate
					AND l.LeaseID = (SELECT TOP 1 LeaseID 
									 FROM Lease 
									 WHERE UnitLeaseGroupID = l.UnitLeaseGroupID
									 ORDER BY DateCreated)), 0),
			   null
		FROM #Occupants #o
			INNER JOIN #PropertiesAndDates #pad ON #o.PropertyID = #pad.PropertyID
		WHERE MoveInDate >= #pad.StartDate
			AND MoveInDate <= #pad.EndDate


	
	UPDATE #MoveIns SET LastMoveOutDate = (SELECT TOP 1 #o.MoveOutDate
										   FROM #Occupants #o	
										   WHERE #o.UnitID = #MoveIns.UnitID
											AND #o.MoveInDate < #MoveIns.MoveInDate
											ORDER BY #o.MoveOutDate DESC)

	-- X
	UPDATE #Data2Export SET MIVacancyDays = (SELECT ISNULL(SUM(DATEDIFF(DAY, #mi.LastMoveOutDate, #mi.MoveInDate)), 0)
										     FROM #MoveIns #mi
											 WHERE #mi.PropertyID = #Data2Export.PropertyID
												AND #mi.LastMoveOutDate IS NOT NULL)

	UPDATE #Data2Export SET MoveInLeaseRentAvg = (SELECT AVG(#mi.Rent)
												  FROM #MoveIns #mi
												  WHERE #mi.PropertyID = #Data2Export.PropertyID)
-- PROBLEM: Unit.LastVacatedDate will be null after someone moves in
-- Important Note from Rick - Highly Suspect Code.  I had this done already, 90% sure I tested it, plus it looks right,
--		BUT, I had it commented out.  I think the reason it was commented out was we were waiting for further clarification.													  
-- MIVacancyDays
	--UPDATE #Data2Export SET MIVacancyDays = (SELECT DATEDIFF(DAY, u.LastVacatedDate, pl.MoveInDate)
	--											 FROM Lease l
	--												 INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID 
	--														AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID	
	--																					FROM PersonLease
	--																					WHERE LeaseID = l.LeaseID
	--																					ORDER BY MoveInDate)
	--												 INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--												 INNER JOIN Unit u ON ulg.UnitID = u.UnitID
	--												 INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID 
	--												 LEFT JOIN PersonLease plMI ON l.LeaseID = pl.LeaseID 
	--														AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID	
	--																					FROM PersonLease
	--																					WHERE LeaseID = l.LeaseID
	--																					ORDER BY MoveInDate)
	--											 WHERE ut.PropertyID = #Data2Export.PropertyID
	--											   AND pl.MoveInDate >= @startDate
	--											   AND pl.MoveInDate <= @endDate
	--											   AND pl.PersonLeaseID = plMI.PersonLeaseID)	
	
	-- X											   
	UPDATE #Data2Export SET Expiring90DayLeases = (SELECT COUNT(DISTINCT l.LeaseID)
													   FROM UnitLeaseGroup ulg														  
														   INNER JOIN Unit u ON ulg.UnitID = u.UnitID
														   INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
														  INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
														INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')
																		AND l.LeaseEndDate >= #pad.StartDate AND l.LeaseEndDate <= DATEADD(DAY, 90, #pad.StartDate)


														WHERE ut.PropertyID = #Data2Export.PropertyID)
	

	UPDATE #Data2Export SET CurrentLeaseCount = (SELECT COUNT(DISTINCT l.LeaseID)
													   FROM UnitLeaseGroup ulg
														   INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')																		
														   INNER JOIN Unit u ON ulg.UnitID = u.UnitID
														   INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
														WHERE ut.PropertyID = #Data2Export.PropertyID)
	
	-- X
	UPDATE #Data2Export SET Exp90DaysPercent = CAST(Expiring90DayLeases AS decimal(9, 4)) / CAST(CurrentLeaseCount AS decimal(9, 4))
		WHERE CurrentLeaseCount <> 0
	
	-- PROBLEM: No current leases?
	--UPDATE #Data2Export SET Exp90DaysPercent = (SELECT CAST(Expiring90DayLeases AS decimal(9, 4)) / CAST(COUNT(l.LeaseID) AS decimal(9, 4))
	--												FROM UnitLeaseGroup ulg
	--													INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')
	--													INNER JOIN Unit u ON ulg.UnitID = u.UnitID
	--													INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	--												WHERE ut.PropertyID = #Data2Export.PropertyID)
	
	-- X
	UPDATE #Data2Export SET MTMStatus = (SELECT COUNT(l.LeaseID)
											FROM UnitLeaseGroup ulg 
												
												INNER JOIN Unit u ON ulg.UnitID = u.UnitID
												INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
												INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
												INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction') 
																		AND l.LeaseEndDate < #pad.StartDate



											WHERE ut.PropertyID = #Data2Export.PropertyID)		
											
	UPDATE #Data2Export SET AmenityAmount = (SELECT SUM(ISNULL(ac.Amount, 0))
												FROM Property p
													INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
													INNER JOIN UnitType ut ON p.PropertyID = ut.PropertyID
													INNER JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID
													INNER JOIN UnitAmenity ua ON u.UnitID = ua.UnitID AND ua.DateEffective <= #pad.EndDate													
													INNER JOIN Amenity amen ON ua.AmenityID = amen.AmenityID 
																		AND ua.UnitAmenityID = (SELECT TOP 1 UnitAmenityID
																									FROM UnitAmenity 
																									WHERE UnitID = u.UnitID
																									  AND AmenityID = amen.AmenityID
																									ORDER BY DateEffective DESC)
													INNER JOIN AmenityCharge ac ON amen.AmenityID = ac.AmenityID
																		AND ac.AmenityChargeID = (SELECT TOP 1 AmenityChargeID 
																									FROM AmenityCharge 

																									WHERE AmenityID = amen.AmenityID
																									  AND DateEffective <= #pad.EndDate

																									ORDER BY DateEffective DESC)
												WHERE p.PropertyID = #Data2Export.PropertyID)														
	
	SELECT	PropertyID, PropertyName,
			ISNULL(NetRentalIncome, 0) AS 'NetRentalIncome',
			ISNULL(NetOperatingIncome, 0) AS 'NetOperatingIncome',
			ISNULL(AmenityAmount, 0) AS 'AmenityAmount',
			ISNULL(TotalConcessions, 0) AS 'TotalConcessions',
			ISNULL(MIVacancyDays, 0) AS 'MIVacancyDays',						
			ISNULL(Exp90DaysPercent, 0) AS 'Exp90DaysPercent',
			ISNULL(FirstVisit, 0) AS 'FirstVisit',
			ISNULL(RenewalPercent, 0) AS 'RenewalPercent',
			ISNULL(ExpiringLeases, 0) AS 'ExpiringLeases',
			ISNULL(Expiring90DayLeases, 0) AS 'Expiring90DayLeases',
			ISNULL(Renewed, 0) AS 'Renewed',
			ISNULL(CurrentLeaseCount, 0) AS 'CurrentLeaseCount',
			ISNULL(RenewedAndSigned, 0) AS 'RenewedAndSigned',
			ISNULL(ExpiringNTV, 0) AS 'ExpiringNTV',
			ISNULL(MTMStatus, 0) AS 'MTMStatus',
			ISNULL(MoveOuts, 0) AS 'MoveOuts',
			ISNULL(NPFollowUp, 0) AS 'NPFollowUp',
			ISNULL(TTLContacts, 0) AS 'TTLContacts',
			ISNULL(ContactsPerProspect, 0) AS 'ContactsPerProspect',
			ISNULL(ReturnVisit, 0) AS 'ReturnVisit',
			ISNULL(TotalNumberOfUnits, 0) AS 'TotalNumberOfUnits',
			ISNULL(TotalSquareFootage, 0) AS 'TotalSquareFootage',
			ISNULL(MoveInLeaseRentAvg, 0) AS 'MoveInLeaseRentAvg'
	 FROM #Data2Export

END

GO
