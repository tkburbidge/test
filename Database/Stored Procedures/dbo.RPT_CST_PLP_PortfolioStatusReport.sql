SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 21, 2016
-- Description:	Builds the data for the PLP PortfolioLeasingStatistics report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_PLP_PortfolioStatusReport] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS

DECLARE @accountID bigint = null
DECLARE @accountingPeriodID uniqueidentifier = null
DECLARE @startDate date = DATEADD(DAY, -6, @date)
DECLARE @objectIDs GuidCollection
DECLARE @unPaidInvoicesReportDate date = DATEADD(DAY, -30, @date)

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PortfolioStats (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(100) not null,
		RegionalManagerID uniqueidentifier null,
		RegionalManagerName nvarchar(100) null,
		UnitCount int null,
		BeginningVacants int null,				-- - GetConsolidatedOccupancyNumbers at @date - 7 days
		ModelUnits int null,					-- - Count of model units at @date
		DownUnits int null,						-- - Count of down units at @date
		MoveIns int null,						-- - Number of move ins during @date - 7 days and @date
		MoveOuts int null,						-- - same as MoveIns
		VacantPreleased int null,				---  GetConsolidatedOccupancyNumbers at @date
		NoticeToVacate int null,				--- GetConsolidatedOccupancyNumbers at @date
		NoticeToVacatePreleased int null,		-- -  GetConsolidatedOccupancyNumbers at @date
		VacantReady int null,					--- Number of units vacant (not preleased) with a unit status of Ready on @date
		WalkInTraffic int null,					--- Number of distinct prospect Face-To-Face interactions during the week date range
		LeasesCurrentWeek int null,				--- New applications during the week
		ActualBilledRent money null,			--- Sum of all charges where TransactionType.Group = Lease for first of the month to @date (RPT_CST_WNR_DailyReport line 130)
		MTDCollected money null,					--- RPT_CST_LEX_PropertySummary line 154 and 183
		DelinquentAmount money null,			-- = RPT_CST_LEX_PropertySummary line 213 - 234
		DelinquentCount int null,				-- - Number of accounts delinquent from above
		AccountsPayableAmount money null,		-- - [RPT_INV_UnpaidInvoices] passing in @reportDate = @date - 30, @invoiceFilterDate = 'Due Date', @useCurrentStatus = true (I think).  They want all the invoices showing over 30 days old that are unpaid. See if my logic is right
		PendingWorkOrders int null				-- - All work orders that don't have a status of Completed, Cancelled, or Closed
		)

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

	CREATE TABLE #ObjectsForBalances (
		ObjectID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		Balance money null)

	CREATE TABLE #UnpaidInvoices (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		PropertyAbbreviation nvarchar(50) not null,
		VendorID uniqueidentifier not null,
		VendorName nvarchar(500) not null,
		InvoiceID uniqueidentifier not null,
		InvoiceNumber nvarchar(500) not null,
		InvoiceDate date null,
		AccountingDate date null,
		DueDate date null,
		[Description] nvarchar(500) null,
		Total money null,
		AmountPaid money null,
		Credit bit null,
		InvoiceStatus nvarchar(20) null,
		IsHighPriorityPayment bit null,
		ApproverPersonID uniqueidentifier null,
		ApproverLastName nvarchar(500) null,
		HoldDate date null)



	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		MonthStartDate date null,
		StartDate date null,
		EndDate date null)

	INSERT #PropertiesAndDates
		SELECT Value, DATEADD(month, DATEDIFF(month, 0, @date), 0), DATEADD(DAY, -6, @date), @date
			FROM @propertyIDs

	INSERT #PortfolioStats
		SELECT	prop.PropertyID, prop.Name, per.PersonID, per.PreferredName + ' ' + per.LastName,
				null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null					-- 18 nulls
			FROM #PropertiesAndDates #pad
				INNER JOIN Property prop ON #pad.PropertyID = prop.PropertyID
				LEFT JOIN Person per ON prop.RegionalManagerPersonID = per.PersonID

	SET @accountID = (SELECT TOP 1 prop.AccountID
						  FROM #PropertiesAndDates #pad
							  INNER JOIN Property prop ON #pad.PropertyID = prop.PropertyID)

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @startDate, @accountingPeriodID, @propertyIDs	

	UPDATE #PortfolioStats SET BeginningVacants = (SELECT COUNT(DISTINCT UnitID)
													   FROM #LeasesAndUnits
													   WHERE OccupiedUnitLeaseGroupID IS NULL
													     AND PropertyID = #PortfolioStats.PropertyID)

	DELETE #LeasesAndUnits

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @date, @accountingPeriodID, @propertyIDs	

	UPDATE #PortfolioStats SET UnitCount = (SELECT COUNT(DISTINCT UnitID)
												FROM #LeasesAndUnits 
												WHERE PropertyID = #PortfolioStats.PropertyID)

	UPDATE #PortfolioStats SET ModelUnits = (SELECT COUNT(DISTINCT u.UnitID)
												FROM Unit u
													INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
													INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
													CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) [UnitStats]
												WHERE [UnitStats].[Status] = 'Model'
												  AND #pad.PropertyID = #PortfolioStats.PropertyID)

	UPDATE #PortfolioStats SET DownUnits = (SELECT COUNT(DISTINCT u.UnitID)
												FROM Unit u
													INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
													INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
													CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) [UnitStats]
												WHERE [UnitStats].[Status] = 'Down'
												  AND #pad.PropertyID = #PortfolioStats.PropertyID)

	UPDATE #PortfolioStats SET MoveIns = (SELECT COUNT(DISTINCT ulg.UnitLeaseGroupID)
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
												WHERE #pad.PropertyID = #PortfolioStats.PropertyID												  
												  AND plPrior.PersonLeaseID IS NULL
												  AND lPrior.LeaseID IS NULL
												  AND l.LeaseStatus NOT IN ('Pending Approval', 'Pending Transfer', 'Pending Renewal', 'Cancelled', 'Denied'))

	-- Good1	
	UPDATE #PortfolioStats SET MoveOuts = (SELECT COUNT(DISTINCT ulg.UnitLeaseGroupID)
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
												WHERE #pad.PropertyID = #PortfolioStats.PropertyID												 
												  AND [plAfter].PersonLeaseID IS NULL
												  AND plNull.LeaseID IS NULL
												  AND l.LeaseStatus IN ('Evicted', 'Former'))
	
	--UPDATE #PortfolioStats SET MoveIns = (SELECT COUNT(DISTINCT UnitID)
	--										  FROM #LeasesAndUnits
	--										  WHERE OccupiedMoveInDate >= @startDate
	--										    AND PropertyID = #PortfolioStats.PropertyID)

	--UPDATE #PortfolioStats SET MoveOuts = (SELECT COUNT(DISTINCT UnitID)
	--										  FROM #LeasesAndUnits
	--										  WHERE OccupiedMoveOutDate >= @startDate
	--										    AND PropertyID = #PortfolioStats.PropertyID)

	UPDATE #PortfolioStats SET VacantPreleased = (SELECT COUNT(DISTINCT UnitID)
													  FROM #LeasesAndUnits
													  WHERE OccupiedUnitLeaseGroupID IS NULL
													    AND PendingUnitLeaseGroupID IS NOT NULL
													    AND PropertyID = #PortfolioStats.PropertyID)

	UPDATE #PortfolioStats SET NoticeToVacate = (SELECT COUNT(DISTINCT UnitID)
													 FROM #LeasesAndUnits
													 WHERE OccupiedUnitLeaseGroupID IS NOT NULL
													   AND OccupiedNTVDate IS NOT NULL
													   AND PropertyID = #PortfolioStats.PropertyID)

	UPDATE #PortfolioStats SET NoticeToVacatePreleased = (SELECT COUNT(DISTINCT UnitID)
															  FROM #LeasesAndUnits
															  WHERE OccupiedUnitLeaseGroupID IS NOT NULL
															    AND OccupiedNTVDate IS NOT NULL
																AND PendingUnitLeaseGroupID IS NOT NULL
															    AND PropertyID = #PortfolioStats.PropertyID)

	UPDATE #PortfolioStats SET VacantReady = (SELECT COUNT(DISTINCT #lau.UnitID)
												  FROM #LeasesAndUnits #lau
													  CROSS APPLY GetUnitStatusByUnitID(#lau.UnitID, @date) [UnitStatus]
												  WHERE [UnitStatus].[Status] = 'Ready'
												    AND #lau.OccupiedUnitLeaseGroupID IS NULL
													AND #PortfolioStats.PropertyID = #lau.PropertyID)

	UPDATE #PortfolioStats SET WalkInTraffic = (SELECT COUNT(DISTINCT pn.PersonID)
													FROM PersonNote pn
														INNER JOIN #PropertiesAndDates #pad ON pn.PropertyID = #pad.PropertyID
													WHERE pn.ContactType = 'Face-to-Face'
													  AND pn.[Date] >= #pad.StartDate
													  AND pn.[Date] <= #pad.EndDate
													  AND pn.PersonType = 'Prospect'
													  AND pn.PropertyID = #PortfolioStats.PropertyID)

	CREATE TABLE #NewLeases (
		PropertyID uniqueidentifier not null,
		LeaseID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		LeaseStatus nvarchar(50) null,
		LeasingAgentPersonID uniqueidentifier null)		

	INSERT #NewLeases
		SELECT b.PropertyID,
			   l.LeaseID,
			   ulg.UnitID,  
			   l.LeaseStatus,
			   l.LeasingAgentPersonID
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN #PropertiesAndDates #pids on #pids.PropertyID = b.PropertyID				
			WHERE 		
				-- Make sure we only take into account the first lease in a given unit lease group
				l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)				
				-- Ensure we only get leases that actually applied during the date range
				AND #pids.StartDate <= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)
				AND #pids.EndDate >= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)  			  			  			  
				-- Make sure we don't take into account transferred residents
				AND ulg.PreviousUnitLeaseGroupID IS NULL							  
		  		
		-- Delete cancelled leases where they were auto cancelled
		DELETE #nl
		FROM #NewLeases #nl
			INNER JOIN PersonLease pl ON pl.LeaseID = #nl.LeaseID
			INNER JOIN Property p ON p.PropertyID = #nl.PropertyID
			INNER JOIN PickListItem pli ON pli.PickListItemID = p.DefaultCancelApplicationReasonForLeavingPickListItemID
		WHERE #nl.LeaseStatus = 'Cancelled'
			AND pl.ReasonForLeaving = pli.Name		

	UPDATE #PortfolioStats SET LeasesCurrentWeek = (SELECT COUNT(DISTINCT #nl.LeaseID)
												   FROM #NewLeases #nl
												   WHERE #nl.PropertyID = #PortfolioStats.PropertyID)

	-- Good but use the same logic from RPT_CST_PLP_LeasingStatistics
	----UPDATE #PortfolioStats SET LeasesCurrentWeek = (SELECT COUNT(DISTINCT l.LeaseID)
	----													FROM Lease l
	----														INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
	----														INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	----														INNER JOIN Unit u ON ulg.UnitID = u.UnitID
	----														INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	----														INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
	----														LEFT JOIN PersonLease plNoSkip ON l.LeaseID = pl.LeaseID AND pl.ApplicationDate < #pad.StartDate
	----													WHERE pl.ApplicationDate >= #pad.StartDate 
	----													  AND pl.ApplicationDate <= #pad.EndDate
	----													  AND plNoSkip.PersonLeaseID IS NULL
	----													  AND #pad.PropertyID = #PortfolioStats.PropertyID)

	UPDATE #PortfolioStats SET ActualBilledRent = ISNULL((SELECT SUM(t.Amount)
													FROM [Transaction] t
														INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
														INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
																				AND tt.[Group] IN ('Lease', 'Prospect', 'Non-Resident Account', 'WOIT Account')
																				AND tt.Name = 'Charge'														
													WHERE t.PropertyID = #PortfolioStats.PropertyID
													  AND t.TransactionDate >= #pad.MonthStartDate
													  AND t.TransactionDate <= #pad.EndDate), 0)

	UPDATE #PortfolioStats SET ActualBilledRent = ActualBilledRent - ISNULL((SELECT SUM(Amount)
																			FROM (SELECT DISTINCT p.PaymentID, p.Amount
																					FROM Payment p
																						INNER JOIN [PaymentTransaction] pt ON pt.PaymentID = p.PaymentID
																						INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
																						INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
																						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
																												AND tt.[Group] IN ('Lease', 'Prospect', 'Non-Resident Account', 'WOIT Account')
																												AND tt.Name = 'Credit'
																					WHERE t.PropertyID = #PortfolioStats.PropertyID
																						AND p.[Date] >= #pad.MonthStartDate
																						AND p.[Date] <= #pad.EndDate) AS Credits), 0)

	--UPDATE #PortfolioStats SET ActualBilledRent = ISNULL((SELECT SUM(t.Amount)
	--														  FROM [Transaction] t
	--															  INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID																																		
	--															  INNER JOIN TransactionType tt on tt.TransactionTypeID = t.TransactionTypeID
	--														  WHERE t.TransactionDate >= #pad.MonthStartDate
	--															AND t.TransactionDate <= #pad.EndDate																  
	--															AND t.PropertyID = #PortfolioStats.PropertyID
	--															AND tt.[Group] = 'Lease'
	--															AND tt.Name IN ('Charge')
	--														  GROUP BY t.PropertyID), 0)

	UPDATE #PortfolioStats SET MTDCollected = ISNULL((SELECT SUM(t.Amount)
														FROM [Transaction] t
															INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Deposit' AND tt.[Group] = 'Bank'
															INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
															INNER JOIN Property p ON p.PropertyID = #pad.PropertyID
															INNER JOIN BankTransactionTransaction btt ON t.TransactionID = btt.TransactionID
															INNER JOIN BankTransaction bt ON btt.BankTransactionID = bt.BankTransactionID
															INNER JOIN Batch bat ON bt.BankTransactionID = bat.BankTransactionID
															INNER JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID AND ba.BankAccountID = p.DefaultAPBankAccountID															
														WHERE bat.[Date] >= #pad.MonthStartDate
														  AND bat.[Date] <= #pad.EndDate														  
														  AND t.PropertyID = #PortfolioStats.PropertyID
														GROUP BY t.PropertyID), 0)

	UPDATE #PortfolioStats SET MTDCollected = MTDCollected + (ISNULL( (SELECT SUM(Amount) 
																		   FROM (SELECT DISTINCT py.PaymentID, py.Amount																			
																					FROM Payment py
																						INNER JOIN BankTransaction bt ON py.PaymentID = bt.ObjectID
																						INNER JOIN Batch b ON py.BatchID = b.BatchID
																						INNER JOIN BankTransactionTransaction btt ON b.BankTransactionID = btt.BankTransactionID
																						INNER JOIN [Transaction] t ON btt.TransactionID = t.TransactionID
																						INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID	
																						INNER JOIN Property p ON p.PropertyID = #pad.PropertyID
																						INNER JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID AND ba.BankAccountID = p.DefaultAPBankAccountID			
																					WHERE py.[Type] IN ('NSF', 'Credit Card Recapture')
																					  AND t.PropertyID = #PortfolioStats.PropertyID
																					  AND py.Amount < 0			 
																					  AND py.[Date] >= #pad.MonthStartDate
																					  AND py.[Date] <= #pad.EndDate) Payments), 0))
																					  																
	INSERT #ObjectsForBalances	
		SELECT DISTINCT ObjectID, #pad.PropertyID, null
			FROM [Transaction] t
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = t.PropertyID
			INNER JOIN TransactionType tt ON tt.TransactionTypeID = t.TransactionTypeID
			WHERE TransactionDate <= @date
				AND t.AccountID = @accountID
				AND tt.[Group] IN ('Prospect', 'Non-Resident Account', 'WOIT Account', 'Lease')
			
	INSERT @objectIDs
		SELECT DISTINCT ObjectID
			FROM #ObjectsForBalances
		
	UPDATE #ObjectsForBalances SET Balance = (SELECT [BAL].Balance
												  FROM #ObjectsForBalances #ofb
												      CROSS APPLY GetObjectBalance(null, @date, #ofb.ObjectID, 0, @propertyIDs) [BAL]
												  WHERE #ofb.ObjectID = #ObjectsForBalances.ObjectID
													AND #ofb.PropertyID = #ObjectsForBalances.PropertyID)

	DELETE FROM #ObjectsForBalances WHERE Balance <= 0

	UPDATE #PortfolioStats SET DelinquentAmount = ISNULL((SELECT SUM(Balance)
															  FROM #ObjectsForBalances
															  WHERE PropertyID = #PortfolioStats.PropertyID													
															  GROUP BY PropertyID), 0)
												
	UPDATE #PortfolioStats SET DelinquentCount = (SELECT COUNT(DISTINCT ObjectID)
													  FROM #ObjectsForBalances
													  WHERE PropertyID = #PortfolioStats.PropertyID)

	INSERT #UnpaidInvoices
		EXEC RPT_INV_UnpaidInvoices @propertyIDs, @unPaidInvoicesReportDate, 'AccountingDate', 1, null

	UPDATE #PortfolioStats SET AccountsPayableAmount = (SELECT ISNULL(SUM(Total), 0.00) - ISNULL(SUM(AmountPaid), 0.00)
															FROM #UnpaidInvoices
															WHERE PropertyID = #PortfolioStats.PropertyID)

	UPDATE #PortfolioStats SET PendingWorkOrders = (SELECT COUNT(DISTINCT WorkOrderID)
														FROM WorkOrder
														WHERE [Status] NOT IN ('Completed', 'Cancelled', 'Closed')
														  AND PropertyID = #PortfolioStats.PropertyID
														  AND UnitNoteID IS NULL)

	SELECT * FROM #PortfolioStats 
		ORDER BY PropertyName
END
GO
