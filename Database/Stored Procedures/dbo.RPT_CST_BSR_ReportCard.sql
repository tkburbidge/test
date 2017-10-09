SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 24, 2016
-- Description:	Gets occupancy and unit information based unittypes and number of bedrooms
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_BSR_ReportCard] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS

DECLARE @objectIDs GuidCollection
DECLARE @accountID bigint
DECLARE @accountingPeriodID uniqueidentifier
DECLARE @i int = 1
DECLARE @maxI int = 13
DECLARE @endDate date

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyInformation (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(100) not null,
		RegionalManagerID uniqueidentifier null,
		RegionalManagerName nvarchar(100) null,
		ManagerID uniqueidentifier null,
		ManagerName nvarchar(100) null,
		DelinquencyUnder500Count int null,
		DelinquencyOver500Count int null,
		DelinquencyUnder500Sum int null,
		DelinquencyOver500Sum int null,
		APBalance money null)

	CREATE TABLE #UnitStatsByBedroom (
		PropertyID uniqueidentifier not null,
		Bedrooms int null,
		UnitCount int null,
		GrossPotentialRent money null,								-- GetMarketRentByDate for each unit on @date
		AveragePerUnit money null,									-- GrossPotentialRent / UnitCount
		DownCount int null,											-- Unit Status = Down on @date
		VacantCount int null,										-- Count of OccupiedUnitLeaseGroupID is null
		VacantCost int null,										-- Sum of market rent for vacant units (no OccupiedUnitLeaseGroupID)
		ReadyCount int null,										-- Vacant units with status of ready
		OccupiedCount int null,										-- OccupiedUnitLeaseGroupID has a value
		OccupiedValue int null,										-- GrossPotentialRent - VacantCost
		ApplicationCount int null,									-- Number of applications submitted for @date - 7 to @date (see box score)
		ApprovalCount int null,										-- Number of approvals submitted for @date - 7 to @date (see box score)
		FutureMoveInCount int null,									-- PendingUnitLeaseGroupID is not null
		LeasedUnits int null,										-- OccupiedCount + FutureMoveInCount
		ThirtyDayNotice int null,									-- Number of OccupiedUnitLeasGroupID with a move out date within @date + 30
		LeasedLessNotice int null,									-- =  LeasedUnits - ThirtyDayNotice
		OnlineApplicationCount int null								-- Online Application Count
		)

	CREATE TABLE #BoxScoreStats (
		PropertyID uniqueidentifier not null,
		WeekEndDate date null,
		UnitCount int null,
		EmailAndCalls int null,										-- Sum of distinct prospect contacts during week date range where interaction type is email or phone
		Traffic int null,											-- RPT_CST_BSR_BoxScoreOccupancy.Traffic
		Applied int null,											-- RPT_CST_BSR_BoxScoreOccupancy.Applied
		Approved int null,											-- RPT_CST_BSR_BoxScoreOccupancy.Approved
		Cancelled int null,											-- Number of first time leases that cancelled that week
		Denied int null,											-- RPT_CST_BSR_BoxScoreOccupancy.Denied
		MoveIns int null,											-- RPT_CST_BSR_BoxScoreOccupancy.MoveIns
		MoveOuts int null,											-- RPT_CST_BSR_BoxScoreOccupancy.MoveOuts
		NetMoveIns int null,										-- = MoveIns - MoveOuts
		TenantVacancy int null,										-- GetConsolidatedOccupancyNumbers at the end of each week
		OccupiedUnits int null,										-- GetConsolidatedOccupancyNumbers at the end of each week
		OccupiedPercent decimal null								-- GetConsolidatedOccupancyNumbers at the end of each week 
		)		

	CREATE TABLE #FinancialStats (
		PropertyID uniqueidentifier null,
		AccountingPeriodEndDate date null,
		IncomeActual money null,									-- GL Account Rage 5110-5990
		IncomeBudget money null,									-- Same but budget
		ControllableExpenseActual money null,						-- 6110 - 6691
		ControllableExpenseBudget money null,						-- Same but budget
		NonControllableExpenseActual money null,					-- 6700 - 6750
		NonControllableExpenseBudget money null,					-- Same but budget
		RegularCapitalImprovementsActual money null,				-- 1401, 1411, 1421, 1431, 1441, 1446, 1451, 1461, 1465, 1470, 1480, 1485, 1490
		RegularCapitalImprovementsBudget money null,				-- Same but budget
		NOIGenActual money null,									-- 1404, 1414, 1424, 1434, 1444, 1449, 1454, 1464
		NOIGenBudget money null,									-- Same but budget
		BadDebtActual money null,									-- 6320
		BadDebtBudget money null									-- Same but budget
		)

	CREATE TABLE #PaymentStats (
--Return two rows for this month and last month
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(100) null,
		AccountingPeriodEndDate date null,							-- Accounting Period End Date
		MonthPart int null,
		TotalCharges money null,									-- Lease, Prospect, Non-Resident, WOIT Account charges for the month to date
		TotalCredits money null,									-- Same as above but credits
		PaymentsBy6 money null,										-- Sum of Lease, Prospect, Non-Resident, WOIT Account Payment records from 1st to 6th. TransactionType.Name = Payment, Group is Lease, etc and LedgerItemType.IsPayment = 1
		PaymentsBy10 money null,
		PaymentsBy15 money null,
		PaymentsBy20 money null,
		PaymentsBy25 money null,
		PaymentsByEndOfMonth money null)

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

	CREATE TABLE #ConsolodatedNumbers (						-- Exact same as #LeasesAndUnits, but we alter the #LeasesAndUnits in the sproc, so we can't reuse it.
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
		PrevMonthStartDate date null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #BoxScoreDates (
		[Sequence] int identity,
		WeekStartDate date null,
		WeekEndDate date null)

	CREATE TABLE #PropertiesAndDatesForBoxScore (
		[Sequence] int null,
		PropertyID uniqueidentifier null,
		WeekStartDate date null,
		WeekEndDate date null)

	CREATE TABLE #GLAccountInts (
		GLAccountID uniqueidentifier not null,
		GLNumber nvarchar(50) null,
		GLInt int null)

	CREATE TABLE #AccountingPeriods (
		[Sequence] int identity,
		AccountingPeriodID uniqueidentifier null,
		EndDate date null
		)

	CREATE TABLE #PropertiesAndAccountingPeriods (
		[Sequence] int null,
		PropertyID uniqueidentifier null,
		AccountingPeriodID uniqueidentifier null,
		APStartDate date null,
		APEndDate date null
		)

	INSERT #PropertiesAndDates
		SELECT Value, DATEADD(month, DATEDIFF(month, 0, @date), 0), null, DATEADD(DAY, -7, @date), @date
			FROM @propertyIDs

	UPDATE #PropertiesAndDates SET PrevMonthStartDate = DATEADD(MONTH, -1, MonthStartDate)

	SET @accountID = (SELECT TOP 1 prop.AccountID
						  FROM #PropertiesAndDates #pad
							  INNER JOIN Property prop ON #pad.PropertyID = prop.PropertyID)

	WHILE (@i <= @maxI)
	BEGIN
		IF (@i = 1)
		BEGIN
			INSERT #BoxScoreDates
				SELECT DATEADD(DAY, -6, @date), @date
		END
		ELSE
		BEGIN
			INSERT #BoxScoreDates
				SELECT DATEADD(DAY, ((-@i + 1) * 7) - 6, @date), DATEADD(DAY, (((-@i + 1) * 7)), @date)
		END
		
		SET @i = @i + 1		
	END

	INSERT #AccountingPeriods
		SELECT TOP 6 AccountingPeriodID, EndDate
			FROM AccountingPeriod
			WHERE AccountID = @accountID
				AND EndDate <= (SELECT EndDate
											FROM AccountingPeriod
											WHERE @date >= StartDate
												AND @date <= EndDate
												AND @accountID = AccountID)
			ORDER BY EndDate DESC

	INSERT #PropertiesAndAccountingPeriods
		SELECT	#ap.[Sequence], #pad.PropertyID, ap.AccountingPeriodID, COALESCE(pap.StartDate, ap.StartDate), COALESCE(pap.EndDate, ap.EndDate)
			FROM #AccountingPeriods #ap
				INNER JOIN AccountingPeriod ap ON #ap.AccountingPeriodID = ap.AccountingPeriodID
				INNER JOIN #PropertiesAndDates #pad ON 1=1
				LEFT JOIN PropertyAccountingPeriod pap ON ap.AccountingPeriodID = pap.AccountingPeriodID AND #pad.PropertyID = pap.PropertyID

	INSERT #PropertiesAndDatesForBoxScore 
		SELECT #bsd.[Sequence], #pad.PropertyID, #bsd.WeekStartDate, #bsd.WeekEndDate
			FROM #BoxScoreDates #bsd
				INNER JOIN #PropertiesAndDates #pad ON 1=1

	INSERT #FinancialStats
		SELECT #pad.PropertyID, #aps.EndDate, null, null, null, null, null, null, null, null, null, null, null, null				-- 12 nulls
			FROM #PropertiesAndDates #pad
				INNER JOIN #AccountingPeriods #aps ON 1=1

	INSERT #PaymentStats
		SELECT	#pad.PropertyID, prop.Name, #aps.EndDate, DATEPART(MONTH, #aps.EndDate), null, null, null, null, null, null, null, null
			FROM #PropertiesAndDates #pad
				INNER JOIN Property prop ON #pad.PropertyID = prop.PropertyID
				INNER JOIN #AccountingPeriods #aps ON #aps.[Sequence] IN (1, 2)

--select * from #BoxScoreDates order by [Sequence]
--select * from #PropertiesAndDatesForBoxScore order by [Sequence]

	INSERT #GLAccountInts
		SELECT	GLAccountID, Number, CAST(Number AS int)
			FROM GLAccount
			WHERE AccountID = @accountID

--select * from #GLAccountInts order by GLInt

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @date, @accountingPeriodID, @propertyIDs	

	ALTER TABLE #LeasesAndUnits ADD UnitTypeID uniqueidentifier NULL
	ALTER TABLE #LeasesAndUnits ADD Bedrooms int NULL
	ALTER TABLE #LeasesAndUnits ADD MarketRent money NULL
	ALTER TABLE #LeasesAndUnits ADD UStatus nvarchar(100) NULL

	UPDATE #lau	SET UnitTypeID = ut.UnitTypeID, Bedrooms = ut.Bedrooms
		FROM #LeasesAndUnits #lau
			INNER JOIN Unit u ON #lau.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID

	UPDATE #lau SET MarketRent = [MarkRent].Amount
		FROM #LeasesAndUnits #lau
			CROSS APPLY dbo.GetMarketRentByDate(#lau.UnitID, @date, 1) [MarkRent]

	UPDATE #lau SET UStatus = [UStat].[Status]
		FROM #LeasesAndUnits #lau
			CROSS APPLY dbo.GetUnitStatusByUnitID(#lau.UnitID, @date) [UStat]

--select * from #LeasesAndUnits
																					  																
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
												  WHERE #ofb.ObjectID = #ObjectsForBalances.ObjectID)

	DELETE FROM #ObjectsForBalances WHERE Balance <= 0

	INSERT #PropertyInformation
		SELECT prop.PropertyID, prop.Name, prop.RegionalManagerPersonID, RegPer.PreferredName + ' ' + RegPer.LastName, PropPer.PersonID,
			   propPer.PreferredName + ' ' + propPer.LastName, null, null, null, null, null
			FROM #PropertiesAndDates #pad
				INNER JOIN Property prop ON #pad.PropertyID = prop.PropertyID
				LEFT JOIN Person RegPer ON prop.RegionalManagerPersonID = RegPer.PersonID
				LEFT JOIN Person PropPer ON prop.ManagerPersonID = PropPer.PersonID

	INSERT #UnitStatsByBedroom
		SELECT DISTINCT PropertyID, Bedrooms, 
						null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null				-- 16 nulls
			FROM #LeasesAndUnits

	INSERT #UnpaidInvoices
		EXEC RPT_INV_UnpaidInvoices @propertyIDs, @date, 'AccountingDate', 1, null

	UPDATE #UnitStatsByBedroom SET UnitCount = (SELECT COUNT(DISTINCT UnitID)
													FROM #LeasesAndUnits
													WHERE PropertyID = #UnitStatsByBedroom.PropertyID
													  AND Bedrooms = #UnitStatsByBedroom.Bedrooms)

	UPDATE #UnitStatsByBedroom SET GrossPotentialRent = (SELECT SUM(MarketRent)
															 FROM #LeasesAndUnits 
															 WHERE PropertyID = #UnitStatsByBedroom.PropertyID
															   AND Bedrooms = #UnitStatsByBedroom.Bedrooms)

	UPDATE #UnitStatsByBedroom SET AveragePerUnit = GrossPotentialRent / CAST(UnitCount AS money)
		WHERE UnitCount > 0

	UPDATE #UnitStatsByBedroom SET DownCount = (SELECT COUNT(DISTINCT UnitID)
													FROM #LeasesAndUnits
													WHERE PropertyID = #UnitStatsByBedroom.PropertyID
													  AND Bedrooms = #UnitStatsByBedroom.Bedrooms
													  AND UStatus = 'Down')

	UPDATE #UnitStatsByBedroom SET VacantCount = (SELECT COUNT(DISTINCT UnitID)
													FROM #LeasesAndUnits
													WHERE PropertyID = #UnitStatsByBedroom.PropertyID
													  AND Bedrooms = #UnitStatsByBedroom.Bedrooms
													  AND OccupiedUnitLeaseGroupID IS NULL)

	UPDATE #UnitStatsByBedroom SET VacantCost = (SELECT SUM(MarketRent)
													FROM #LeasesAndUnits 
													WHERE PropertyID = #UnitStatsByBedroom.PropertyID
													  AND Bedrooms = #UnitStatsByBedroom.Bedrooms
													  AND OccupiedUnitLeaseGroupID IS NULL)

	UPDATE #UnitStatsByBedroom SET ReadyCount = (SELECT COUNT(DISTINCT UnitID)
													FROM #LeasesAndUnits
													WHERE PropertyID = #UnitStatsByBedroom.PropertyID
													  AND Bedrooms = #UnitStatsByBedroom.Bedrooms
													  AND OccupiedUnitLeaseGroupID IS NULL
													  AND UStatus = 'Ready')

	UPDATE #UnitStatsByBedroom SET OccupiedCount = (SELECT COUNT(DISTINCT UnitID)
														FROM #LeasesAndUnits
														WHERE PropertyID = #UnitStatsByBedroom.PropertyID
														  AND Bedrooms = #UnitStatsByBedroom.Bedrooms
														  AND OccupiedUnitLeaseGroupID IS NOT NULL)

	UPDATE #UnitStatsByBedroom SET OccupiedValue = GrossPotentialRent - VacantCost

	UPDATE #UnitStatsByBedroom SET FutureMoveInCount = (SELECT COUNT(DISTINCT UnitID)
															FROM #LeasesAndUnits
															WHERE PropertyID = #UnitStatsByBedroom.PropertyID
															  AND Bedrooms = #UnitStatsByBedroom.Bedrooms
															  AND PendingUnitLeaseGroupID IS NOT NULL)

	UPDATE #UnitStatsByBedroom SET LeasedUnits = OccupiedCount + FutureMoveInCount

	UPDATE #UnitStatsByBedroom SET ThirtyDayNotice = (SELECT COUNT(DISTINCT UnitID)
														  FROM #LeasesAndUnits
														  WHERE PropertyID = #UnitStatsByBedroom.PropertyID
														    AND Bedrooms = #UnitStatsByBedroom.Bedrooms
														    AND OccupiedUnitLeaseGroupID IS NOT NULL
															AND OccupiedMoveOutDate > @date
															AND OccupiedMoveOutDate <= DATEADD(DAY, 30, @date))

	UPDATE #UnitStatsByBedroom SET LeasedLessNotice = LeasedUnits - ThirtyDayNotice

	CREATE TABLE #LeaseApplications ( LeaseID uniqueidentifier, PropertyID uniqueidentifier, AppliedOnline bit, BedroomCount int )

	INSERT INTO #LeaseApplications
		SELECT DISTINCT l.LeaseID, #pad.PropertyID, 0, ut.Bedrooms
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
								--AND #pad.PropertyID = #UnitStatsByBedroom.PropertyID
								--AND ut.Bedrooms = #UnitStatsByBedroom.Bedrooms
	UPDATE #LeaseApplications SET AppliedOnline = (SELECT ISNULL((SELECT TOP 1
													ai.OriginatedOnline
												FROM ApplicantInformation ai
													INNER JOIN ApplicantInformationPerson aip ON aip.ApplicantInformationID = ai.ApplicantInformationID
													INNER JOIN PersonLease pl ON pl.PersonID = aip.PersonID
													INNER JOIN Lease l ON l.LeaseID = #LeaseApplications.LeaseID AND pl.LeaseID = l.LeaseID
													-- Someone on the lease applied online within seveb days of the 
													-- lease being created and the application being created
												WHERE ABS(DATEDIFF(day, ai.DateCreated, l.DateCreated)) <= 7), 0))

	UPDATE #UnitStatsByBedroom SET ApplicationCount = (SELECT COUNT(DISTINCT l.LeaseID)
														FROM #LeaseApplications l
														WHERE l.PropertyID = #UnitStatsByBedroom.PropertyID
															 AND l.BedroomCount = #UnitStatsByBedroom.Bedrooms)

	UPDATE #UnitStatsByBedroom SET ApprovalCount = (SELECT COUNT(DISTINCT #lau.PendingUnitLeaseGroupID)
														FROM #LeasesAndUnits #lau
															INNER JOIN Lease l ON #lau.PendingUnitLeaseGroupID = l.UnitLeaseGroupID
															INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ApprovalStatus IN ('Approved')
														WHERE #UnitStatsByBedroom.PropertyID = #lau.PropertyID
														  AND #UnitStatsByBedroom.Bedrooms = #lau.Bedrooms)




	UPDATE #UnitStatsByBedroom SET OnlineApplicationCount = (SELECT COUNT(DISTINCT l.LeaseID)
														FROM #LeaseApplications l
														WHERE l.PropertyID = #UnitStatsByBedroom.PropertyID
															 AND l.BedroomCount = #UnitStatsByBedroom.Bedrooms
															 AND l.AppliedOnline = 1)	
--select * from #UnitStatsByBedroom

	UPDATE #PropertyInformation SET DelinquencyUnder500Sum = ISNULL((SELECT SUM(Balance)
															   FROM #ObjectsForBalances
															   WHERE Balance < 500.00
															     AND PropertyID = #PropertyInformation.PropertyID), 0)

	UPDATE #PropertyInformation SET DelinquencyOver500Sum = ISNULL((SELECT SUM(Balance)
															  FROM #ObjectsForBalances
															  WHERE Balance >= 500.00
															    AND PropertyID = #PropertyInformation.PropertyID), 0)

	UPDATE #PropertyInformation SET DelinquencyUnder500Count = ISNULL((SELECT COUNT(DISTINCT ObjectID)
															   FROM #ObjectsForBalances
															   WHERE Balance < 500.00
															     AND PropertyID = #PropertyInformation.PropertyID), 0)

	UPDATE #PropertyInformation SET DelinquencyOver500Count = ISNULL((SELECT COUNT(DISTINCT ObjectID)
															  FROM #ObjectsForBalances
															  WHERE Balance >= 500.00
															    AND PropertyID = #PropertyInformation.PropertyID), 0)

	UPDATE #PropertyInformation SET APBalance = ISNULL((SELECT ISNULL(SUM(Total), 0.00) - ISNULL(SUM(AmountPaid), 0.00)
															FROM #UnpaidInvoices
															WHERE PropertyID = #PropertyInformation.PropertyID), 0)

	UPDATE #PropertyInformation SET APBalance = ISNULL(ISNULL(APBalance, 0) + (SELECT ISNULL(SUM(p.Amount), 0)
																			FROM Payment p
																				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
																				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
																				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID																				
																				LEFT JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
																				LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
																				LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
																				LEFT JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID	
																			WHERE tt.Name in ('Deposit Refund', 'Payment Refund')
																				AND tt.[Group] in ('Lease', 'Non-Resident Account', 'Prospect', 'WOIT Account')																				
																				AND p.[Date] <= @date
																				AND t.PropertyID = #PropertyInformation.PropertyID
																				AND tr.TransactionID IS NULL
																				AND t.ReversesTransactionID IS NULL																							
																				AND ((ta.TransactionID IS NULL) OR (ta.TransactionDate > @date) OR
																					(((SELECT COUNT(transactionID) from [Transaction] ta1 where ta1.AppliesToTransactionID = t.TransactionID and ta1.TransactionDate <= @date) =
																					 (SELECT COUNT(transactionID) from [Transaction] tr1 where tr1.TransactionDate <= @date and tr1.ReversesTransactionID in (SELECT transactionID
																													FROM [Transaction] tr2 where tr2.AppliesToTransactionID = t.TransactionID)))))), 0)																
-- Now, populate #BoxScoreStats

	INSERT #BoxScoreStats
		SELECT PropertyID, WeekEndDate, null, null, null, null, null, null, null, null, null, null, null, null, null
			FROM #PropertiesAndDatesForBoxScore

	UPDATE #BoxScoreStats SET UnitCount = (SELECT COUNT(DISTINCT UnitID)
											   FROM #LeasesAndUnits
											   WHERE #BoxScoreStats.PropertyID = PropertyID)

	-- Good1
	UPDATE #BoxScoreStats SET EmailAndCalls = (SELECT COUNT(pn.PersonNoteID)
												   FROM PersonNote pn
														INNER JOIN Prospect p ON p.PersonID = pn.PersonID
														INNER JOIN PersonType pt ON pn.CreatedByPersonID = pt.PersonID AND pt.[Type] IN ('Employee', 'Prospect')
														INNER JOIN #PropertiesAndDatesForBoxScore #bspad ON pn.PropertyID = #bspad.PropertyID
													WHERE pn.ContactType IN ('Email', 'Phone')
													  AND pn.PersonType = 'Prospect'
													  AND pn.[Date] >= #bspad.WeekStartDate 
													  AND pn.[Date] <= #bspad.WeekEndDate
													  AND pn.PropertyID = #BoxScoreStats.PropertyID
													  AND #bspad.WeekEndDate = #BoxScoreStats.WeekEndDate)
	
	-- Good1
	UPDATE #BoxScoreStats SET Traffic = (SELECT COUNT(DISTINCT pros.ProspectID)
										     FROM Prospect pros
											     INNER JOIN PersonNote pn ON pros.FirstPersonNoteID = pn.PersonNoteID
											     INNER JOIN #PropertiesAndDatesForBoxScore #bspad ON pn.PropertyID = #bspad.PropertyID 
																										AND pn.[Date] >= #bspad.WeekStartDate AND pn.[Date] <= #bspad.WeekEndDate
										     WHERE #bspad.PropertyID = #BoxScoreStats.PropertyID
											   AND #bspad.WeekEndDate = #BoxScoreStats.WeekEndDate)
	
	-- Good1
	UPDATE #BoxScoreStats SET Applied = (SELECT COUNT(DISTINCT l.LeaseID)
										     FROM Lease l
											     INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
											     INNER JOIN Unit u ON ulg.UnitID = u.UnitID
											     INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
											     INNER JOIN #PropertiesAndDatesForBoxScore #bspad ON ut.PropertyID = #bspad.PropertyID
											     INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID 
																				AND pl.ApplicationDate >= #bspad.WeekStartDate AND pl.ApplicationDate <= #bspad.WeekEndDate											     
										     WHERE pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																		   FROM PersonLease
																		   WHERE LeaseID = l.LeaseID
																		   ORDER BY ApplicationDate)
											   AND #bspad.PropertyID = #BoxScoreStats.PropertyID
											   AND #bspad.WeekEndDate = #BoxScoreStats.WeekEndDate
											   AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
																   FROM Lease l2
																   WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																   ORDER BY l2.LeaseStartDate))


	UPDATE #BoxScoreStats SET Approved = (SELECT COUNT(DISTINCT ulg.UnitLeaseGroupID)
											  FROM UnitLeaseGroup ulg
												  INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
												  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ApprovalStatus = 'Approved'
												  INNER JOIN PersonNote pn ON pl.PersonID = pn.PersonID
												  INNER JOIN #PropertiesAndDatesForBoxScore #bspad ON pn.PropertyID = #bspad.PropertyID
																					AND pn.[Date] >= #bspad.WeekStartDate AND pn.[Date] <= #bspad.WeekEndDate
																					AND pn.InteractionType = 'Approved'
																					AND pn.DateCreated > l.DateCreated
												  LEFT JOIN (SELECT	pl1.LeaseID, pn1.PersonNoteID, pn1.[Date], pn1.DateCreated
																 FROM PersonLease pl1
																	 INNER JOIN PersonNote pn1 ON pl1.PersonID = pn1.PersonID
																 WHERE pn1.InteractionType = 'Approved') [pnPrior] ON pnPrior.LeaseID = l.LeaseID
																															AND pnPrior.[Date] < #bspad.WeekStartDate 
																															AND pnPrior.DateCreated > l.DateCreated
												WHERE #bspad.PropertyID = #BoxScoreStats.PropertyID
												  AND #bspad.WeekEndDate = #BoxScoreStats.WeekEndDate
												  AND pnPrior.PersonNoteID IS NULL
												   AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
																   FROM Lease l2
																   WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																   ORDER BY l2.LeaseStartDate))

	-- Good1													
	UPDATE #BoxScoreStats SET Cancelled = (SELECT COUNT(DISTINCT l.LeaseID)
										  FROM Lease l
											  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
											  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
											  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
											  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
											  INNER JOIN #PropertiesAndDatesForBoxScore #bspad ON ut.PropertyID = #bspad.PropertyID
											  LEFT JOIN PersonLease plMONull ON l.LeaseID = plMONull.LeaseID AND plMONull.MoveOutDate > #bspad.WeekEndDate
										  WHERE (pl.MoveOutDate >= #bspad.WeekStartDate AND pl.MoveOutDate <= #bspad.WeekEndDate)
											AND l.LeaseStatus IN ('Cancelled')											
											AND plMONull.PersonLeaseID IS NULL
										    AND #bspad.PropertyID = #BoxScoreStats.PropertyID
											AND #bspad.WeekEndDate = #BoxScoreStats.WeekEndDate
											 AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
																   FROM Lease l2
																   WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																   ORDER BY l2.LeaseStartDate))
	
	-- Good1
	UPDATE #BoxScoreStats SET Denied = (SELECT COUNT(DISTINCT l.LeaseID)
										  FROM Lease l
											  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
											  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
											  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
											  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
											  INNER JOIN #PropertiesAndDatesForBoxScore #bspad ON ut.PropertyID = #bspad.PropertyID
											  LEFT JOIN PersonLease plMONull ON l.LeaseID = plMONull.LeaseID AND plMONull.MoveOutDate > #bspad.WeekEndDate
										  WHERE (pl.MoveOutDate >= #bspad.WeekStartDate AND pl.MoveOutDate <= #bspad.WeekEndDate)
											AND l.LeaseStatus IN ('Denied')											
											AND plMONull.PersonLeaseID IS NULL
										    AND #bspad.PropertyID = #BoxScoreStats.PropertyID
											AND #bspad.WeekEndDate = #BoxScoreStats.WeekEndDate
											 AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
																   FROM Lease l2
																   WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																   ORDER BY l2.LeaseStartDate))				
	-- Good1
	UPDATE #BoxScoreStats SET MoveIns = (SELECT COUNT(DISTINCT ulg.UnitLeaseGroupID)
											  FROM UnitLeaseGroup ulg
												  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
												  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
												  INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
												  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
												  INNER JOIN #PropertiesAndDatesForBoxScore #bspad ON ut.PropertyID = #bspad.PropertyID
																					AND pl.MoveInDate >= #bspad.WeekStartDate AND pl.MoveInDate <= #bspad.WeekEndDate
												  LEFT JOIN (SELECT	pl1.LeaseID, pl1.PersonLeaseID, pl1.MoveInDate
																 FROM PersonLease pl1) [plPrior] ON plPrior.LeaseID = l.LeaseID
																					AND plPrior.MoveInDate < #bspad.WeekStartDate 
												  LEFT JOIN Lease lPrior ON ulg.UnitLeaseGroupID = lPrior.UnitLeaseGroupID
																					AND lPrior.LeaseStartDate < l.LeaseStartDate
												WHERE #bspad.PropertyID = #BoxScoreStats.PropertyID
												  AND #bspad.WeekEndDate = #BoxScoreStats.WeekEndDate
												  AND plPrior.PersonLeaseID IS NULL
												  AND lPrior.LeaseID IS NULL
												  AND l.LeaseStatus NOT IN ('Pending Approval', 'Pending Transfer', 'Pending Renewal', 'Cancelled', 'Denied'))

	-- Good1	
	UPDATE #BoxScoreStats SET MoveOuts = (SELECT COUNT(DISTINCT ulg.UnitLeaseGroupID)
											  FROM UnitLeaseGroup ulg
												  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
												  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
												  INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
												  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
												  INNER JOIN #PropertiesAndDatesForBoxScore #bspad ON ut.PropertyID = #bspad.PropertyID
																					AND pl.MoveOutDate >= #bspad.WeekStartDate AND pl.MoveOutDate <= #bspad.WeekEndDate
												  LEFT JOIN (SELECT	pl1.LeaseID, pl1.PersonLeaseID, pl1.MoveOutDate
																 FROM PersonLease pl1) [plAfter] ON [plAfter].LeaseID = l.LeaseID
																					AND [plAfter].MoveOutDate > #bspad.WeekEndDate
												  LEFT JOIN PersonLease plNull ON l.LeaseID = plNull.LeaseID AND plNull.MoveOutDate IS NULL 
												  --LEFT JOIN Lease lPrior ON ulg.UnitLeaseGroupID = lPrior.UnitLeaseGroupID
														--							AND lPrior.LeaseStartDate < l.LeaseStartDate
												WHERE #bspad.PropertyID = #BoxScoreStats.PropertyID
												  AND #bspad.WeekEndDate = #BoxScoreStats.WeekEndDate
												  AND [plAfter].PersonLeaseID IS NULL
												  AND plNull.LeaseID IS NULL
												  AND l.LeaseStatus IN ('Evicted', 'Former'))

	SET @i = 1

	WHILE (@i <= @maxI)
	BEGIN
		TRUNCATE TABLE #ConsolodatedNumbers

		SELECT @endDate = WeekEndDate
			FROM #BoxScoreDates
			WHERE [Sequence] = @i

		INSERT #ConsolodatedNumbers
			EXEC GetConsolodatedOccupancyNumbers @accountID, @endDate, @accountingPeriodID, @propertyIDs	

		UPDATE #BoxScoreStats SET TenantVacancy = (SELECT COUNT(DISTINCT UnitID)
													   FROM #ConsolodatedNumbers
													   WHERE OccupiedUnitLeaseGroupID IS NULL
													     AND PropertyID = #BoxScoreStats.PropertyID)
			WHERE WeekEndDate = @endDate

		UPDATE #BoxScoreStats SET OccupiedUnits = (SELECT COUNT(DISTINCT UnitID)
													   FROM #ConsolodatedNumbers
													   WHERE OccupiedUnitLeaseGroupID IS NOT NULL
													     AND PropertyID = #BoxScoreStats.PropertyID)
			WHERE WeekEndDate = @endDate

		SET @i = @i + 1
	END


	UPDATE #FinancialStats SET IncomeActual = ISNULL((SELECT SUM(-je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #GLAccountInts #glai ON je.GLAccountID = #glai.GLAccountID 
																					AND #glai.GLInt >= 5110 AND #glai.GLInt <= 5990
															INNER JOIN #PropertiesAndAccountingPeriods #paap ON t.PropertyID = #paap.PropertyID
															INNER JOIN #AccountingPeriods #aps ON #paap.AccountingPeriodID = #aps.AccountingPeriodID
															INNER JOIN Settings s ON t.AccountID = s.AccountID
														WHERE je.AccountingBasis = s.DefaultAccountingBasis
														  AND t.TransactionDate >= #paap.APStartDate
														  AND t.TransactionDate <= #paap.APEndDate
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND #paap.PropertyID = #FinancialStats.PropertyID
														  AND #aps.EndDate = #FinancialStats.AccountingPeriodEndDate), 0)

	UPDATE #FinancialStats SET IncomeBudget = ISNULL((SELECT SUM(CASE WHEN (s.DefaultAccountingBasis = 'Cash') THEN bud.CashBudget ELSE bud.AccrualBudget END)
														FROM Budget bud
															INNER JOIN #GLAccountInts #glai ON bud.GLAccountID = #glai.GLAccountID 
																					AND #glai.GLInt >= 5110 AND #glai.GLInt <= 5990
															INNER JOIN PropertyAccountingPeriod pap ON bud.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
															INNER JOIN #PropertiesAndAccountingPeriods #paap ON pap.PropertyID = #paap.PropertyID 
																					AND pap.AccountingPeriodID = #paap.AccountingPeriodID
															INNER JOIN #AccountingPeriods #aps ON #paap.AccountingPeriodID = #aps.AccountingPeriodID
															INNER JOIN Settings s ON s.AccountID = @accountID
														WHERE #paap.PropertyID = #FinancialStats.PropertyID
														  AND #aps.EndDate = #FinancialStats.AccountingPeriodEndDate), 0)

	UPDATE #FinancialStats SET ControllableExpenseActual = ISNULL((SELECT SUM(je.Amount)
																		FROM JournalEntry je
																			INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																			INNER JOIN #GLAccountInts #glai ON je.GLAccountID = #glai.GLAccountID 
																									AND #glai.GLInt >= 6110 AND #glai.GLInt <= 6691
																									AND #glai.GLInt NOT IN (6305, 6306)
																			INNER JOIN #PropertiesAndAccountingPeriods #paap ON t.PropertyID = #paap.PropertyID
																			INNER JOIN #AccountingPeriods #aps ON #paap.AccountingPeriodID = #aps.AccountingPeriodID
																			INNER JOIN Settings s ON t.AccountID = s.AccountID
																		WHERE je.AccountingBasis = s.DefaultAccountingBasis
																		  AND t.TransactionDate >= #paap.APStartDate
																		  AND t.TransactionDate <= #paap.APEndDate
																		  AND t.Origin NOT IN ('Y', 'E')
																		  AND #paap.PropertyID = #FinancialStats.PropertyID
																		  AND je.AccountingBookID IS NULL
																		  AND #aps.EndDate = #FinancialStats.AccountingPeriodEndDate), 0)

	UPDATE #FinancialStats SET ControllableExpenseBudget = ISNULL((SELECT SUM(CASE WHEN (s.DefaultAccountingBasis = 'Cash') THEN bud.CashBudget ELSE bud.AccrualBudget END)
																		FROM Budget bud
																			INNER JOIN #GLAccountInts #glai ON bud.GLAccountID = #glai.GLAccountID 
																									AND #glai.GLInt >= 6110 AND #glai.GLInt <= 6691
																									AND #glai.GLInt NOT IN (6305, 6306)
																			INNER JOIN PropertyAccountingPeriod pap ON bud.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																			INNER JOIN #PropertiesAndAccountingPeriods #paap ON pap.PropertyID = #paap.PropertyID 
																									AND pap.AccountingPeriodID = #paap.AccountingPeriodID
																			INNER JOIN #AccountingPeriods #aps ON #paap.AccountingPeriodID = #aps.AccountingPeriodID
																			INNER JOIN Settings s ON s.AccountID = @accountID
																		WHERE #paap.PropertyID = #FinancialStats.PropertyID
																		  AND #aps.EndDate = #FinancialStats.AccountingPeriodEndDate), 0)

	UPDATE #FinancialStats SET NonControllableExpenseActual = ISNULL((SELECT SUM(je.Amount)
																		FROM JournalEntry je
																			INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																			INNER JOIN #GLAccountInts #glai ON je.GLAccountID = #glai.GLAccountID 
																									AND #glai.GLInt >= 6700 AND #glai.GLInt <= 6750
																			INNER JOIN #PropertiesAndAccountingPeriods #paap ON t.PropertyID = #paap.PropertyID
																			INNER JOIN #AccountingPeriods #aps ON #paap.AccountingPeriodID = #aps.AccountingPeriodID
																			INNER JOIN Settings s ON t.AccountID = s.AccountID
																		WHERE je.AccountingBasis = s.DefaultAccountingBasis
																		  AND t.TransactionDate >= #paap.APStartDate
																		  AND t.TransactionDate <= #paap.APEndDate
																		  AND t.Origin NOT IN ('Y', 'E')
																		  AND je.AccountingBookID IS NULL
																		  AND #paap.PropertyID = #FinancialStats.PropertyID
																		  AND #aps.EndDate = #FinancialStats.AccountingPeriodEndDate), 0)

	UPDATE #FinancialStats SET NonControllableExpenseBudget = ISNULL((SELECT SUM(CASE WHEN (s.DefaultAccountingBasis = 'Cash') THEN bud.CashBudget ELSE bud.AccrualBudget END)
																		FROM Budget bud
																			INNER JOIN #GLAccountInts #glai ON bud.GLAccountID = #glai.GLAccountID 
																									AND #glai.GLInt >= 6700 AND #glai.GLInt <= 6750
																			INNER JOIN PropertyAccountingPeriod pap ON bud.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																			INNER JOIN #PropertiesAndAccountingPeriods #paap ON pap.PropertyID = #paap.PropertyID 
																									AND pap.AccountingPeriodID = #paap.AccountingPeriodID
																			INNER JOIN #AccountingPeriods #aps ON #paap.AccountingPeriodID = #aps.AccountingPeriodID
																			INNER JOIN Settings s ON s.AccountID = @accountID
																		WHERE #paap.PropertyID = #FinancialStats.PropertyID
																		  AND #aps.EndDate = #FinancialStats.AccountingPeriodEndDate), 0)

	UPDATE #FinancialStats SET RegularCapitalImprovementsActual = ISNULL((SELECT SUM(je.Amount)
																		FROM JournalEntry je
																			INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																			INNER JOIN #GLAccountInts #glai ON je.GLAccountID = #glai.GLAccountID 
																									AND #glai.GLInt IN (1401, 1411, 1421, 1431, 1441, 1446, 1451, 1461, 1465, 1470, 1480, 1485, 1490)
																			INNER JOIN #PropertiesAndAccountingPeriods #paap ON t.PropertyID = #paap.PropertyID
																			INNER JOIN #AccountingPeriods #aps ON #paap.AccountingPeriodID = #aps.AccountingPeriodID
																			INNER JOIN Settings s ON t.AccountID = s.AccountID
																		WHERE je.AccountingBasis = s.DefaultAccountingBasis
																		  AND t.TransactionDate >= #paap.APStartDate
																		  AND t.TransactionDate <= #paap.APEndDate
																		  AND t.Origin NOT IN ('Y', 'E')
																		  AND je.AccountingBookID IS NULL
																		  AND #paap.PropertyID = #FinancialStats.PropertyID
																		  AND #aps.EndDate = #FinancialStats.AccountingPeriodEndDate), 0)

	UPDATE #FinancialStats SET RegularCapitalImprovementsBudget = ISNULL((SELECT SUM(CASE WHEN (s.DefaultAccountingBasis = 'Cash') THEN bud.CashBudget ELSE bud.AccrualBudget END)
																		FROM Budget bud
																			INNER JOIN #GLAccountInts #glai ON bud.GLAccountID = #glai.GLAccountID 
																									AND #glai.GLInt IN (1401, 1411, 1421, 1431, 1441, 1446, 1451, 1461, 1465, 1470, 1480, 1485, 1490)
																			INNER JOIN PropertyAccountingPeriod pap ON bud.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																			INNER JOIN #PropertiesAndAccountingPeriods #paap ON pap.PropertyID = #paap.PropertyID 
																									AND pap.AccountingPeriodID = #paap.AccountingPeriodID
																			INNER JOIN #AccountingPeriods #aps ON #paap.AccountingPeriodID = #aps.AccountingPeriodID
																			INNER JOIN Settings s ON s.AccountID = @accountID
																		WHERE #paap.PropertyID = #FinancialStats.PropertyID
																		  AND #aps.EndDate = #FinancialStats.AccountingPeriodEndDate), 0)

	UPDATE #FinancialStats SET NOIGenActual = ISNULL((SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #GLAccountInts #glai ON je.GLAccountID = #glai.GLAccountID 
																					AND #glai.GLInt IN (1414, 1424, 1429, 1434, 1444, 1449, 1454, 1464)
															INNER JOIN #PropertiesAndAccountingPeriods #paap ON t.PropertyID = #paap.PropertyID
															INNER JOIN #AccountingPeriods #aps ON #paap.AccountingPeriodID = #aps.AccountingPeriodID
															INNER JOIN Settings s ON t.AccountID = s.AccountID
														WHERE je.AccountingBasis = s.DefaultAccountingBasis
															AND t.TransactionDate >= #paap.APStartDate
															AND t.TransactionDate <= #paap.APEndDate
															AND t.Origin NOT IN ('Y', 'E')
															AND je.AccountingBookID IS NULL
															AND #paap.PropertyID = #FinancialStats.PropertyID
															AND #aps.EndDate = #FinancialStats.AccountingPeriodEndDate), 0)

	UPDATE #FinancialStats SET NOIGenBudget = ISNULL((SELECT SUM(CASE WHEN (s.DefaultAccountingBasis = 'Cash') THEN bud.CashBudget ELSE bud.AccrualBudget END)
														FROM Budget bud
															INNER JOIN #GLAccountInts #glai ON bud.GLAccountID = #glai.GLAccountID 
																					AND #glai.GLInt IN (1414, 1424, 1429, 1434, 1444, 1449, 1454, 1464)
															INNER JOIN PropertyAccountingPeriod pap ON bud.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
															INNER JOIN #PropertiesAndAccountingPeriods #paap ON pap.PropertyID = #paap.PropertyID 
																					AND pap.AccountingPeriodID = #paap.AccountingPeriodID
															INNER JOIN #AccountingPeriods #aps ON #paap.AccountingPeriodID = #aps.AccountingPeriodID
															INNER JOIN Settings s ON s.AccountID = @accountID
														WHERE #paap.PropertyID = #FinancialStats.PropertyID
															AND #aps.EndDate = #FinancialStats.AccountingPeriodEndDate), 0)

	UPDATE #FinancialStats SET BadDebtActual = ISNULL((SELECT SUM(-je.Amount)
															FROM JournalEntry je
																INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																INNER JOIN #GLAccountInts #glai ON je.GLAccountID = #glai.GLAccountID 
																						AND #glai.GLInt IN (6320)
																INNER JOIN #PropertiesAndAccountingPeriods #paap ON t.PropertyID = #paap.PropertyID
																INNER JOIN #AccountingPeriods #aps ON #paap.AccountingPeriodID = #aps.AccountingPeriodID
																INNER JOIN Settings s ON t.AccountID = s.AccountID
															WHERE je.AccountingBasis = s.DefaultAccountingBasis
															  AND t.TransactionDate >= #paap.APStartDate
															  AND t.TransactionDate <= #paap.APEndDate
															  AND #paap.PropertyID = #FinancialStats.PropertyID
															  AND t.Origin NOT IN ('Y', 'E')
															  AND je.AccountingBookID IS NULL
															  AND #aps.EndDate = #FinancialStats.AccountingPeriodEndDate), 0)

	UPDATE #FinancialStats SET BadDebtBudget = ISNULL((SELECT SUM(CASE WHEN (s.DefaultAccountingBasis = 'Cash') THEN bud.CashBudget ELSE bud.AccrualBudget END)
															FROM Budget bud
																INNER JOIN #GLAccountInts #glai ON bud.GLAccountID = #glai.GLAccountID 
																						AND #glai.GLInt IN (6320)
																INNER JOIN PropertyAccountingPeriod pap ON bud.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																INNER JOIN #PropertiesAndAccountingPeriods #paap ON pap.PropertyID = #paap.PropertyID 
																						AND pap.AccountingPeriodID = #paap.AccountingPeriodID
																INNER JOIN #AccountingPeriods #aps ON #paap.AccountingPeriodID = #aps.AccountingPeriodID
																INNER JOIN Settings s ON s.AccountID = @accountID
															WHERE #paap.PropertyID = #FinancialStats.PropertyID
															  AND #aps.EndDate = #FinancialStats.AccountingPeriodEndDate), 0)



	CREATE TABLE #MyTempPayments (
		PropertyID uniqueidentifier not null,
		PaymentID uniqueidentifier not null,
		Amount money null,
		[Date] date null,
		MonthPart int null)

	CREATE TABLE #MyPaymentDates (
		PropertyID uniqueidentifier not null,
		AccountingPeriodEndDate date null,
		MonthPart int null,
		Day1 date null,
		Day6 date null,
		Day10 date null, 
		Day15 date null,
		Day20 date null,
		Day25 date null,
		DayEnd date null)

	INSERT #MyTempPayments 
		SELECT DISTINCT t.PropertyID, pay.PaymentID, pay.Amount, pay.[Date], DATEPART(MONTH, pay.[Date])
			FROM Payment pay
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Payment') AND tt.[Group] IN ('Lease', 'Prospect', 'Non-Resident Account', 'WOIT Account')
				INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsPayment = 1
				INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
			WHERE pay.[Date] >= #pad.PrevMonthStartDate 
				AND pay.[Date] <= #pad.EndDate
				

	INSERT #MyPaymentDates
		SELECT	PropertyID, AccountingPeriodEndDate, DATEPART(MONTH, AccountingPeriodEndDate), 
				DATEADD(month, DATEDIFF(month, 0, AccountingPeriodEndDate), 0),
				DATEADD(DAY, 5, DATEADD(month, DATEDIFF(month, 0, AccountingPeriodEndDate), 0)),
				DATEADD(DAY, 9, DATEADD(month, DATEDIFF(month, 0, AccountingPeriodEndDate), 0)),
				DATEADD(DAY, 14, DATEADD(month, DATEDIFF(month, 0, AccountingPeriodEndDate), 0)),
				DATEADD(DAY, 19, DATEADD(month, DATEDIFF(month, 0, AccountingPeriodEndDate), 0)),
				DATEADD(DAY, 24, DATEADD(month, DATEDIFF(month, 0, AccountingPeriodEndDate), 0)),
				AccountingPeriodEndDate
			FROM #PaymentStats

	UPDATE #PaymentStats SET TotalCharges = ISNULL((SELECT SUM(t.Amount)
													FROM [Transaction] t
														INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
																				AND tt.[Group] IN ('Lease', 'Prospect', 'Non-Resident Account', 'WOIT Account')
																				AND tt.Name = 'Charge'														
													WHERE t.PropertyID = #PaymentStats.PropertyID
													  AND DATEPART(MONTH, t.TransactionDate) = DATEPART(MONTH, #PaymentStats.AccountingPeriodEndDate)
													  AND DATEPART(YEAR, t.TransactionDate) = DATEPART(YEAR, #PaymentStats.AccountingPeriodEndDate)), 0)

	UPDATE #PaymentStats SET TotalCredits = ISNULL((SELECT SUM(Amount)
													FROM (SELECT DISTINCT p.PaymentID, p.Amount
															FROM Payment p
																INNER JOIN [PaymentTransaction] pt ON pt.PaymentID = p.PaymentID
																INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
																INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
																						AND tt.[Group] IN ('Lease', 'Prospect', 'Non-Resident Account', 'WOIT Account')
																						AND tt.Name = 'Credit'
																INNER JOIN LedgerItemType lit on t.LedgerItemTypeID = lit.LedgerItemTypeID
																INNER JOIN GLAccount gl ON gl.GLAccountID = lit.GLAccountID AND gl.Number IN ('5240', '5245', '5250')
															WHERE t.PropertyID = #PaymentStats.PropertyID
															  AND DATEPART(MONTH, p.[Date]) = DATEPART(MONTH, #PaymentStats.AccountingPeriodEndDate)
															  AND DATEPART(YEAR, p.[Date]) = DATEPART(YEAR, #PaymentStats.AccountingPeriodEndDate)) AS Credits), 0)
		
	UPDATE #PaymentStats SET PaymentsBy6 = ISNULL((SELECT SUM(#mtp.Amount)
													FROM #MyTempPayments #mtp
														INNER JOIN #MyPaymentDates #mpd ON #mtp.MonthPart = #mpd.MonthPart
													WHERE #mtp.MonthPart = #PaymentStats.MonthPart
													  AND #mtp.PropertyID = #PaymentStats.PropertyID
													  AND [Date] >= #mpd.Day1
													  AND [Date] <= #mpd.Day6), 0)

	UPDATE #PaymentStats SET PaymentsBy10 = ISNULL((SELECT SUM(#mtp.Amount)
													FROM #MyTempPayments #mtp
														INNER JOIN #MyPaymentDates #mpd ON #mtp.MonthPart = #mpd.MonthPart
													WHERE #mtp.MonthPart = #PaymentStats.MonthPart
													  AND #mtp.PropertyID = #PaymentStats.PropertyID
													  AND [Date] > #mpd.Day6
													  AND [Date] <= #mpd.Day10), 0)
		
	UPDATE #PaymentStats SET PaymentsBy15 = ISNULL((SELECT SUM(#mtp.Amount)
													FROM #MyTempPayments #mtp
														INNER JOIN #MyPaymentDates #mpd ON #mtp.MonthPart = #mpd.MonthPart
													WHERE #mtp.MonthPart = #PaymentStats.MonthPart
													  AND #mtp.PropertyID = #PaymentStats.PropertyID
													  AND [Date] > #mpd.Day10
													  AND [Date] <= #mpd.Day15), 0)
		
	UPDATE #PaymentStats SET PaymentsBy20 = ISNULL((SELECT SUM(#mtp.Amount)
													FROM #MyTempPayments #mtp
														INNER JOIN #MyPaymentDates #mpd ON #mtp.MonthPart = #mpd.MonthPart
													WHERE #mtp.MonthPart = #PaymentStats.MonthPart
													  AND #mtp.PropertyID = #PaymentStats.PropertyID
													  AND [Date] > #mpd.Day15
													  AND [Date] <= #mpd.Day20), 0)
		
	UPDATE #PaymentStats SET PaymentsBy25 = ISNULL((SELECT SUM(#mtp.Amount)
													FROM #MyTempPayments #mtp
														INNER JOIN #MyPaymentDates #mpd ON #mtp.MonthPart = #mpd.MonthPart
													WHERE #mtp.MonthPart = #PaymentStats.MonthPart
													  AND #mtp.PropertyID = #PaymentStats.PropertyID
													  AND [Date] > #mpd.Day20
													  AND [Date] <= #mpd.Day25), 0)

	UPDATE #PaymentStats SET PaymentsByEndOfMonth = ISNULL((SELECT SUM(#mtp.Amount)
														FROM #MyTempPayments #mtp
															INNER JOIN #MyPaymentDates #mpd ON #mtp.MonthPart = #mpd.MonthPart
														WHERE #mtp.MonthPart = #PaymentStats.MonthPart
														  AND #mtp.PropertyID = #PaymentStats.PropertyID
														  AND [Date] > #mpd.Day25
														  AND [Date] <= #mpd.DayEnd), 0)

	SELECT * FROM #PropertyInformation
	SELECT 
		PropertyID ,
		ISNULL(Bedrooms, 0) AS Bedrooms,
		ISNULL(UnitCount, 0) AS UnitCount,
		ISNULL(GrossPotentialRent, 0) AS GrossPotentialRent,		
		ISNULL(AveragePerUnit, 0) AS AveragePerUnit,			
		ISNULL(DownCount, 0) AS DownCount ,					
		ISNULL(VacantCount, 0) AS VacantCount ,				
		ISNULL(VacantCost, 0) AS VacantCost ,				
		ISNULL(ReadyCount, 0) AS ReadyCount ,				
		ISNULL(OccupiedCount, 0) OccupiedCount ,				
		ISNULL(OccupiedValue, 0) AS OccupiedValue,				
		ISNULL(ApplicationCount, 0) AS ApplicationCount,			
		ISNULL(ApprovalCount, 0) AS ApprovalCount,				
		ISNULL(FutureMoveInCount, 0) AS FutureMoveInCount,			
		ISNULL(LeasedUnits, 0) AS LeasedUnits,				
		ISNULL(ThirtyDayNotice, 0) AS ThirtyDayNotice,			
		ISNULL(LeasedLessNotice, 0) AS 	LeasedLessNotice,
		ISNULL(OnlineApplicationCount, 0) AS OnlineApplicationCount		
	 FROM #UnitStatsByBedroom
	SELECT * FROM #BoxScoreStats
	SELECT * FROM #FinancialStats
	SELECT * FROM #PaymentStats


END
GO
