SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 11, 2015
-- Description:	Main sproc for Lexington Property Summary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_LEX_PropertySummary] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyIDs GuidCollection READONLY, 
	@date date = null,
	@accountingPeriodID uniqueidentifier = null
	
AS
DECLARE @previousMonthStartDate date
DECLARE @previousMonthEndDate date
DECLARE @currentMonthStartDate date
DECLARE @objectIDs GuidCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #MyProperties (
		PropertyID uniqueidentifier not null)
	
	CREATE TABLE #MyFinalNumbers (
		PropertyID uniqueidentifier not null,
		Property nvarchar(50) null,
		Units int null,
		DownUnits int null,
		NumberOccupied int null,
		PhysicalOccupancyPercent decimal(7, 2) null,
		TotalVacant int null,
		LeasedPercent decimal(7, 2) null,		--WAIT
		ApprovedLeases int null,				--WAIT
		CollectionsPreviousMonth money null,
		CollectionsMTD money null,
		Delinquent money null,
		VacantNotReady int null,
		VacantsMadeReady int null,
		PercentVacantsReady decimal(7, 2) null,
		OpenServiceRequests int null,
		CompServiceRequests int null,
		LeasesExpiringNext30 int null,
		ThirtyDayRenewals int null,
		NTV int null)
		
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
		
	CREATE TABLE #VacantUnits (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitStatus nvarchar(30) null)

	CREATE TABLE #UnitStati (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitStatus nvarchar(30) null)
		
	CREATE TABLE #ObjectsForBalances (
		ObjectID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		Balance money null)
		
	CREATE TABLE #ExpiringLeases (
		LeaseID uniqueidentifier not null,
		NextLeaseID uniqueidentifier null,
		PropertyID uniqueidentifier not null,
		Signed int null)
		
	CREATE TABLE #NewApprovedLeases (
		PropertyID uniqueidentifier not null,
		Unit nvarchar(100) not null,
		LeaseID uniqueidentifier not null,
		ApprovalDate date null)

	INSERT #MyProperties
		SELECT Value FROM @propertyIDs
		
	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @date, @accountingPeriodID, @propertyIDs

	INSERT #MyFinalNumbers
		SELECT Value, Property.Name, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null,			-- 16 nulls here!
									 null, null																									-- 2 more nulls here from task 4834
			FROM @propertyIDs pids
				INNER JOIN Property ON pids.Value = Property.PropertyID

	INSERT #UnitStati
		SELECT #lau.PropertyID, #lau.UnitID, [Stats].[Status]
			FROM #LeasesAndUnits #lau
				INNER JOIN #MyProperties #myP ON #lau.PropertyID = #myP.PropertyID
				CROSS APPLY GetUnitStatusByUnitID(#lau.UnitID, DATEADD(DAY, -1, @date)) [Stats]
				
	SET @currentMonthStartDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @date), 0)
	SET @previousMonthStartDate = DATEADD(month, DATEDIFF(month, 0, @date)-1, 0)
	SET @previousMonthEndDate = DATEADD(DAY, -1, @currentMonthStartDate)

	-- GOOD
	UPDATE #MyFinalNumbers SET Units = (SELECT COUNT(DISTINCT #lau.UnitID) 
											FROM #LeasesAndUnits #lau
												INNER JOIN #UnitStati #us ON #lau.UnitID = #us.UnitID
											WHERE #lau.PropertyID = #MyFinalNumbers.PropertyID
											  AND #us.UnitStatus NOT IN ('Admin', 'Model'))

	-- GOOD										
	UPDATE #MyFinalNumbers SET NumberOccupied = (SELECT COUNT(UnitID)
													FROM #LeasesAndUnits
													WHERE OccupiedUnitLeaseGroupID IS NOT NULL
													  AND PropertyID = #MyFinalNumbers.PropertyID
													GROUP BY PropertyID)
	-- GOOD													
	UPDATE #MyFinalNumbers SET TotalVacant = (SELECT COUNT(UnitID)
												  FROM #LeasesAndUnits
												  WHERE OccupiedUnitLeaseGroupID IS NULL
												    AND PropertyID = #MyFinalNumbers.PropertyID
												  GROUP BY PropertyID)
	-- GOOD												  
	UPDATE #MyFinalNumbers SET NTV = ISNULL((SELECT COUNT(UnitID)
										  FROM #LeasesAndUnits
										  WHERE 
											OccupiedUnitLeaseGroupID IS NOT NULL
											AND OccupiedNTVDate IS NOT NULL
										    AND PropertyID = #MyFinalNumbers.PropertyID
										  GROUP BY PropertyID), 0)
	-- Not Returned, but does it need to be?											  
	UPDATE #MyFinalNumbers SET PhysicalOccupancyPercent = 100.0 * (CAST(NumberOccupied AS DECIMAL(7, 2)) / CAST(Units AS DECIMAL(7, 2)))
		WHERE #MyFinalNumbers.Units <> 0
											

	--UPDATE #MyFinalNumbers SET CollectionsMTD = ISNULL((
	--												SELECT DISTINCT p.PamentID, p.Amount, t.PropertyID
	--												FROM Batch bat
	--													INNER JOIN BankTransaction bt ON bat.BankTransactionID = bt.BankTransactionID
	--													INNER JOIN Payment p ON p.BatchID = bat.BatchID
	--													INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
	--													INNER JOIN [Transaction] t on t.TransactionID = pt.TransactionID														
	--												WHERE bat.[Date] >= @currentMonthStartDate
	--												  AND bat.[Date] <= @date													  
	--												  AND t.PropertyID = #MyFinalNumbers.PropertyID
	--												GROUP BY t.PropertyID), 0)

	UPDATE #MyFinalNumbers SET CollectionsMTD = ISNULL((SELECT SUM(t.Amount)
													FROM [Transaction] t
														INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Deposit' AND tt.[Group] = 'Bank'
														INNER JOIN BankTransactionTransaction btt ON t.TransactionID = btt.TransactionID
														INNER JOIN BankTransaction bt ON btt.BankTransactionID = bt.BankTransactionID
														INNER JOIN Batch bat ON bt.BankTransactionID = bat.BankTransactionID
														INNER JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID AND ba.GLAccountID IN ('342717f2-ff4a-4194-bee7-260fb7e8079f', '2b50234b-e56a-42c4-93fe-c88fac941e51', 'e8c3b9e2-1441-4f53-9dde-deea96b14bbd', 'c2be7ed2-1b87-44f0-a956-1e9a5ae90fc3')
														LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
													WHERE bat.[Date] >= @currentMonthStartDate
													  AND bat.[Date] <= @date
													  AND tr.TransactionID IS NULL
													  AND t.PropertyID = #MyFinalNumbers.PropertyID
													GROUP BY t.PropertyID), 0)
													
	UPDATE #MyFinalNumbers SET CollectionsPreviousMonth = ISNULL((SELECT SUM(t.Amount)
																FROM [Transaction] t
																	INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Deposit' AND tt.[Group] = 'Bank'
																	INNER JOIN BankTransactionTransaction btt ON t.TransactionID = btt.TransactionID
																	INNER JOIN BankTransaction bt ON btt.BankTransactionID = bt.BankTransactionID
																	INNER JOIN Batch bat ON bt.BankTransactionID = bat.BankTransactionID
																	INNER JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID AND ba.GLAccountID IN ('342717f2-ff4a-4194-bee7-260fb7e8079f', '2b50234b-e56a-42c4-93fe-c88fac941e51', 'e8c3b9e2-1441-4f53-9dde-deea96b14bbd', 'c2be7ed2-1b87-44f0-a956-1e9a5ae90fc3')
																	LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
																WHERE bat.[Date] >= @previousMonthStartDate
																  AND bat.[Date] <= @previousMonthEndDate
																  AND tr.TransactionID IS NULL
																  AND t.PropertyID = #MyFinalNumbers.PropertyID
																GROUP BY t.PropertyID), 0)

	-- Remove NSF and CCR.  Payment.Amount will be negative so we add it in here
	UPDATE #MyFinalNumbers SET CollectionsMTD = CollectionsMTD + (ISNULL( (SELECT SUM(Amount) 
																		   FROM (SELECT DISTINCT py.PaymentID, py.Amount																			
																					FROM Payment py
																						INNER JOIN BankTransaction bt ON py.PaymentID = bt.ObjectID
																						INNER JOIN Batch b ON py.BatchID = b.BatchID
																						INNER JOIN BankTransactionTransaction btt ON b.BankTransactionID = btt.BankTransactionID
																						INNER JOIN [Transaction] t ON btt.TransactionID = t.TransactionID	
																						INNER JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID AND ba.GLAccountID IN ('342717f2-ff4a-4194-bee7-260fb7e8079f', '2b50234b-e56a-42c4-93fe-c88fac941e51', 'e8c3b9e2-1441-4f53-9dde-deea96b14bbd', 'c2be7ed2-1b87-44f0-a956-1e9a5ae90fc3')			
																					WHERE py.[Type] IN ('NSF', 'Credit Card Recapture')
																					  AND t.PropertyID = #MyFinalNumbers.PropertyID
																					  AND py.Amount < 0			 
																					  AND py.[Date] >= @currentMonthStartDate
																					  AND py.[Date] <= @date) Payments), 0))

	-- Remove NSF and CCR.  Payment.Amount will be negative so we add it in here
	UPDATE #MyFinalNumbers SET CollectionsPreviousMonth = CollectionsPreviousMonth + (ISNULL( (SELECT SUM(Amount) 
																							   FROM (SELECT DISTINCT py.PaymentID, py.Amount																			
																										FROM Payment py
																											INNER JOIN BankTransaction bt ON py.PaymentID = bt.ObjectID
																											INNER JOIN Batch b ON py.BatchID = b.BatchID
																											INNER JOIN BankTransactionTransaction btt ON b.BankTransactionID = btt.BankTransactionID
																											INNER JOIN [Transaction] t ON btt.TransactionID = t.TransactionID	
																											INNER JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID AND ba.GLAccountID IN ('342717f2-ff4a-4194-bee7-260fb7e8079f', '2b50234b-e56a-42c4-93fe-c88fac941e51', 'c2be7ed2-1b87-44f0-a956-1e9a5ae90fc3')		
																										WHERE py.[Type] IN ('NSF', 'Credit Card Recapture')
																										  AND t.PropertyID = #MyFinalNumbers.PropertyID
																										  AND py.Amount < 0			 
																										  AND py.[Date] >= @previousMonthStartDate
																										  AND py.[Date] <= @previousMonthEndDate) Payments), 0))
			
																
	INSERT #ObjectsForBalances	
		SELECT DISTINCT ObjectID, #p.PropertyID, null
			FROM [Transaction] t
			INNER JOIN #MyProperties #p ON #p.PropertyID = t.PropertyID
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
												  WHERE #ofb.ObjectID = #ObjectsForBalances.ObjectID)

	DELETE FROM #ObjectsForBalances WHERE Balance <= 0

	UPDATE #MyFinalNumbers SET Delinquent = ISNULL((SELECT SUM(Balance)
												FROM #ObjectsForBalances
												WHERE PropertyID = #MyFinalNumbers.PropertyID													
												GROUP BY PropertyID), 0)
												
	INSERT #VacantUnits 
		SELECT PropertyID, UnitID, [UStat].[Status]
			FROM #LeasesAndUnits #lau
				CROSS APPLY GetUnitStatusByUnitID(#lau.UnitID, DATEADD(day, 1, @date)) [UStat]
			WHERE #lau.OccupiedUnitLeaseGroupID IS NULL
			
	UPDATE #MyFinalNumbers SET VacantsMadeReady = ISNULL((SELECT COUNT(UnitID) 
															FROM #VacantUnits #va
															WHERE UnitStatus = 'Ready'
															  AND PropertyID = #MyFinalNumbers.PropertyID
															GROUP BY PropertyID), 0)
															
	UPDATE #MyFinalNumbers SET PercentVacantsReady = 100.0 * (CAST(VacantsMadeReady AS decimal(7, 2))/CAST(TotalVacant AS decimal(7, 2)))
		WHERE TotalVacant <> 0

	UPDATE #MyFinalNumbers SET OpenServiceRequests = ISNULL((SELECT COUNT(*)
																FROM WorkOrder
																WHERE PropertyID = #MyFinalNumbers.PropertyID
																  AND ReportedDate < DATEADD(Day, 1, @date)																  
																  AND UnitNoteID IS NULL					-- Don't include MakeReady WorkOrders
																  AND ((CompletedDate IS NULL AND CancellationDate IS NULL AND [Status] NOT IN ('Completed', 'Cancelled', 'Closed')) OR (CompletedDate > DATEADD(Day, 1, @date)	) OR (CancellationDate > DATEADD(Day, 1, @date)	))), 0)
																  
	UPDATE #MyFinalNumbers SET CompServiceRequests = ISNULL((SELECT COUNT(*)
																FROM WorkOrder
																WHERE PropertyID = #MyFinalNumbers.PropertyID
																  AND CompletedDate >= @currentMonthStartDate
																  AND UnitNoteID IS NULL					-- Don't include MakeReady WorkOrders
																  AND CompletedDate <= DATEADD(Day, 1, @date)), 0)
												
	INSERT #ExpiringLeases 
		SELECT l.LeaseID, null, #lau.PropertyID, 0
			FROM #LeasesAndUnits #lau
				INNER JOIN Lease l ON #lau.OccupiedUnitLeaseGroupID = l.UnitLeaseGroupID
			WHERE l.LeaseEndDate >= @date
			  AND l.LeaseEndDate <= DATEADD(DAY, 30, @date)
			  AND l.LeaseStatus IN ('Current', 'Under Eviction')--, 'Former', 'Evicted', 'Renewed')

	-- Get the next lease for the UnitLeaseGroup.  
	-- cl = Expiring Current Lease
	-- nl = Next Lease in order of LeaseEndDate.  The INNER JOIN Binds nl to ANY Lease which expires after the current.  The TOP 1 binds it to the first of those EndDates	  
	UPDATE #ExpiringLeases SET NextLeaseID = (SELECT nl.LeaseID
												  FROM Lease cl
												      INNER JOIN Lease nl ON cl.UnitLeaseGroupID = nl.UnitLeaseGroupID AND cl.LeaseEndDate < nl.LeaseEndDate AND cl.DateCreated <= nl.DateCreated
												  WHERE nl.LeaseID = (SELECT TOP 1 LeaseID 
																		  FROM Lease l
																		  WHERE UnitLeaseGroupID = nl.UnitLeaseGroupID
																		    AND l.UnitLeaseGroupID = cl.UnitLeaseGroupID
																		    AND cl.LeaseID = #ExpiringLeases.LeaseID
																		    AND l.LeaseEndDate > cl.LeaseEndDate
																		    AND l.LeaseStatus NOT IN ('Denied', 'Cancelled')
																		  ORDER BY LeaseEndDate))
																	  
	UPDATE #ExpiringLeases SET Signed = (SELECT COUNT(*)
											FROM PersonLease
											WHERE LeaseSignedDate <= @date
											  AND LeaseID = #ExpiringLeases.NextLeaseID)
																		  
	UPDATE #MyFinalNumbers SET LeasesExpiringNext30 = ISNULL((SELECT COUNT(*)
																  FROM #ExpiringLeases
																  WHERE LeaseID IS NOT NULL
																    AND PropertyID = #MyFinalNumbers.PropertyID
																  GROUP BY PropertyID), 0)
												
	UPDATE #MyFinalNumbers SET ThirtyDayRenewals = ISNULL((SELECT COUNT(*) 
															  FROM #ExpiringLeases
															  WHERE NextLeaseID IS NOT NULL
															    AND Signed > 0
															    AND PropertyID = #MyFinalNumbers.PropertyID
															  GROUP BY PropertyID), 0)
			
	INSERT #NewApprovedLeases
		SELECT PropertyID, UnitNumber, PendingLeaseID, null
		FROM #LeasesAndUnits
		WHERE PendingLeaseID IS NOT NULL
				
	UPDATE #NewApprovedLeases SET ApprovalDate = (SELECT TOP 1 pn.[Date] 
													FROM PersonLease pl
													INNER JOIN PersonNote pn ON pn.PersonID = pl.PersonID
													WHERE pl.LeaseID = #NewApprovedLeases.LeaseID
														AND pn.PropertyID = #NewApprovedLeases.PropertyID
														AND pn.InteractionType = 'Approved'
														AND pl.ApprovalStatus = 'Approved'
														--AND pn.Location = #NewApprovedLeases.Unit
													ORDER BY pn.[Date], pn.DateCreated)															 	
			
	UPDATE #MyFinalNumbers SET ApprovedLeases = ISNULL((SELECT COUNT(#nal.LeaseID)
															FROM #NewApprovedLeases #nal
															WHERE #nal.PropertyID  = #MyFinalNumbers.PropertyID
																AND #nal.ApprovalDate IS NOT NULL
																AND #nal.ApprovalDate <= @date
															GROUP BY #nal.PropertyID), 0)
															
	-- NOT RETURNED												
	--UPDATE #MyFinalNumbers SET LeasedPercent = ISNULL((CAST(ApprovedLeases AS decimal(7, 2)) + CAST(NumberOccupied AS decimal(7, 2)) - CAST(NTV AS decimal(7, 2)))
	--													/ (CAST(Units AS decimal(7, 2))), 0.00)

	UPDATE #MyFinalNumbers SET DownUnits = (SELECT COUNT(DISTINCT #vu.UnitID)
												FROM #VacantUnits #vu
												WHERE #vu.UnitStatus IN ('Down')
												  AND #vu.PropertyID = #MyFinalNumbers.PropertyID)

	SELECT 
		PropertyID,
		Property AS 'PropertyName',
		ISNULL(Units, 0) AS 'TotalUnits',
		ISNULL(DownUnits, 0) AS 'DownUnits',
		ISNULL(NumberOccupied, 0) AS 'OccupiedUnits',
		ISNULL(TotalVacant, 0) AS 'VacantUnits',
		ISNULL(ApprovedLeases, 0) AS 'ApprovedLeases',
		ISNULL(CollectionsPreviousMonth, 0)  AS 'PreviousMonthTotalCollected',
		ISNULL(CollectionsMTD, 0) AS 'CollectedMTD',
		ISNULL(Delinquent, 0) AS 'Delinquent',
		ISNULL(VacantsMadeReady, 0) AS 'VacantReady',
		ISNULL(OpenServiceRequests, 0) AS 'OutstandingWorkOrders',
		ISNULL(CompServiceRequests, 0) AS 'CompletedWorkOrders',
		ISNULL(LeasesExpiringNext30, 0) AS 'ExpiringLeases',
		ISNULL(ThirtyDayRenewals, 0) AS 'RenewedLeases',
		ISNULL(NTV, 0) AS 'NoticeToVacate'
		FROM #MyFinalNumbers
	
END
GO
