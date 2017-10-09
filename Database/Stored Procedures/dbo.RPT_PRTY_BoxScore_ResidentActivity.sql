SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO










-- =============================================
-- Author:		Nick Olsen
-- Create date: March 9, 2015
-- Description:	Gets the data for the resident related box score rerpot
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRTY_BoxScore_ResidentActivity]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null,
	@startDate date,
	@endDate date,
	@onlyProjectedOccupancy bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate date null,
		EndDate date null)
	
	
	INSERT #PropertiesAndDates 
		SELECT	pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID


	/*  RESIDENT ACTIVITY STUFF  */

	CREATE TABLE #ResidentActivity (
		[Type] nvarchar(100),
		PropertyID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		UnitType nvarchar(100),
		UnitID uniqueidentifier,
		Unit nvarchar(50),
		PaddedUnitNumber nvarchar(50),
		UnitLeaseGroupID uniqueidentifier,
		LeaseID uniqueidentifier,
		Residents nvarchar(1000),
		MarketRent money,
		EffectiveRent money,
		MoveInDate date,
		MoveOutReason nvarchar(100),
		NoticeGiven date,
		MoveOutDate date,
		LeaseEndDate date,
		RequiredDeposit money,
		DepositsPaidIn money,
		DepositsPaidOut money,
		DepositsHeld money,
		ProspectSource nvarchar(100)
	)

	IF (@onlyProjectedOccupancy = 0)
	BEGIN
		INSERT INTO #ResidentActivity
			SELECT DISTINCT 
					'MoveOut',
					p.PropertyID,	
					ut.UnitTypeID,
					ut.Name,
					u.UnitID,
					u.Number,
					u.PaddedNumber,
					l.UnitLeaseGroupID,
					l.LeaseID,
					'' AS 'Residents',
					0 AS 'MarketRent',
					0 AS 'EffectiveRent',
					pl.MoveInDate,
					pl.ReasonForLeaving,
					pl.NoticeGivenDate,
					pl.MoveOutDate,
					l.LeaseEndDate,
					0 AS 'RequiredDeposit',
					0 AS 'DepositsPaidIn',
					0 AS 'DepositsPaidOut',
					0 AS 'DepositHeld',
					null AS 'ProspectSource'				
				FROM Lease l
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN Property p ON p.PropertyID = b.PropertyID
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID		
					INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID						
					--Join in PickListItem for the category
					LEFT JOIN PickListItem pli on pli.Name = pl.ReasonForLeaving AND pli.[Type] = 'ReasonForLeaving' AND pli.AccountID = @accountID									
					INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
				
				WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
										  FROM PersonLease pl2
										  WHERE pl2.LeaseID = l.LeaseID
											AND pl2.ResidencyStatus IN ('Former', 'Evicted')
										  ORDER BY pl2.MoveOutDate DESC, pl2.OrderBy, pl2.PersonID)		
				  AND pl.MoveOutDate >= #pad.StartDate
				  AND pl.MoveOutDate <= #pad.EndDate
				  AND pl.ResidencyStatus IN ('Former', 'Evicted')
				  AND l.LeaseStatus IN ('Former', 'Evicted')
			
	

		INSERT INTO #ResidentActivity
			SELECT DISTINCT 	
					'MoveIn' AS 'Type',					
					p.PropertyID,	
					ut.UnitTypeID,
					ut.Name,
					u.UnitID,
					u.Number,
					u.PaddedNumber,			
					l.UnitLeaseGroupID,
					l.LeaseID,
					'' AS 'Residents',
					mr.Amount AS 'MarketRent',
					0 AS 'EffectiveRent',
					pl.MoveInDate,
					'' AS 'MoveOutReason',
					null AS 'NoticeGiven',
					null AS 'MoveOutDate',
					l.LeaseEndDate,			
					0,
					0 AS 'DepositsPaidIn',
					0 AS 'DepositsPaidOut',
					0,
					null AS 'ProspectSource'				
				FROM Lease l
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN Property p ON p.PropertyID = b.PropertyID
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID		
					INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID																		
					INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
					CROSS APPLY GetMarketRentByDate(u.UnitID, #pad.EndDate, 1) mr
				WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
										  FROM PersonLease pl2
										  WHERE pl2.LeaseID = l.LeaseID
											AND pl2.ResidencyStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
										  ORDER BY pl2.MoveInDate, pl2.OrderBy, pl2.PersonID)		
				  AND pl.MoveInDate >= #pad.StartDate
				  AND pl.MoveInDate <= #pad.EndDate
				  AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
				  AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
				  AND l.LeaseID = (SELECT TOP 1 LeaseID 
								   FROM Lease
								   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
										 AND LeaseStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted')
								   ORDER BY LeaseStartDate, DateCreated)

		UPDATE #ResidentActivity SET MoveOutReason = (SELECT TOP 1 pl2.ReasonForLeaving
														FROM Lease l1 
															INNER JOIN PersonLease pl1 ON l1.leaseID = pl1.leaseID
															INNER JOIN PersonLease pl2 on pl1.personID = pl2.personID
															INNER JOIN Lease l2 on pl2.leaseID = l2.leaseID
														WHERE l1.LeaseID = #ResidentActivity.LeaseID 
														  AND l2.LeaseID <> l1.LeaseID
														  AND l2.LeaseStartDate < l1.LeaseStartDate -- previous to current lease
														  AND pl2.ReasonForLeaving = 'Onsite Transfer'
														ORDER BY l2.DateCreated DESC)
		WHERE #ResidentActivity.[Type] IN ('MoveIn')

		INSERT INTO #ResidentActivity
			SELECT DISTINCT 						
					'NTV',
					p.PropertyID,	
					ut.UnitTypeID,
					ut.Name,
					u.UnitID,
					u.Number,
					u.PaddedNumber,
					l.UnitLeaseGroupID,
					l.LeaseID,
					'' AS 'Residents',
					0 AS 'MarketRent',
					0 AS 'EffectiveRent',
					pl.MoveInDate,
					pl.ReasonForLeaving,
					pl.NoticeGivenDate,
					pl.MoveOutDate,
					l.LeaseEndDate,
					0 AS 'RequiredDeposit',
					0 AS 'DepositsPaidIn',
					0 AS 'DepositsPaidOut',
					0 AS 'DepositHeld',
					null AS 'ProspectSource'				
				FROM Lease l
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN Property p ON p.PropertyID = b.PropertyID
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID		
					INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID						
					--Join in PickListItem for the category
					INNER JOIN PickListItem pli on pli.Name = pl.ReasonForLeaving AND pli.[Type] = 'ReasonForLeaving' AND pli.AccountID = @accountID									
					INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
					LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted') AND plmo.NoticeGivenDate IS NULL --AND plmo.MoveOutDate IS NULL
				
				WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
										  FROM PersonLease pl2
										  WHERE pl2.LeaseID = l.LeaseID
											AND pl2.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted')
										  ORDER BY pl2.NoticeGivenDate DESC, pl2.OrderBy, pl2.PersonID)		
				  AND plmo.PersonLeaseID IS NULL -- no one who hasn't given notice
				  AND pl.NoticeGivenDate >= #pad.StartDate
				  AND pl.NoticeGivenDate <= #pad.EndDate
				  AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted')
				  AND l.LeaseStatus IN ('Current', 'Under Eviction',  'Former', 'Evicted')
				  AND l.LeaseID = (SELECT TOP 1 LeaseID 
								   FROM Lease
								   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
										 AND LeaseStatus IN ('Current', 'Former', 'Under Eviction', 'Evicted')
								   ORDER BY LeaseStartDate, DateCreated)	

		UPDATE #ResidentActivity SET Residents = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
																 FROM Person 
																	 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID																																		 
																 WHERE PersonLease.LeaseID = #ResidentActivity.LeaseID																   		   
																	   AND PersonLease.MainContact = 1				   
																 FOR XML PATH ('')), 1, 2, '')
	
	
		UPDATE #ResidentActivity SET DepositsPaidIn = (SELECT ISNULL(SUM(t.Amount), 0)
														FROM [Transaction] t
															INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID 
															INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = t.PropertyID
															--LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
														WHERE t.ObjectID = #ResidentActivity.UnitLeaseGroupID
														  AND t.TransactionDate <= #pad.EndDate
														  AND tt.Name IN ('Deposit', 'Balance Transfer Deposit', 'Deposit Interest Payment'))
														  --AND tr.TransactionID IS NULL)
		--WHERE [Type] IN ('NTV', 'MoveOut')
		  
		UPDATE #ResidentActivity SET DepositsPaidOut = (SELECT ISNULL(SUM(t.Amount), 0)
														FROM [Transaction] t
															INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
															INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = t.PropertyID
															--LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
														WHERE t.ObjectID = #ResidentActivity.UnitLeaseGroupID
														  AND t.TransactionDate <= #pad.EndDate
														  AND tt.Name IN ('Deposit Refund', 'Deposit Applied to Balance'))
														  --AND tr.TransactionID IS NULL)
		--WHERE [Type] IN ('NTV', 'MoveOut')
		  
		UPDATE #ResidentActivity SET RequiredDeposit = (SELECT ISNULL(SUM(lli.Amount), 0)
													FROM UnitLeaseGroup ulg 
														INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
														INNER JOIN LeaseLedgerItem lli ON l.LeaseID = lli.LeaseID
														INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
														INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
													WHERE ulg.UnitLeaseGroupID = #ResidentActivity.UnitLeaseGroupID
													  AND lit.IsDeposit = 1)
		--WHERE [Type] IN ('NTV', 'MoveOut')

		UPDATE #ResidentActivity SET DepositsHeld = DepositsPaidIn - DepositsPaidOut

		UPDATE #ResidentActivity SET EffectiveRent = ISNULL((SELECT ISNULL(Sum(lli.Amount), 0) 
																FROM LeaseLedgerItem lli
																INNER JOIN LedgerItem li on li.LedgerItemID = lli.LedgerItemID
																INNER JOIN LedgerItemType lit on lit.LedgerItemTypeID = li.LedgerItemTypeID
																WHERE lli.LeaseID = #ResidentActivity.LeaseID 
																		AND lit.IsRent = 1
																		AND lli.StartDate <= #ResidentActivity.LeaseEndDate), 0)
		WHERE [Type] = 'MoveIn'
	
		UPDATE #ResidentActivity SET EffectiveRent = EffectiveRent - ISNULL((SELECT ISNULL(SUM(lli.Amount), 0)
																			FROM LeaseLedgerItem lli
																				INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
																				INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID  AND lit.IsCredit = 1 AND lit.IsRecurringMonthlyRentConcession = 1																		
																			WHERE lli.LeaseID = #ResidentActivity.LeaseID
																			  AND lli.StartDate <= #ResidentActivity.LeaseEndDate), 0)
		WHERE [Type] = 'MoveIn'


		-- Update prospect id for main prospects
		UPDATE #ResidentActivity SET ProspectSource = (SELECT TOP 1 ps.Name
													FROM Prospect pr													  
														INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
														INNER JOIN PersonLease pl ON pl.LeaseID = #ResidentActivity.LeaseID AND pr.PersonID = pl.PersonID
														INNER JOIN ProspectSource ps ON ps.ProspectSourceID = pps.ProspectSourceID
													WHERE pps.PropertyID = #ResidentActivity.PropertyID)
		WHERE [Type] = 'MoveIn'													   	
													 
		-- Update prospect id for roommates											 
		UPDATE #ResidentActivity SET ProspectSource = (SELECT TOP 1 ps.Name
												FROM Prospect pr	
													INNER JOIN ProspectRoommate proroom ON pr.ProspectID = proroom.ProspectID												 
													INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													INNER JOIN PersonLease pl ON pl.LeaseID = #ResidentActivity.LeaseID AND proroom.PersonID = pl.PersonID
													INNER JOIN ProspectSource ps ON ps.ProspectSourceID = pps.ProspectSourceID
												WHERE pps.PropertyID = #ResidentActivity.PropertyID)
		WHERE [Type] = 'MoveIn'
			AND #ResidentActivity.ProspectSource IS NULL
			
				
	END -- END OF IF(@onlyProjectedOccupancy = 0)


	/*  UNIT COUNT STUFF used by many of the return sets  */
	
	CREATE TABLE #UnitCounts  (
		PropertyID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		UnitType nvarchar(100),
		UnitCount int
	)


	INSERT INTO #UnitCounts
		SELECT
			ut.PropertyID,
			ut.UnitTypeID,
			ut.Name,
			COUNT(u.UnitID)		
		FROM UnitType ut
			INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
			LEFT JOIN Unit u ON u.UnitTypeID = ut.UnitTypeID AND u.IsHoldingUnit = 0 AND u.ExcludedFromOccupancy = 0 AND (u.DateRemoved IS NULL OR u.DateRemoved > #pad.EndDate)			
		GROUP BY ut.UnitTypeID, ut.Name, ut.PropertyID


	/*  OCCUPANCY STUFF  */

	CREATE TABLE #Occupancy (
		PropertyID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		UnitType nvarchar(100),
		Units int,
		MoveIns int,
		MoveOuts int,
		Vacant int,
		VacantPreLeased int,
		VacantReady int,
		OnNotice int,
		OnNoticePreLeased int,
		ModelAdmin int,
		Down int
	)

	INSERT INTO #Occupancy
		SELECT
			PropertyID,
			UnitTypeID,
			UnitType,
			UnitCount,
			0 AS 'MoveIns',
			0 AS 'MoveOuts',
			0 AS 'Vacant', 
			0 AS 'VacantPreLeased',
			0 AS 'VacantReady',
			0 AS 'OnNotice',
			0 AS 'OnNoticePreLeased',
			0 AS 'ModelAdmin',
			0 AS 'Down'
		FROM #UnitCounts

	CREATE TABLE #CurrentOccupants
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,		
		OccupiedUnitLeaseGroupID uniqueidentifier, 
		OccupiedLastLeaseID uniqueidentifier,
		OccupiedMoveInDate date,
		OccupiedNTVDate date,
		OccupiedMoveOutDate date,
		OccupiedIsMovedOut bit,
		PendingUnitLeaseGroupID uniqueidentifier,
		PendingLeaseID uniqueidentifier,
		PendingApplicationDate date,
		PendingMoveInDate date 
	)

	INSERT INTO #CurrentOccupants
		EXEC [GetConsolodatedOccupancyNumbers] @accountID, @endDate, @accountingPeriodID, @propertyIDs

	

	UPDATE #Occupancy SET MoveIns = (SELECT COUNT(*) 
									 FROM #ResidentActivity #ra
									 WHERE #ra.UnitTypeID = #Occupancy.UnitTypeID
										AND #ra.[Type] = 'MoveIn')

	UPDATE #Occupancy SET MoveOuts = (SELECT COUNT(*) 
									 FROM #ResidentActivity #ra
									 WHERE #ra.UnitTypeID = #Occupancy.UnitTypeID
										AND #ra.[Type] = 'MoveOut')

	UPDATE #Occupancy SET Vacant = (SELECT COUNT(*) 
									 FROM #CurrentOccupants #cu
										INNER JOIN Unit u ON u.UnitID = #cu.UnitID
									 WHERE u.UnitTypeID = #Occupancy.UnitTypeID
										AND #cu.OccupiedUnitLeaseGroupID IS NULL)

	UPDATE #Occupancy SET VacantPreleased = (SELECT COUNT(*) 
									 FROM #CurrentOccupants #cu
										INNER JOIN Unit u ON u.UnitID = #cu.UnitID
									 WHERE u.UnitTypeID = #Occupancy.UnitTypeID
										AND #cu.OccupiedUnitLeaseGroupID IS NULL
										AND #cu.PendingUnitLeaseGroupID IS NOT NULL)

	UPDATE #Occupancy SET OnNotice = (SELECT COUNT(*) 
									 FROM #CurrentOccupants #cu
										INNER JOIN Unit u ON u.UnitID = #cu.UnitID
										INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #cu.PropertyID
									 WHERE u.UnitTypeID = #Occupancy.UnitTypeID
										AND #cu.OccupiedUnitLeaseGroupID IS NOT NULL 
										AND #cu.OccupiedNTVDate <= #pad.EndDate
										AND #cu.OccupiedMoveOutDate IS NOT NULL)

	UPDATE #Occupancy SET OnNoticePreLeased = (SELECT COUNT(*) 
									 FROM #CurrentOccupants #cu
										INNER JOIN Unit u ON u.UnitID = #cu.UnitID
										INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #cu.PropertyID
									 WHERE u.UnitTypeID = #Occupancy.UnitTypeID
										AND #cu.OccupiedUnitLeaseGroupID IS NOT NULL 
										AND #cu.OccupiedMoveOutDate IS NOT NULL

										AND #cu.PendingUnitLeaseGroupID IS NOT NULL
										AND #cu.OccupiedNTVDate <= #pad.EndDate)

	UPDATE #Occupancy SET VacantReady = (SELECT COUNT(*) 
										 FROM #CurrentOccupants #co
											INNER JOIN Unit u ON u.UnitID = #co.UnitID
											INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #co.PropertyID
											CROSS APPLY GetUnitStatusByUnitID(#co.UnitID, #pad.EndDate) us
										 WHERE u.UnitTypeID = #Occupancy.UnitTypeID
											AND #co.OccupiedUnitLeaseGroupID IS NULL 
											AND us.[Status] IN ('Ready'))

	UPDATE #Occupancy SET ModelAdmin = (SELECT COUNT(*) 
										 FROM #CurrentOccupants #co
											INNER JOIN Unit u ON u.UnitID = #co.UnitID
											INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #co.PropertyID
											CROSS APPLY GetUnitStatusByUnitID(#co.UnitID, #pad.EndDate) us
										 WHERE u.UnitTypeID = #Occupancy.UnitTypeID
											AND #co.OccupiedUnitLeaseGroupID IS NULL 
											AND us.[Status] IN ('Admin', 'Model'))

	UPDATE #Occupancy SET Down = (SELECT COUNT(*) 
									FROM #CurrentOccupants #co
										INNER JOIN Unit u ON u.UnitID = #co.UnitID
										INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #co.PropertyID
										CROSS APPLY GetUnitStatusByUnitID(#co.UnitID, #pad.EndDate) us
									WHERE u.UnitTypeID = #Occupancy.UnitTypeID
									AND #co.OccupiedUnitLeaseGroupID IS NULL 
									AND us.[Status] IN ('Down'))


	/*  ON NOTICE SUMMARY STUFF  */

	CREATE TABLE #OnNoticeSummary (
		PropertyID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		UnitType nvarchar(100),
		Units int,
		NewNotices int,
		TotalOnNotice int
	)

	IF (@onlyProjectedOccupancy = 0)
	BEGIN
		INSERT INTO #OnNoticeSummary
			SELECT
				PropertyID,
				UnitTypeID,
				UnitType,
				UnitCount,
				0, 
				0
			FROM #UnitCounts

		UPDATE #OnNoticeSummary SET NewNotices = (SELECT COUNT(*) 
										FROM #ResidentActivity #ra
										WHERE #ra.UnitTypeID = #OnNoticeSummary.UnitTypeID
										AND #ra.[Type] = 'NTV')
	
		UPDATE #OnNoticeSummary SET TotalOnNotice = (SELECT COUNT(*) 
													 FROM #CurrentOccupants #cu
														INNER JOIN Unit u ON u.UnitID = #cu.UnitID
														INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #cu.PropertyID
													 WHERE u.UnitTypeID = #OnNoticeSummary.UnitTypeID
														AND #cu.OccupiedUnitLeaseGroupID IS NOT NULL 
														AND #cu.OccupiedNTVDate <= #pad.EndDate
														AND #cu.OccupiedMoveOutDate IS NOT NULL)
	END -- END OF IF(@onlyProjectedOccupancy = 0)


	/*  VACANCY LISTING STUFF  */

	CREATE TABLE #VacancyListing (
		PropertyID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		UnitType nvarchar(100),
		UnitID uniqueidentifier,
		Unit nvarchar(100),
		PaddedUnitNumber nvarchar(100),
		VacancyStatus nvarchar(100),
		[Status] nvarchar(100),
		MarketRent money,
		OccupiedLastLeaseID uniqueidentifier,
		MoveOutDate date,
		MoveOutReason nvarchar(100),
		MoveInDate date,
		ReportEndDate date
	)

	INSERT INTO #VacancyListing
		SELECT 
			#co.PropertyID,
			ut.UnitTypeID,
			ut.Name,
			#co.UnitID,
			u.Number,
			u.PaddedNumber,
			(CASE WHEN #co.OccupiedUnitLeaseGroupID IS NULL THEN 'Vacant'
				  ELSE 'On-Notice'
			 END),
			 us.[Status],
			 mr.Amount,
			 #co.OccupiedLastLeaseID,
			 #co.OccupiedMoveOutDate,
			 null AS 'MoveOutReason',
			 #co.PendingMoveInDate AS 'MoveInDate',
			 #pad.EndDate
		FROM #CurrentOccupants #co
			INNER JOIN Unit u ON u.UnitID = #co.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #co.PropertyID
			CROSS APPLY GetUnitStatusByUnitID(#co.UnitID, #pad.EndDate) us
			CROSS APPLY GetMarketRentByDate(u.UnitID, #pad.EndDate, 1) mr
			WHERE #co.OccupiedUnitLeaseGroupID IS NULL
			  OR (#co.OccupiedMoveOutDate IS NOT NULL AND #co.OccupiedNTVDate IS NULL)
			  OR (#co.OccupiedMoveOutDate IS NOT NULL AND #co.OccupiedNTVDate <= #pad.EndDate)												


	UPDATE #VacancyListing
		SET MoveOutReason = (SELECT TOP 1 pl.ReasonForLeaving
									  FROM PersonLease pl
									  WHERE pl.LeaseID = #VacancyListing.OccupiedLastLeaseID
										AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted')
									  ORDER BY MoveOutDate DESC, OrderBy, PersonLeaseID)
	WHERE OccupiedLastLeaseID IS NOT NULL

	---- if Vacant then get the last lease's move out date and reason
	UPDATE #vl SET
		#vl.MoveOutDate = pl.MoveOutDate,
		#vl.MoveOutReason = pl.ReasonForLeaving
	FROM #VacancyListing #vl
		INNER JOIN PersonLease pl ON pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																FROM PersonLease pl
																INNER JOIN Lease l on pl.LeaseID = l.LeaseID
																INNER JOIN UnitLeaseGroup ulg on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																INNER JOIN Unit u ON u.UnitID = ulg.UnitID
																INNER JOIN Building b ON b.BuildingID = u.BuildingID
																INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = b.PropertyID
															WHERE ulg.UnitID = #vl.UnitID
																AND pl.ResidencyStatus IN ('Former', 'Evicted')
																AND l.LeaseStatus IN ('Former', 'Evicted')
																-- Make sure this lease moved out before the @date
																AND (SELECT TOP 1 pl2.MoveOutDate
																		FROM PersonLease pl2
																		WHERE pl2.LeaseID = l.LeaseID
																		ORDER BY pl2.MoveOutDate DESC) <= #pad.EndDate
															ORDER BY pl.MoveOutDate DESC, pl.OrderBy, pl.PersonLeaseID)
	WHERE #vl.OccupiedLastLeaseID IS NULL
		

	/*  APPLICANTS STUFF  */

	CREATE TABLE #Applicants (
		[Type] nvarchar(100),
		PropertyID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		UnitType nvarchar(100),
		UnitID uniqueidentifier,
		Unit nvarchar(50),
		PaddedUnitNumber nvarchar(50),
		UnitLeaseGroupID uniqueidentifier,
		LeaseID uniqueidentifier,
		Residents nvarchar(1000),
		MarketRent money,
		EffectiveRent money,
		ApplicationDate date,
		SignedDate date,
		LeaseStartDate date,
		LeaseEndDate date,
		MoveInDate date,
		CancelledDeniedReason nvarchar(100),		
		CancelledDeniedDate date,
		LeasingAgent nvarchar(200),
		ProspectSource nvarchar(200),
		PriorEffectiveRent money,
		IsRenewal bit,
		PreviousLeaseID uniqueidentifier						
	)

	IF (@onlyProjectedOccupancy = 0)
	BEGIN
		-- NewApplication
		INSERT INTO #Applicants
			SELECT 
				'NewApplication' AS 'Type',
				p.PropertyID,
				ut.UnitTypeID,
				ut.Name,
				u.UnitID,
				u.Number,
				u.PaddedNumber,
				l.UnitLeaseGroupID,
				l.LeaseID,
				'' AS 'Residents',
				mr.Amount AS 'MarketRent',
				0 AS 'EffectiveRent',
				pl.ApplicationDate,
				null AS 'SignedDate',
				l.LeaseStartDate,
				l.LeaseEndDate,
				pl.MoveInDate,
				null AS 'CancelledDeniedReason',
				null AS 'CancelledDeniedDate',
				lap.FirstName + ' ' + lap.LastName AS 'LeasingAgent',
				null AS 'ProspectSource',
				null AS 'PriorEffectiveRent',
				0 AS 'IsRenewal',
				null AS 'PreviousLeaseID'
			FROM Lease l
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID		
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
				LEFT JOIN Person lap ON lap.PersonID = l.LeasingAgentPersonID	
				CROSS APPLY GetMarketRentByDate(u.UnitID, pl.ApplicationDate, 1) mr	
			WHERE pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID	
													FROM PersonLease 
													WHERE LeaseID = l.LeaseID
													ORDER BY ApplicationDate, OrderBy, PersonLeaseID)
				AND pl.ApplicationDate >= #pad.StartDate
				AND pl.ApplicationDate <= #pad.EndDate


		-- Approved Application
		INSERT INTO #Applicants
			SELECT 
				'ApprovedApplication' AS 'Type',
				p.PropertyID,
				ut.UnitTypeID,
				ut.Name,
				u.UnitID,
				u.Number,
				u.PaddedNumber,
				l.UnitLeaseGroupID,
				l.LeaseID,
				'' AS 'Residents',
				mr.Amount AS 'MarketRent',
				0 AS 'EffectiveRent',
				pl.ApplicationDate,
				null AS 'SignedDate',
				l.LeaseStartDate,
				l.LeaseEndDate,
				pl.MoveInDate,
				null AS 'CancelledDeniedReason',
				pn.[Date] AS 'CancelledDeniedDate',
				lap.FirstName + ' ' + lap.LastName AS 'LeasingAgent',
				null AS 'ProspectSource',
				null AS 'PriorEffectiveRent',
				0 AS 'IsRenewal',
				null AS 'PreviousLeaseID'
			FROM Lease l
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID		
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
				LEFT JOIN Person lap ON lap.PersonID = l.LeasingAgentPersonID	
				CROSS APPLY GetMarketRentByDate(u.UnitID, pl.ApplicationDate, 1) mr	
				INNER JOIN PersonNote pn ON pl.PersonID = pn.PersonID AND pn.PropertyID = #pad.PropertyID AND pn.InteractionType = 'Approved' 
			WHERE pl.PersonLeaseID = (SELECT TOP 1 pl1.PersonLeaseID	
												FROM PersonLease pl1
													INNER JOIN PersonNote pn1 on pl1.PersonID = pn1.personID
												WHERE pl1.LeaseID = l.LeaseID
													AND pn1.PropertyID = p.PropertyID
													AND pl1.ApprovalStatus = 'Approved'
													AND pn1.InteractionType = 'Approved'
												ORDER BY pn1.[Date] ASC, pl1.ApplicationDate, pl1.OrderBy, pl1.PersonLeaseID)
				AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID
									   FROM PersonNote pn2
									   WHERE pn2.PersonID = pl.PersonID
										AND pn2.InteractionType = 'Approved'
										AND pn2.PropertyID = #pad.PropertyID
										AND pn2.DateCreated > l.DateCreated -- Approval is after the lease is created. This accounts for transferred leases. Don't want to show a transferred lease as approved 2 years before
									   ORDER BY pn2.[Date] ASC)
				AND pn.[Date] >= #pad.StartDate
				AND pn.[Date] <= #pad.EndDate				
				AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
								 FROM Lease l2 
								 WHERE l2.UnitLeaseGroupID = l.UnitLeaseGroupID
								 ORDER by l2.DateCreated)


	

		-- Cancelled and Denied Applications
		INSERT INTO #Applicants
			SELECT 
				(CASE WHEN l.LeaseStatus = 'Cancelled' THEN 'CancelledApplication' 
					  ELSE 'DeniedApplication'
				 END) AS 'Type',
				p.PropertyID,
				ut.UnitTypeID,
				ut.Name,
				u.UnitID,
				u.Number,
				u.PaddedNumber,
				l.UnitLeaseGroupID,
				l.LeaseID,
				'' AS 'Residents',
				mr.Amount AS 'MarketRent',
				0 AS 'EffectiveRent',
				pl.ApplicationDate,
				null AS 'SignedDate',
				l.LeaseStartDate,
				l.LeaseEndDate,
				pl.MoveInDate,
				pl.ReasonForLeaving AS 'CancelledDeniedReason',
				pl.MoveOutDate AS 'CancelledDeniedDate',
				lap.FirstName + ' ' + lap.LastName AS 'LeasingAgent',
				null AS 'ProspectSource',
				null AS 'PriorEffectiveRent',
				0 AS 'IsRenewal',
				null AS 'PreviousLeaseID'
			FROM Lease l
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID		
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
				LEFT JOIN Person lap ON lap.PersonID = l.LeasingAgentPersonID
				CROSS APPLY GetMarketRentByDate(u.UnitID, pl.ApplicationDate, 1) mr
			WHERE pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID	
						FROM PersonLease 
						WHERE LeaseID = l.LeaseID
						ORDER BY MoveOutDate DESC, OrderBy, PersonLeaseID)
				AND l.LeaseStatus IN ('Cancelled', 'Denied')
				AND pl.MoveOutDate >= #pad.StartDate
				AND pl.MoveOutDate <= #pad.EndDate

		-- Signed Applications
		INSERT INTO #Applicants
			SELECT 
				'SignedApplication' AS 'Type',
				p.PropertyID,
				ut.UnitTypeID,
				ut.Name,
				u.UnitID,
				u.Number,
				u.PaddedNumber,
				l.UnitLeaseGroupID,
				l.LeaseID,
				'' AS 'Residents',
				mr.Amount AS 'MarketRent',
				0 AS 'EffectiveRent',
				pl.ApplicationDate,
				pl.LeaseSignedDate AS 'SignedDate',
				l.LeaseStartDate,
				l.LeaseEndDate,
				pl.MoveInDate,
				null AS 'CancelledDeniedReason',
				null AS 'CancelledDeniedDate',
				lap.FirstName + ' ' + lap.LastName AS 'LeasingAgent',
				null AS 'ProspectSource',
				null AS 'PriorEffectiveRent',
				0 AS 'Renewal',
				null AS 'PreviousLeaseID'
			FROM Lease l
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID		
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
				LEFT JOIN Person lap ON lap.PersonID = l.LeasingAgentPersonID
				CROSS APPLY GetMarketRentByDate(u.UnitID, pl.ApplicationDate, 1) mr
			WHERE pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID	
										FROM PersonLease 
										WHERE LeaseID = l.LeaseID
											AND LeaseSignedDate IS NOT NULL
										ORDER BY LeaseSignedDate, OrderBy, PersonLeaseID)
				AND l.LeaseStatus NOT IN ('Cancelled', 'Denied')
				AND pl.LeaseSignedDate >= #pad.StartDate
				AND pl.LeaseSignedDate <= #pad.EndDate

		UPDATE #Applicants SET IsRenewal = 1 WHERE LeaseID <> (SELECT TOP 1 LeaseID 
															   FROM Lease 
															   WHERE UnitLeaseGroupID = #Applicants.UnitLeaseGroupID
															   ORDER BY LeaseStartDate, DateCreated)

		UPDATE #Applicants SET [Type] = REPLACE([Type], 'Application', 'Renewal') WHERE IsRenewal = 1

		UPDATE #Applicants SET Residents = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
																 FROM Person 
																	 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID																																		 
																 WHERE PersonLease.LeaseID = #Applicants.LeaseID																   		   
																	   AND PersonLease.MainContact = 1				   
																 FOR XML PATH ('')), 1, 2, '')


		UPDATE #Applicants SET EffectiveRent = ISNULL((SELECT ISNULL(Sum(lli.Amount), 0) 
																FROM LeaseLedgerItem lli
																INNER JOIN LedgerItem li on li.LedgerItemID = lli.LedgerItemID
																INNER JOIN LedgerItemType lit on lit.LedgerItemTypeID = li.LedgerItemTypeID
																WHERE lli.LeaseID = #Applicants.LeaseID 
																		AND lit.IsRent = 1
																		AND lli.StartDate <= #Applicants.LeaseEndDate), 0)
	
	
		UPDATE #Applicants SET EffectiveRent = EffectiveRent - ISNULL((SELECT ISNULL(SUM(lli.Amount), 0)
																			FROM LeaseLedgerItem lli
																				INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
																				INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID  AND lit.IsCredit = 1 AND lit.IsRecurringMonthlyRentConcession = 1																		
																			WHERE lli.LeaseID = #Applicants.LeaseID
																			  AND lli.StartDate <= #Applicants.LeaseEndDate), 0)

		UPDATE #Applicants SET PreviousLeaseID = (SELECT TOP 1 l.LeaseID
													FROM Lease l 
														INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
														INNER JOIN Unit u ON ulg.UnitID = u.UnitID
													WHERE u.UnitID = #Applicants.UnitID
														AND l.LeaseID <> #Applicants.LeaseID
														AND l.UnitLeaseGroupID = #Applicants.UnitLeaseGroupID
														AND l.LeaseStartDate < #Applicants.LeaseStartDate
														AND l.LeaseStatus IN ('Current', 'Renewed')
													ORDER BY DateCreated DESC)
		WHERE #Applicants.IsRenewal = 1

		--Get Previous LeaseID for transfers
		UPDATE #Applicants SET PreviousLeaseID = (SELECT TOP 1 l2.LeaseID
													FROM Lease l1 
														INNER JOIN PersonLease pl1 ON l1.leaseID = pl1.leaseID
														INNER JOIN PersonLease pl2 on pl1.personID = pl2.personID
														INNER JOIN Lease l2 on pl2.leaseID = l2.leaseID
													WHERE l1.LeaseID = #Applicants.LeaseID 
													  AND l2.LeaseID <> l1.LeaseID
													  AND l2.LeaseStartDate < l1.LeaseStartDate -- previous to current lease
													  AND pl2.ReasonForLeaving = 'Onsite Transfer'
													ORDER BY l2.DateCreated DESC)
		WHERE #Applicants.[Type] IN ('SignedApplication', 'NewApplication')
		  AND #Applicants.PreviousLeaseID IS NULL

		UPDATE #Applicants SET PriorEffectiveRent = ISNULL((SELECT ISNULL(Sum(lli.Amount), 0) 
																FROM LeaseLedgerItem lli
																INNER JOIN LedgerItem li on li.LedgerItemID = lli.LedgerItemID
																INNER JOIN LedgerItemType lit on lit.LedgerItemTypeID = li.LedgerItemTypeID
																INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
																WHERE lli.LeaseID = #Applicants.PreviousLeaseID 
																		AND lit.IsRent = 1
																		AND lli.StartDate <= l.LeaseEndDate), 0)
		WHERE PreviousLeaseID IS NOT NULL
	
	
		UPDATE #Applicants SET PriorEffectiveRent = PriorEffectiveRent - ISNULL((SELECT ISNULL(SUM(lli.Amount), 0)
																			FROM LeaseLedgerItem lli
																				INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
																				INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID  AND lit.IsCredit = 1 AND lit.IsRecurringMonthlyRentConcession = 1																		
																				INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
																			WHERE lli.LeaseID = #Applicants.PreviousLeaseID
																			  AND lli.StartDate <= l.LeaseEndDate), 0)
		WHERE PreviousLeaseID IS NOT NULL


		-- Update prospect id for main prospects
		UPDATE #Applicants SET ProspectSource = (SELECT TOP 1 ps.Name
													FROM Prospect pr													  
														INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
														INNER JOIN PersonLease pl ON pl.LeaseID = #Applicants.LeaseID AND pr.PersonID = pl.PersonID
														INNER JOIN ProspectSource ps ON ps.ProspectSourceID = pps.ProspectSourceID
													WHERE pps.PropertyID = #Applicants.PropertyID)
		WHERE [Type] IN ('SignedApplication', 'NewApplication', 'CancelledApplication', 'ApprovedApplication')												   	
													 
		-- Update prospect id for roommates											 
		UPDATE #Applicants SET ProspectSource = (SELECT TOP 1 ps.Name
												FROM Prospect pr	
													INNER JOIN ProspectRoommate proroom ON pr.ProspectID = proroom.ProspectID												 
													INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													INNER JOIN PersonLease pl ON pl.LeaseID = #Applicants.LeaseID AND proroom.PersonID = pl.PersonID
													INNER JOIN ProspectSource ps ON ps.ProspectSourceID = pps.ProspectSourceID
												WHERE pps.PropertyID = #Applicants.PropertyID)
		WHERE [Type] IN ('SignedApplication', 'NewApplication', 'CancelledApplication', 'ApprovedApplication')
			AND #Applicants.ProspectSource IS NULL	

	END -- END OF IF(@onlyProjectedOccupancy = 0)



	/*  APPLICATIONS AND RENEWALS STUFF  */

	CREATE TABLE #ApplicationsAndRenewals (
		PropertyID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		UnitType nvarchar(100),
		Units int,
		NewApplied int,
		NewCancelled int,
		NewDenied int,
		NewApproved int,
		NewSigned int,
		RenewApplied int,
		RenewCancelled int,
		RenewSigned int,
		Leased int
	)

	IF (@onlyProjectedOccupancy = 0)
	BEGIN
		INSERT INTO #ApplicationsAndRenewals
			SELECT
				PropertyID,
				UnitTypeID,
				UnitType,
				UnitCount,
				0 As 'NewApplied', 
				0 AS 'NewCancelled',
				0 AS 'NewDenied', 
				0 AS 'NewApproved',
				0 AS 'NewSigned',
				0 AS 'RenewalApplied', 
				0 AS 'RenewalCancelled',
				0 AS 'RenewalSigned',
				0 As 'Leased'
			FROM #UnitCounts

		UPDATE #ApplicationsAndRenewals SET NewApplied = (SELECT COUNT(*) 
														   FROM #Applicants #a
														   WHERE #a.UnitTypeID = #ApplicationsAndRenewals.UnitTypeID
															AND #a.[Type] = 'NewApplication')

		UPDATE #ApplicationsAndRenewals SET NewCancelled = (SELECT COUNT(*) 
														   FROM #Applicants #a
														   WHERE #a.UnitTypeID = #ApplicationsAndRenewals.UnitTypeID
															AND #a.[Type] = 'CancelledApplication')

		UPDATE #ApplicationsAndRenewals SET NewDenied = (SELECT COUNT(*) 
														   FROM #Applicants #a
														   WHERE #a.UnitTypeID = #ApplicationsAndRenewals.UnitTypeID
															AND #a.[Type] = 'DeniedApplication')

		UPDATE #ApplicationsAndRenewals SET NewApproved = (SELECT COUNT(*) 
														   FROM #Applicants #a
														   WHERE #a.UnitTypeID = #ApplicationsAndRenewals.UnitTypeID
															AND #a.[Type] = 'ApprovedApplication')

		UPDATE #ApplicationsAndRenewals SET NewSigned = (SELECT COUNT(*) 
														   FROM #Applicants #a
														   WHERE #a.UnitTypeID = #ApplicationsAndRenewals.UnitTypeID
															AND #a.[Type] = 'SignedApplication')

		UPDATE #ApplicationsAndRenewals SET RenewApplied = (SELECT COUNT(*) 
															   FROM #Applicants #a
															   WHERE #a.UnitTypeID = #ApplicationsAndRenewals.UnitTypeID
																AND #a.[Type] = 'NewRenewal')

		UPDATE #ApplicationsAndRenewals SET RenewCancelled = (SELECT COUNT(*) 
														   FROM #Applicants #a
														   WHERE #a.UnitTypeID = #ApplicationsAndRenewals.UnitTypeID
															AND #a.[Type] = 'CancelledRenewal')


		UPDATE #ApplicationsAndRenewals SET RenewSigned = (SELECT COUNT(*) 
														   FROM #Applicants #a
														   WHERE #a.UnitTypeID = #ApplicationsAndRenewals.UnitTypeID
															AND #a.[Type] = 'SignedRenewal')

		UPDATE #ApplicationsAndRenewals SET Leased = (SELECT COUNT(*) 
														   FROM #CurrentOccupants #co
															INNER JOIN Unit u ON u.UnitID = #co.UnitID
														   WHERE u.UnitTypeID = #ApplicationsAndRenewals.UnitTypeID
															 AND ((#co.OccupiedUnitLeaseGroupID IS NOT NULL AND #co.OccupiedMoveOutDate IS NULL)
															 --OR (#co.OccupiedUnitLeaseGroupID IS NOT NULL AND #co.OccupiedMoveOutDate IS NULL AND #co.PendingUnitLeaseGroupID IS NOT NULL)
															 OR (#co.PendingUnitLeaseGroupID IS NOT NULL)))

	END -- END OF IF(@onlyProjectedOccupancy = 0)


	CREATE TABLE #Properties (
		PropertyID uniqueidentifier not null,
		Name nvarchar(50) not null)
	
	INSERT #Properties 
		SELECT	pIDs.Value, prop.Name
			FROM @propertyIDs pIDs
				INNER JOIN Property prop ON pIDs.Value = prop.PropertyID
	
	
	SELECT * FROM #ResidentActivity
	SELECT * FROM #Occupancy
	SELECT * FROM #OnNoticeSummary
	SELECT * FROM #VacancyListing
	SELECT * FROM #Applicants
	SELECT * FROM #ApplicationsAndRenewals
	--SELECT * FROM #CurrentOccupants 
	SELECT * FROM #Properties
	
END
GO
