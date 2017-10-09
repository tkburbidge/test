SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 17, 2015
-- Description:	Gets the data for the MFG Nightly Property Summary
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_MFG_NightlyPropertySummary] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyIDs GuidCollection READONLY, 
	@date date = null,
	@accountingPeriodID uniqueidentifier = null
AS

DECLARE @currentMonthStartDate date
DECLARE @nextMonthStartDate date				-- NOTE, this is going to be the first day of the next month, so current month will be <, not <=  
DECLARE @nextMonthEndDate date
DECLARE @objectIDs GuidCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #MFGNightlyNumbers ( 
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) null,
		Units int null,
		NumberOccupied int null,
		Occupancy decimal(7, 2) null,
		Leased decimal(7, 2) null,
		VacantUnits int null,
		VacantPreleased int null,
		VacantNotPreLeased int null,
		OnNotice int null,
		OnNoticePreLeased int null,
		ApprovedApplications int null,
		HoldingUnitApplications int null,
		OnNotice30Days int null,
		OnNoticeNotLeased30Days int null,
		OnNoticePreLeased30Days int null,
		OnNotice60Days int null,
		OnNoticeNotLeased60Days int null,
		OnNoticePreLeased60Days int null,
		OnNotice90Days int null,
		OnNoticeNotLeased90Days int null,
		OnNoticePreLeased90Days int null,
		LeaseExpirationsCurrentMonth int null,
		LeaseExpirationsCurrentMonthOnNotice int null,
		LeaseExpirationsCurrentMonthTransferring int null,
		LeaseExpirationsCurrentMonthRenewing int null,
		LeaseExpirationsCurrentMonthSignedRenewals int null,
		LeaseExpirationsNextMonth int null,
		LeaseExpirationsNextMonthOnNotice int null,
		LeaseExpirationsNextMonthTransferring int null,
		LeaseExpirationsNextMonthRenewing int null,
		LeaseExpirationsNextMonthSignedRenewals int null,
		WorkOrdersCompletedToday int null,
		OutstandingWorkOrders int null,
		CumulativeCollections money null,
		DelinquentBalances money null,
		CallsToday int null,
		UntisShownToday int null,
		ApplicationsReceivedToday int null,
		ApplicationsApprovedToday int null,
		RenewalsSignedToday int null,
		CallsThisMonth int null,
		UntisShownThisMonth int null,
		ApplicationsReceivedThisMonth int null)
		
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
		
	CREATE TABLE #LeasesExpiringThisMonth (
		LeaseID uniqueidentifier not null,
		PropertyID uniqueidentifier not null)
		
	CREATE TABLE #ObjectsAndBalancesThisMonth (
		ObjectID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		Balance money null)
		
	CREATE TABLE #Properties (
		PropertyID uniqueidentifier not null)
		
	INSERT #Properties
		SELECT Value FROM @propertyIDs
		
	SET @currentMonthStartDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @date), 0)
	SET @nextMonthStartDate = DATEADD(MONTH, 1, @currentMonthStartDate)
	SET @nextMonthEndDate = DATEADD(DAY, -1, DATEADD(MONTH, 2, @currentMonthStartDate))

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @date, @accountingPeriodID, @propertyIDs	
		
	INSERT #MFGNightlyNumbers
		SELECT	DISTINCT
				#lau.PropertyID,
				prop.Name AS 'PropertyName',
				ISNULL(COUNT(#lau.UnitID), 0) AS 'Units',
				null, null, null, null, null, null, null, null, null, null,				-- 10 each, total of 41 nulls, which I think is right.
				null, null, null, null, null, null, null, null, null, null,
				null, null, null, null, null, null, null, null, null, null,
				null, null, null, null, null, null, null, null, null, null,
				null
			FROM #LeasesAndUnits #lau
				INNER JOIN Property prop ON #lau.PropertyID = prop.PropertyID	
			GROUP BY #lau.PropertyID, prop.Name		
 
  	UPDATE #MFGNightlyNumbers SET Units = ISNULL((SELECT COUNT(UnitID) 
													FROM #LeasesAndUnits
													WHERE PropertyID = #MFGNightlyNumbers.PropertyID
													GROUP BY PropertyID), 0)
											
	UPDATE #MFGNightlyNumbers SET NumberOccupied = ISNULL((SELECT COUNT(UnitID)
															  FROM #LeasesAndUnits
															  WHERE OccupiedUnitLeaseGroupID IS NOT NULL
															    AND PropertyID = #MFGNightlyNumbers.PropertyID
															  GROUP BY PropertyID), 0)
														
	UPDATE #MFGNightlyNumbers SET Occupancy = ISNULL(100.0 * (CAST(NumberOccupied AS DECIMAL(7, 2)) / CAST(Units AS DECIMAL(7, 2))), 0)
		WHERE Units <> 0

															
	UPDATE #MFGNightlyNumbers SET VacantUnits = ISNULL((SELECT COUNT(UnitID)
														  FROM #LeasesAndUnits
														  WHERE OccupiedUnitLeaseGroupID IS NULL
															AND PropertyID = #MFGNightlyNumbers.PropertyID
														  GROUP BY PropertyID), 0)
													  
	UPDATE #MFGNightlyNumbers SET VacantPreleased = ISNULL((SELECT COUNT(UnitID)
																FROM #LeasesAndUnits
																WHERE PendingUnitLeaseGroupID IS NOT NULL
																  AND OccupiedUnitLeaseGroupID IS NULL
																  AND PropertyID = #MFGNightlyNumbers.PropertyID
																GROUP BY PropertyID), 0)
														
	UPDATE #MFGNightlyNumbers SET VacantNotPreLeased = ISNULL((SELECT COUNT(UnitID)
																	FROM #LeasesAndUnits
																	WHERE PendingUnitLeaseGroupID IS NULL
																	  AND OccupiedUnitLeaseGroupID IS NULL
																	  AND PropertyID = #MFGNightlyNumbers.PropertyID
																	GROUP BY PropertyID), 0)

	UPDATE #MFGNightlyNumbers SET OnNotice = ISNULL((SELECT COUNT(UnitID)
														  FROM #LeasesAndUnits
														  WHERE OccupiedUnitLeaseGroupID IS NOT NULL
															AND OccupiedMoveOutDate IS NOT NULL
															AND PropertyID = #MFGNightlyNumbers.PropertyID
														  GROUP BY PropertyID), 0)																		
															
	UPDATE #MFGNightlyNumbers SET OnNoticePreLeased = ISNULL((SELECT COUNT(UnitID)
															  FROM #LeasesAndUnits
															  WHERE OccupiedUnitLeaseGroupID IS NOT NULL
																AND OccupiedMoveOutDate IS NOT NULL
																AND PendingUnitLeaseGroupID IS NOT NULL
																AND PropertyID = #MFGNightlyNumbers.PropertyID
															  GROUP BY PropertyID), 0)				
	
	-- 2015-5-15: They want the lease calculation to be occupied + vacant pre-leased / total units
	UPDATE #MFGNightlyNumbers SET Leased = ISNULL(100.0 * ((CAST(NumberOccupied AS DECIMAL(7, 2)) ---
															--CAST(OnNotice AS DECIMAL(7, 2)) +
															 --CAST(OnNoticePreLeased AS DECIMAL(7, 2)) + 
															 + CAST(VacantPreLeased AS DECIMAL(7, 2))) / CAST(Units AS DECIMAL(7, 2))), 0)
		WHERE Units <> 0


	UPDATE #MFGNightlyNumbers SET ApprovedApplications = ISNULL((SELECT COUNT(DISTINCT l.LeaseID)
																	  FROM Lease l
																		  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																		  INNER JOIN Unit u ON ulg.UnitID = u.UnitID AND u.IsHoldingUnit = 0 AND u.ExcludedFromOccupancy = 0																						
																		  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID 
																		  INNER JOIN #Properties #p ON ut.PropertyID = #p.PropertyID
																		  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ResidencyStatus = 'Approved'
																	   WHERE l.LeaseStatus = 'Pending'
																	     AND ut.PropertyID = #MFGNightlyNumbers.PropertyID
																	   GROUP BY #p.PropertyID), 0)
															   
	UPDATE #MFGNightlyNumbers SET HoldingUnitApplications = ISNULL((SELECT COUNT(DISTINCT l.LeaseID)
																	    FROM Lease l
																		    INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																		    INNER JOIN Unit u ON ulg.UnitID = u.UnitID AND u.IsHoldingUnit = 1
																		    INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID 
																		    INNER JOIN #Properties #p ON ut.PropertyID = #p.PropertyID
																		    INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ResidencyStatus = 'Approved'
																	     WHERE l.LeaseStatus = 'Pending'
																	       AND ut.PropertyID = #MFGNightlyNumbers.PropertyID
																	     GROUP BY #p.PropertyID), 0)		
																   
	UPDATE #MFGNightlyNumbers SET OnNotice30Days = ISNULL((SELECT COUNT(UnitID)
															  FROM #LeasesAndUnits 
															  WHERE OccupiedUnitLeaseGroupID IS NOT NULL
																AND OccupiedMoveOutDate IS NOT NULL
															    AND OccupiedMoveOutDate <= DATEADD(DAY, 30, @date)
															    AND PropertyID = #MFGNightlyNumbers.PropertyID
															  GROUP BY PropertyID), 0)
														
	UPDATE #MFGNightlyNumbers SET OnNoticeNotLeased30Days = ISNULL((SELECT COUNT(UnitID)
																		FROM #LeasesAndUnits 
																		WHERE OccupiedUnitLeaseGroupID IS NOT NULL
																		  AND OccupiedMoveOutDate IS NOT NULL
																		  AND OccupiedMoveOutDate <= DATEADD(DAY, 30, @date)
																		  AND PropertyID = #MFGNightlyNumbers.PropertyID
																		  AND PendingUnitLeaseGroupID IS NULL
																		GROUP BY PropertyID), 0)			
																
	UPDATE #MFGNightlyNumbers SET OnNoticePreLeased30Days = ISNULL((SELECT COUNT(UnitID)
																		FROM #LeasesAndUnits 
																		WHERE OccupiedUnitLeaseGroupID IS NOT NULL
																		  AND OccupiedMoveOutDate IS NOT NULL
																		  AND OccupiedMoveOutDate <= DATEADD(DAY, 30, @date)
																		  AND PropertyID = #MFGNightlyNumbers.PropertyID
																		  AND PendingUnitLeaseGroupID IS NOT NULL
																		GROUP BY PropertyID), 0)																																								   
																   
	UPDATE #MFGNightlyNumbers SET OnNotice60Days = ISNULL((SELECT COUNT(UnitID)
															  FROM #LeasesAndUnits 
															  WHERE OccupiedUnitLeaseGroupID IS NOT NULL
																AND OccupiedMoveOutDate IS NOT NULL
															    AND OccupiedMoveOutDate > DATEADD(DAY, 30, @date)
															    AND OccupiedMoveOutDate <= DATEADD(DAY, 60, @date)
															    AND PropertyID = #MFGNightlyNumbers.PropertyID
															  GROUP BY PropertyID), 0)
														
	UPDATE #MFGNightlyNumbers SET OnNoticeNotLeased60Days = ISNULL((SELECT COUNT(UnitID)
																		FROM #LeasesAndUnits 
																		WHERE OccupiedUnitLeaseGroupID IS NOT NULL
																		  AND OccupiedMoveOutDate IS NOT NULL
																		  AND OccupiedMoveOutDate > DATEADD(DAY, 30, @date)
																		  AND OccupiedMoveOutDate <= DATEADD(DAY, 60, @date)
																		  AND PropertyID = #MFGNightlyNumbers.PropertyID
																		  AND PendingUnitLeaseGroupID IS NULL
																		GROUP BY PropertyID), 0)				
																
	UPDATE #MFGNightlyNumbers SET OnNoticePreLeased60Days = ISNULL((SELECT COUNT(UnitID)
																		FROM #LeasesAndUnits 
																		WHERE OccupiedUnitLeaseGroupID IS NOT NULL
																		  AND OccupiedMoveOutDate IS NOT NULL
																		  AND OccupiedMoveOutDate > DATEADD(DAY, 30, @date)
																		  AND OccupiedMoveOutDate <= DATEADD(DAY, 60, @date)
																		  AND PropertyID = #MFGNightlyNumbers.PropertyID
																		  AND PendingUnitLeaseGroupID IS NOT NULL
																		GROUP BY PropertyID), 0)																																								   
																   
	UPDATE #MFGNightlyNumbers SET OnNotice90Days = ISNULL((SELECT COUNT(UnitID)
															  FROM #LeasesAndUnits 
															  WHERE OccupiedUnitLeaseGroupID IS NOT NULL
																AND OccupiedMoveOutDate IS NOT NULL
															    AND OccupiedMoveOutDate > DATEADD(DAY, 60, @date)
															    AND OccupiedMoveOutDate <= DATEADD(DAY, 90, @date)
															    AND PropertyID = #MFGNightlyNumbers.PropertyID
															  GROUP BY PropertyID), 0)
														
	UPDATE #MFGNightlyNumbers SET OnNoticeNotLeased90Days = ISNULL((SELECT COUNT(UnitID)
																		FROM #LeasesAndUnits 
																		WHERE OccupiedUnitLeaseGroupID IS NOT NULL
																		  AND OccupiedMoveOutDate IS NOT NULL
																		  AND OccupiedMoveOutDate > DATEADD(DAY, 60, @date)
																		  AND OccupiedMoveOutDate <= DATEADD(DAY, 90, @date)
																		  AND PropertyID = #MFGNightlyNumbers.PropertyID
																		  AND PendingUnitLeaseGroupID IS NULL
																		GROUP BY PropertyID), 0)				
																
	UPDATE #MFGNightlyNumbers SET OnNoticePreLeased90Days = ISNULL((SELECT COUNT(UnitID)
																		FROM #LeasesAndUnits 
																		WHERE OccupiedUnitLeaseGroupID IS NOT NULL
																		  AND OccupiedMoveOutDate IS NOT NULL
																		  AND OccupiedMoveOutDate > DATEADD(DAY, 60, @date)
																		  AND OccupiedMoveOutDate <= DATEADD(DAY, 90, @date)
																		  AND PropertyID = #MFGNightlyNumbers.PropertyID
																		  AND PendingUnitLeaseGroupID IS NOT NULL
																		GROUP BY PropertyID), 0)

																
	INSERT #LeasesExpiringThisMonth 
		SELECT	l.LeaseID, #p.PropertyID
			FROM Lease l 
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #Properties #p ON ut.PropertyID = #p.PropertyID
			WHERE l.LeaseStatus IN ('Current', 'Under Eviction')
			  AND l.LeaseEndDate >= @currentMonthStartDate
			  AND l.LeaseEndDate < @nextMonthStartDate
--select * from #LeasesExpiringThisMonth			  
	UPDATE #MFGNightlyNumbers SET LeaseExpirationsCurrentMonth = ISNULL((SELECT COUNT(LeaseID) 
																			FROM #LeasesExpiringThisMonth 
																			WHERE PropertyID = #MFGNightlyNumbers.PropertyID
																			GROUP BY PropertyID), 0)
																
	UPDATE #MFGNightlyNumbers SET LeaseExpirationsCurrentMonthOnNotice = ISNULL((SELECT COUNT(DISTINCT #letm.LeaseID)
																					  FROM #LeasesExpiringThisMonth #letm
																						  INNER JOIN PersonLease pl ON #letm.LeaseID = pl.LeaseID
																						  LEFT JOIN PersonLease plmo ON #letm.LeaseID = plmo.LeaseID AND plmo.MoveOutDate IS NULL
																					  WHERE plmo.PersonLeaseID IS NULL
																						AND #letm.PropertyID = #MFGNightlyNumbers.PropertyID
																					  GROUP BY #letm.PropertyID), 0)														
																
	UPDATE #MFGNightlyNumbers SET LeaseExpirationsCurrentMonthTransferring = ISNULL((SELECT COUNT(DISTINCT #letm.LeaseID)
																						 FROM #LeasesExpiringThisMonth #letm
																							 INNER JOIN Lease l ON #letm.LeaseID = l.LeaseID
																							 INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																							 INNER JOIN UnitLeaseGroup ulgTrans ON ulg.UnitLeaseGroupID = ulgTrans.PreviousUnitLeaseGroupID
																							 INNER JOIN Lease tl ON tl.UnitLeaseGroupID = ulgTrans.UnitLeaseGroupID AND tl.LeaseStatus NOT IN ('Cancelled', 'Denied')
																						 WHERE #letm.PropertyID = #MFGNightlyNumbers.PropertyID																							
																						 GROUP BY #letm.PropertyID), 0)
																				  
	UPDATE #MFGNightlyNumbers SET LeaseExpirationsCurrentMonthRenewing = ISNULL((SELECT COUNT(DISTINCT #letm.LeaseID)
																					 FROM #LeasesExpiringThisMonth #letm 
																					     INNER JOIN Lease cl ON #letm.LeaseID = cl.LeaseID
																						 INNER JOIN UnitLeaseGroup ulg ON cl.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																						 INNER JOIN Lease prl ON ulg.UnitLeaseGroupID = prl.UnitLeaseGroupID AND prl.LeaseStatus IN ('Pending Renewal')
																					  WHERE #letm.PropertyID = #MFGNightlyNumbers.PropertyID
																					  GROUP BY #letm.PropertyID), 0)
																			   
	UPDATE #MFGNightlyNumbers SET LeaseExpirationsCurrentMonthSignedRenewals = ISNULL((SELECT COUNT(DISTINCT #letm.LeaseID)
																						   FROM #LeasesExpiringThisMonth #letm
																							   INNER JOIN Lease cl ON #letm.LeaseID = cl.LeaseID
																							   INNER JOIN UnitLeaseGroup ulg ON cl.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																							   INNER JOIN Lease prl ON ulg.UnitLeaseGroupID = prl.UnitLeaseGroupID AND prl.LeaseStatus IN ('Pending Renewal')
																							   INNER JOIN PersonLease prpl ON prl.LeaseID = prpl.LeaseID AND prpl.LeaseSignedDate IS NOT NULL
																							WHERE #letm.PropertyID = #MFGNightlyNumbers.PropertyID
																							GROUP BY #letm.PropertyID), 0)
	
	TRUNCATE TABLE #LeasesExpiringThisMonth
																	
	INSERT #LeasesExpiringThisMonth 
		SELECT	l.LeaseID, #p.PropertyID
			FROM Lease l 
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #Properties #p ON ut.PropertyID = #p.PropertyID
			WHERE l.LeaseStatus IN ('Current', 'Under Eviction')
			  AND l.LeaseEndDate >= @nextMonthStartDate
			  AND l.LeaseEndDate <= @nextMonthEndDate
													
	UPDATE #MFGNightlyNumbers SET LeaseExpirationsNextMonth = ISNULL((SELECT COUNT(LeaseID) 
																		  FROM #LeasesExpiringThisMonth 
																		  WHERE PropertyID = #MFGNightlyNumbers.PropertyID
																		  GROUP BY PropertyID), 0)
																																	
	UPDATE #MFGNightlyNumbers SET LeaseExpirationsNextMonthOnNotice = ISNULL((SELECT COUNT(DISTINCT #letm.LeaseID)
																				  FROM #LeasesExpiringThisMonth #letm
																					  INNER JOIN PersonLease pl ON #letm.LeaseID = pl.LeaseID
																					  LEFT JOIN PersonLease plmo ON #letm.LeaseID = plmo.LeaseID AND plmo.MoveOutDate IS NULL
																				  WHERE plmo.PersonLeaseID IS NULL
																					AND #letm.PropertyID = #MFGNightlyNumbers.PropertyID
																				  GROUP BY #letm.PropertyID), 0)														
																
	UPDATE #MFGNightlyNumbers SET LeaseExpirationsNextMonthTransferring = ISNULL((SELECT COUNT(DISTINCT #letm.LeaseID)
																					  FROM #LeasesExpiringThisMonth #letm
																						  INNER JOIN Lease l ON #letm.LeaseID = l.LeaseID
																						  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																						  INNER JOIN UnitLeaseGroup ulgTrans ON ulg.UnitLeaseGroupID = ulgTrans.PreviousUnitLeaseGroupID
																						  INNER JOIN Lease tl ON tl.UnitLeaseGroupID = ulgTrans.UnitLeaseGroupID AND tl.LeaseStatus NOT IN ('Cancelled', 'Denied')
																					  WHERE #letm.PropertyID = #MFGNightlyNumbers.PropertyID
																					  GROUP BY #letm.PropertyID), 0)
																				  
	UPDATE #MFGNightlyNumbers SET LeaseExpirationsNextMonthRenewing = ISNULL((SELECT COUNT(DISTINCT #letm.LeaseID)
																				  FROM #LeasesExpiringThisMonth #letm 
																					  INNER JOIN Lease cl ON #letm.LeaseID = cl.LeaseID
																					  INNER JOIN UnitLeaseGroup ulg ON cl.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																					  INNER JOIN Lease prl ON ulg.UnitLeaseGroupID = prl.UnitLeaseGroupID AND prl.LeaseStatus IN ('Pending Renewal')
																				   WHERE #letm.PropertyID = #MFGNightlyNumbers.PropertyID
																				   GROUP BY #letm.PropertyID), 0)
																			   
	UPDATE #MFGNightlyNumbers SET LeaseExpirationsNextMonthSignedRenewals = ISNULL((SELECT COUNT(DISTINCT #letm.LeaseID)
																						FROM #LeasesExpiringThisMonth #letm
																							INNER JOIN Lease cl ON #letm.LeaseID = cl.LeaseID
																							INNER JOIN UnitLeaseGroup ulg ON cl.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																							INNER JOIN Lease prl ON ulg.UnitLeaseGroupID = prl.UnitLeaseGroupID AND prl.LeaseStatus IN ('Pending Renewal')
																							INNER JOIN PersonLease prpl ON prl.LeaseID = prpl.LeaseID AND prpl.LeaseSignedDate IS NOT NULL
																						 WHERE #letm.PropertyID = #MFGNightlyNumbers.PropertyID
																						 GROUP BY #letm.PropertyID), 0)
		
	UPDATE #MFGNightlyNumbers SET WorkOrdersCompletedToday = ISNULL((SELECT COUNT(WorkOrderID)
																		FROM WorkOrder
																		WHERE CompletedDate IS NOT NULL
																		  AND CAST(CompletedDate AS date) = @date
																		  AND [Status] IN ('Completed', 'Closed')
																		  AND PropertyID = #MFGNightlyNumbers.PropertyID
																		GROUP BY PropertyID), 0)
																
	UPDATE #MFGNightlyNumbers SET OutstandingWorkOrders = ISNULL((SELECT COUNT(WorkOrderID)
																	  FROM WorkOrder
																	  WHERE 
																	    --(CompletedDate IS NULL OR CAST(CompletedDate AS Date) <= @date)
																		 [Status] NOT IN ('Completed', 'Closed', 'Cancelled')
																		AND PropertyID = #MFGNightlyNumbers.PropertyID
																	  GROUP BY PropertyID), 0)
															  
	--UPDATE #MFGNightlyNumbers SET CumulativeCollections = ISNULL((SELECT SUM(t.Amount)
	--																  FROM [Transaction] t 
	--																	  INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Payment') AND tt.[Group] IN ('Lease', 'Non-Resident Account', 'Prospect')
	--																	  LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
	--																  WHERE t.PropertyID = #MFGNightlyNumbers.PropertyID
	--																	AND t.TransactionDate >= @currentMonthStartDate
	--																	AND t.TransactionDate <= @date
	--																	AND tr.TransactionID IS NULL
	--																  GROUP BY t.PropertyID), 0)

	UPDATE #MFGNightlyNumbers SET CumulativeCollections = ISNULL((SELECT SUM(t.Amount)
												FROM [Transaction] t
													INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Deposit' AND tt.[Group] = 'Bank'
													INNER JOIN BankTransactionTransaction btt ON t.TransactionID = btt.TransactionID
													INNER JOIN BankTransaction bt ON btt.BankTransactionID = bt.BankTransactionID
													INNER JOIN Batch bat ON bt.BankTransactionID = bat.BankTransactionID
													LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
												WHERE bat.[Date] >= @currentMonthStartDate
													AND bat.[Date] < @nextMonthStartDate
													AND tr.TransactionID IS NULL
													AND t.PropertyID = #MFGNightlyNumbers.PropertyID
												GROUP BY t.PropertyID), 0)	

	CREATE TABLE #Charges (
		PropertyID uniqueidentifier,
		TransactionID uniqueidentifier,
		Amount money
	)

	INSERT INTO #Charges
		SELECT t.PropertyID, t.TransactionID, t.Amount
		FROM [Transaction] t
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] IN ('Lease', 'Non-Resident Account', 'Prospect', 'WOIT Account') AND tt.[Name] = 'Charge'
			--LEFT JOIN [Transaction] at ON at.AppliesToTransactionID = t.TransactionID
			LEFT JOIN [Transaction] rt ON rt.ReversesTransactionID = t.TransactionID		
			--LEFT JOIN [Transaction] rat ON rat.ReversesTransactionID = at.TransactionID					
			INNER JOIN #MFGNightlyNumbers #m on #m.PropertyID = t.PropertyID			
		WHERE t.TransactionDate >= @currentMonthStartDate
			AND t.TransactionDate < @nextMonthStartDate		
			AND (rt.TransactionID IS NULL OR rt.TransactionDate > @date)
			AND t.ReversesTransactionID IS NULL
			AND t.Amount > 0

	UPDATE #Charges SET Amount = Amount - ISNULL((SELECT SUM(ISNULL(at.Amount, 0))
										   FROM [Transaction] at
										   LEFT JOIN [Transaction] rat ON rat.ReversesTransactionID = at.TransactionID
										   WHERE at.AppliesToTransactionID = #Charges.TransactionID
											AND (rat.TransactionID IS NULL OR rat.TransactionDate > @date)), 0)

	UPDATE #MFGNightlyNumbers SET DelinquentBalances = (SELECT SUM(Amount)	
														FROM #Charges
														WHERE #Charges.PropertyID = #MFGNightlyNumbers.PropertyID)
															
	UPDATE #MFGNightlyNumbers SET CallsToday = ISNULL((SELECT COUNT(pn.PersonNoteID)
														   FROM PersonNote pn
														   WHERE pn.PersonType = 'Prospect'
														     AND pn.[Date] = @date
														     AND pn.ContactType = 'Phone'
														     AND pn.PropertyID = #MFGNightlyNumbers.PropertyID
														   GROUP BY pn.PropertyID), 0)
													
	UPDATE #MFGNightlyNumbers SET UntisShownToday = ISNULL((SELECT COUNT(PersonNoteID)
																FROM PersonNote
																WHERE PersonType = 'Prospect'
																  AND [Date] = @date
																  AND InteractionType = 'Unit Shown'
																  AND PropertyID = #MFGNightlyNumbers.PropertyID
																GROUP BY PropertyID), 0)
															  
	UPDATE #MFGNightlyNumbers SET ApplicationsReceivedToday = ISNULL((SELECT COUNT(l.LeaseID)
																	  FROM UnitLeaseGroup ulg
																		  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
																		  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
																		  INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
																		  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ApplicationDate = @date
																		  LEFT JOIN Lease priorL ON ulg.UnitLeaseGroupID = priorL.UnitLeaseGroupID AND priorL.LeaseStartDate < l.LeaseStartDate
																		  LEFT JOIN PersonLease minPLAppDate ON l.LeaseID = minPLAppDate.LeaseID AND minPLAppDate.ApplicationDate < @date
																	  WHERE priorL.LeaseID IS NULL
																	    AND minPLAppDate.PersonLeaseID IS NULL
																	    AND ut.PropertyID = #MFGNightlyNumbers.PropertyID
																	  GROUP BY ut.PropertyID), 0)

	UPDATE #MFGNightlyNumbers SET ApplicationsApprovedToday = ISNULL((SELECT COUNT(DISTINCT l.LeaseID)
																	      FROM UnitLeaseGroup ulg 
																		      INNER JOIN Unit u ON ulg.UnitID = u.UnitID
																		      INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
																		      INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
																		      INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
																		      INNER JOIN PersonNote pn ON pl.PersonID = pn.PersonID AND pn.InteractionType = 'Approved' AND pn.[Date] = @date
																		      LEFT JOIN Lease priorL ON ulg.UnitLeaseGroupID = priorL.UnitLeaseGroupID AND priorL.LeaseStartDate < l.LeaseStartDate
																	      WHERE priorL.LeaseID IS NULL
																		    AND ut.PropertyID = #MFGNightlyNumbers.PropertyID
																	      GROUP BY ut.PropertyID), 0)
															   
	UPDATE #MFGNightlyNumbers SET RenewalsSignedToday = ISNULL((SELECT COUNT(DISTINCT l.LeaseID)
																	FROM UnitLeaseGroup ulg
																		INNER JOIN Unit u ON ulg.UnitID = u.UnitID
																		INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
																		INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
																		INNER JOIN Lease priorL ON ulg.UnitLeaseGroupID = priorL.UnitLeaseGroupID AND priorL.LeaseStartDate < l.LeaseStartDate
																		INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.LeaseSignedDate = @date
																		LEFT JOIN PersonLease plMinSignedDate ON l.LeaseID = pl.LeaseID AND pl.LeaseSignedDate < @date
																	WHERE plMinSignedDate.PersonLeaseID IS NULL
																	  AND ut.PropertyID = #MFGNightlyNumbers.PropertyID
																	GROUP BY ut.PropertyID), 0)
														  												
	UPDATE #MFGNightlyNumbers SET CallsThisMonth  = ISNULL((SELECT COUNT(pn.PersonNoteID)
																FROM PersonNote pn
																WHERE pn.PersonType = 'Prospect'
																  AND pn.[Date] <= @date
																  AND pn.[Date] >= @currentMonthStartDate
																  AND pn.ContactType = 'Phone'
																  AND pn.PropertyID = #MFGNightlyNumbers.PropertyID
																GROUP BY pn.PropertyID), 0)
													
	UPDATE #MFGNightlyNumbers SET UntisShownThisMonth  = ISNULL((SELECT COUNT(PersonNoteID)
																     FROM PersonNote
																	 WHERE PersonType = 'Prospect'
																	   AND [Date] <= @date
																	   AND [Date] >= @currentMonthStartDate
																	   AND InteractionType = 'Unit Shown'
																	   AND PropertyID = #MFGNightlyNumbers.PropertyID
																	 GROUP BY PropertyID), 0)
															  
	UPDATE #MFGNightlyNumbers SET ApplicationsReceivedThisMonth = ISNULL((SELECT COUNT(DISTINCT l.LeaseID)
																			  FROM UnitLeaseGroup ulg
																				  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
																				  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
																				  INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
																				  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ApplicationDate >= @currentMonthStartDate AND pl.ApplicationDate <= @date
																				  LEFT JOIN Lease priorL ON ulg.UnitLeaseGroupID = priorL.UnitLeaseGroupID AND priorL.LeaseStartDate < l.LeaseStartDate
																				  LEFT JOIN PersonLease minPLAppDate ON l.LeaseID = minPLAppDate.LeaseID AND minPLAppDate.ApplicationDate < @currentMonthStartDate
																			  WHERE priorL.LeaseID IS NULL
																				AND minPLAppDate.PersonLeaseID IS NULL
																				AND ut.PropertyID = #MFGNightlyNumbers.PropertyID
																			  GROUP BY ut.PropertyID), 0)

	SELECT * 
		FROM #MFGNightlyNumbers
 
 
 
 
 
 
END
GO
