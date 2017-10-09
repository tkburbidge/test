SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[GetLateFeesToAssess] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@unitLeaseGroupID uniqueidentifier = null,
	@accountingPeriodID uniqueidentifier = null,
	@date datetime = null,
	@lateFeeScheduleID uniqueidentifier = null
AS
DECLARE @propertyIDs GuidCollection
DECLARE @loopCtr			int
DECLARE @maxLoopCtr			int
DECLARE @includePaymentsOnDate bit
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- Table we'll return when we get this done.
    CREATE TABLE #TempLateFees (
		UnitLeaseGroupID		uniqueidentifier			NOT NULL,
		UnitNumber				nvarchar(20)				NOT NULL,
		PaddedUnitNumber		nvarchar(20)				NOT NULL,
		LeaseID					uniqueidentifier			NOT NULL,
		ResidentNames			nvarchar(1000)				NULL,
		TimesLate				tinyint						NULL,
		LateBalance				money						NULL,
		CurrentBalance			money						NULL, 
		LateFeeAlreadyCharged	money						NULL,
		RevokedCreditCount		int							NULL,
		RevokedCreditAmount		money						NULL,
		MoveInDate				datetime					NULL,
		MoveOutDate				datetime					NULL,
		RentDueDay				int							NULL,
		Threshold				money						NULL,
		--LateFeeGracePeriod		tinyint						NULL,
		MaximumLateFee			money						NULL,
		MaximumLateFeeType		nvarchar(100)				NULL,
		--InitialLateFee			money						NULL,
		--AdditionalLateFeePerDay		money					NULL,
		TotalFeeDue				money						NULL,
		BilledPeriodCharges		money						NULL,
		LateFeeScheduleID		uniqueidentifier			NULL,
		LateFeeToCharge			money						NULL,
		LastLateFeeChargedDate	date						NULL,
		DoNotAssessLateFees		bit							NULL,
		FeeLedgerItemTypeID		uniqueidentifier			NULL,
		MarketRentCharges		money						NULL,
		)
		
-- Table we'll use to compute LateFeeBalance which is outstanding charges for this period only.
	CREATE TABLE #TempOutstandingTransactions (
		ObjectID			uniqueidentifier		NOT NULL,
		TransactionID		uniqueidentifier		NOT NULL,
		Amount				money					NOT NULL,
		TaxAmount			money					NULL,
		--TaxesPaid			money					NULL,
		UnPaidAmount		money					NULL,
		TaxUnpaidAmount		money					NULL,
		[Description]		nvarchar(500)			NULL,
		TranDate			datetime2				NULL,
		GLAccountID			uniqueidentifier		NULL, 
		OrderBy				smallint				NULL,
		TaxRateGroupID		uniqueidentifier		NULL,
		LedgerItemTypeID	uniqueidentifier		NULL,
		LedgerItemTypeAbbr	nvarchar(50)			NULL,
		GLNumber			nvarchar(50)			NULL,		
		IsWriteOffable		bit						NULL,
		Notes				nvarchar(MAX)			NULL,
		TaxRateID			uniqueidentifier		NULL
		)		
		
-- Table to hold late fee schedules
	CREATE TABLE #TempFeeSchedule (
		LateFeeScheduleID		uniqueidentifier			NULL,
		LateFeeScheduleDetailID	uniqueidentifier			NULL,
		Threshold				money						NULL,
		[Day]					smallint					NULL,
		IsPercent				bit							NULL,
		Amount					decimal(6, 2)				NULL,
		AssessedBalance			nvarchar(30)				NULL,
		FeesAssessedDaily		bit							NULL
		)
		
-- Table to hold sorted late fee schedules.  We need the detail records sorted to find the last day a fee should be assessed.
	CREATE TABLE #TempFeeSchedule2 (
		Sequence				int							NOT NULL,
		LateFeeScheduleID		uniqueidentifier			NULL,
		LateFeeScheduleDetailID	uniqueidentifier			NULL,
		Threshold				money						NULL,
		[Day]					smallint					NULL,
		IsPercent				bit							NULL,
		Amount					decimal(6, 2)				NULL,
		AssessedBalance			nvarchar(30)				NULL,
		FeesAssessedDaily		bit							NULL,
		MaxCounter				int							NULL
		)		
		
-- Table to merge the late fee details with the UnitLeaseGroup details to compute the total fee due, in parts, by each detail record.
	CREATE TABLE #Calculator (
		Sequence						int					not null,
		LateFeeScheduleID				uniqueidentifier	not null,
		LateFeeScheduleDetailID			uniqueidentifier	null,
		UnitLeaseGroupID				uniqueidentifier	not null,
		MathBalance						money				not null,
		LastChargeDate					date				null,
		[Day]							int					not null,
		IsPercent						bit					not null,
		Amount							money				not null,
		FeesAssessedDaily				bit					not null,
		MaxCounter						int					not null,
		Total							money				not null
		)

		
	INSERT @propertyIDs VALUES (@propertyID)
	
	SELECT @includePaymentsOnDate = ISNULL(LateFeeAssessmentIncludePaymentsOnDay, 0) FROM Property WHERE PropertyID = @propertyID

	INSERT #TempOutstandingTransactions
			EXEC GetOutstandingCharges @accountID, @propertyID, @unitLeaseGroupID, 'Lease', 1, @date, 0, @includePaymentsOnDate
			
	IF (@lateFeeScheduleID IS NULL)
	BEGIN
		DELETE #TOT
			FROM #TempOutstandingTransactions #TOT
				INNER JOIN LedgerItemType lit ON #TOT.LedgerItemTypeID = lit.LedgerItemTypeID
				--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyID = @propertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE #TOT.TranDate < pap.StartDate
			   OR lit.IsLateFeeAssessable = 0

		INSERT #TempLateFees 
			SELECT	DISTINCT ulg.UnitLeaseGroupID AS 'UnitLeaseGroupID', 
					u.Number AS 'UnitNumber', 
					u.PaddedNumber AS 'PaddedUnitNumber',
					l.LeaseID,
					STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
							 FROM Person 
							 INNER JOIN PersonLease  ON Person.PersonID = PersonLease.PersonID		
							 INNER JOIN PersonType  ON Person.PersonID = PersonType.PersonID
							 INNER JOIN PersonTypeProperty  ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
							 WHERE PersonLease.LeaseID = l.LeaseID
								   AND PersonType.[Type] = 'Resident'				   
								   AND PersonLease.MainContact = 1				   
							 FOR XML PATH ('')), 1, 2, '') AS 'ResidentNames',
					((SELECT COUNT(*) FROM ULGAPInformation WHERE ObjectID = ulg.UnitLeaseGroupID AND Late = 1) +
					ISNULL((SELECT ImportTimesLate FROM UnitLeaseGroup WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID), 0)) AS 'TimesLate',
				   --(BB.Balance + LB.Balance) AS 'LateBalance',
					0 AS 'LateBalance',
					CB.Balance AS 'CurrentBalance', 							
					0 AS 'LateFeeAlreadyCharged', 
					0 AS 'RevokedCreditCount',
					0 AS 'RevokedCreditAmount',
					(SELECT MIN(pl.MoveInDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID) AS 'MoveInDate',
					(SELECT MAX(pl.MoveOutDate) 
						FROM PersonLease pl 
						WHERE pl.LeaseID = l.LeaseID
							AND 0 = (SELECT COUNT(*) FROM PersonLease pli WHERE pli.LeaseID = l.LeaseID AND MoveOutDate IS NULL)
							AND pl.MoveOutDate > pap.StartDate 
							AND pl.MoveOutDate <= pap.EndDate)
						AS 'MoveOutDate',
					--l.RentDueDay, 
					1 AS 'RentDueDay',
					lfs.Threshold,
					--l.LateFeeGracePeriod, 
					--l.MaximumLateFee,
					lfs.MaximumLateFee,
					lfs.MaximumLateFeeType,
					--l.InitialLateFee, 
					--l.AdditionalLateFeePerDay,
					0 AS 'TotalFeeDue',
					0 AS 'BilledPeriodCharges',
					l.LateFeeScheduleID AS 'LateFeeScheduleID',
					null AS 'LateFeeToCharge',
					null AS 'LastLateFeeChargedDate',

					CASE
						WHEN (ulgapI.DoNotAssessLateFees = 1) THEN 1
						ELSE 0 END AS 'DoNotAssessLateFees',
					lfs.LedgerItemTypeID,
					MarketRent.Amount AS 'MarketRentCharges'
				FROM UnitLeaseGroup ulg 
				--[Transaction] t							
					--INNER JOIN [UnitLeaseGroup] ulg ON t.ObjectID = ulg.UnitLeaseGroupID
					INNER JOIN [Lease] l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN [LateFeeSchedule] lfs ON l.LateFeeScheduleID = lfs.LateFeeScheduleID
					INNER JOIN [Unit] u ON ulg.UnitID = u.UnitID		
					INNER JOIN [UnitType] ut on u.UnitTypeID = ut.UnitTypeID		
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					--LEFT JOIN [AccountingPeriod] ap ON ap.AccountingPeriodID = @accountingPeriodID
					LEFT JOIN PropertyAccountingPeriod pap ON pap.AccountingPeriodID = @accountingPeriodID AND pap.PropertyID = @propertyID
					LEFT JOIN [ULGAPInformation] ulgapI ON ulgapI.AccountingPeriodID = @accountingPeriodID AND ulg.UnitLeaseGroupID = ulgapI.ObjectID
					CROSS APPLY GetObjectBalance(null, @date, ulg.UnitLeaseGroupID, 0, @propertyIDs) AS CB
					CROSS APPLY GetMarketRentByDate(u.UnitID, @date, 1) as MarketRent
					--CROSS APPLY GetObjectBalance(null, DATEADD(DAY, -1, ap.StartDate), ulg.UnitLeaseGroupID, 0, @propertyIDs) AS BB
					--CROSS APPLY GetObjectBalance(ap.StartDate, @date, ulg.UnitLeaseGroupID, 1, @propertyIDs) AS LB
				WHERE --t.AccountID = @accountID
					--AND t.PropertyID = @propertyID
					--AND t.TransactionDate >= ap.StartDate
					--AND t.TransactionDate <= @date
					ulg.UnitLeaseGroupID IN (SELECT ObjectID FROM #TempOutstandingTransactions)
					AND ulg.AccountID = @accountID
					AND b.PropertyID = @propertyID
					AND l.AssessLateFees = 1
					AND ((@unitLeaseGroupID IS NULL) OR (@unitLeaseGroupID = ulg.UnitLeaseGroupID))
					AND ulg.UnitLeaseGroupID IN (SELECT DISTINCT ObjectID FROM #TempOutstandingTransactions)
					-- Get the late fee settings from the current lease
					AND l.LeaseID = (SELECT TOP 1 [Lease].LeaseID 
									 FROM [Lease] 
									 WHERE [Lease].UnitLeaseGroupID = ulg.UnitLeaseGroupID
										AND [Lease].LeaseStatus IN ('Current', 'Under Eviction'))
									   --AND ((@date >= [Lease].LeaseStartDate AND @date <= [Lease].LeaseEndDate) 
										--		OR [Lease].LeaseEndDate = (SELECT MAX(LeaseEndDate) FROM [Lease] WHERE [Lease].UnitLeaseGroupID = ulg.UnitLeaseGroupID))
									 --ORDER BY [Lease].LeaseEndDate DESC)	

		

	END
	ELSE
	BEGIN
		DELETE #TOT
			FROM #TempOutstandingTransactions #TOT
				--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyID = @propertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE #TOT.TranDate < pap.StartDate
			   OR #TOT.LedgerItemTypeID NOT IN (SELECT LedgerItemTypeID 
													FROM LateFeeScheduleLedgerItemType
													WHERE LateFeeScheduleID = @lateFeeScheduleID)
			  

		INSERT #TempLateFees 
			SELECT	DISTINCT ulg.UnitLeaseGroupID AS 'UnitLeaseGroupID', 
					u.Number AS 'UnitNumber', 
					u.PaddedNumber AS 'PaddedUnitNumber',
					l.LeaseID,
					STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
							 FROM Person 
							 INNER JOIN PersonLease  ON Person.PersonID = PersonLease.PersonID		
							 INNER JOIN PersonType  ON Person.PersonID = PersonType.PersonID
							 INNER JOIN PersonTypeProperty  ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
							 WHERE PersonLease.LeaseID = l.LeaseID
								   AND PersonType.[Type] = 'Resident'				   
								   AND PersonLease.MainContact = 1				   
							 FOR XML PATH ('')), 1, 2, '') AS 'ResidentNames',
					((SELECT COUNT(*) FROM ULGAPInformation WHERE ObjectID = ulg.UnitLeaseGroupID AND Late = 1) +
					ISNULL((SELECT ImportTimesLate FROM UnitLeaseGroup WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID), 0)) AS 'TimesLate',
				   --(BB.Balance + LB.Balance) AS 'LateBalance',
					0 AS 'LateBalance',
					CB.Balance AS 'CurrentBalance', 							
					0 AS 'LateFeeAlreadyCharged', 
					0 AS 'RevokedCreditCount',
					0 AS 'RevokedCreditAmount',
					(SELECT MIN(pl.MoveInDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID) AS 'MoveInDate',
					(SELECT MAX(pl.MoveOutDate) 
						FROM PersonLease pl 
						WHERE pl.LeaseID = l.LeaseID
							AND 0 = (SELECT COUNT(*) FROM PersonLease pli WHERE pli.LeaseID = l.LeaseID AND MoveOutDate IS NULL)
							AND pl.MoveOutDate > pap.StartDate 
							AND pl.MoveOutDate <= pap.EndDate)
						AS 'MoveOutDate',
					--l.RentDueDay, 
					1 AS 'RentDueDay',
					lfs.Threshold,
					--l.LateFeeGracePeriod, 
					--l.MaximumLateFee,
					lfs.MaximumLateFee,
					lfs.MaximumLateFeeType,
					--l.InitialLateFee, 
					--l.AdditionalLateFeePerDay,
					0 AS 'TotalFeeDue',
					0 AS 'BilledPeriodCharges',
					lfs.LateFeeScheduleID AS 'LateFeeScheduleID',
					null AS 'LateFeeToCharge',
					null AS 'LastLateFeeChargedDate',
					CAST(0 AS BIT) AS 'DoNotAssessLateFees',
					lfs.LedgerItemTypeID,
					MarketRent.Amount AS 'MarketRentCharges'
				FROM UnitLeaseGroup ulg 
				--[Transaction] t							
					--INNER JOIN [UnitLeaseGroup] ulg ON t.ObjectID = ulg.UnitLeaseGroupID
					INNER JOIN [Lease] l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN [LateFeeSchedule] lfs ON lfs.LateFeeScheduleID = @lateFeeScheduleID
					INNER JOIN [Unit] u ON ulg.UnitID = u.UnitID		
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					--LEFT JOIN [AccountingPeriod] ap ON ap.AccountingPeriodID = @accountingPeriodID
					LEFT JOIN PropertyAccountingPeriod pap ON pap.AccountingPeriodID = @accountingPeriodID AND pap.PropertyID = @propertyID
					--LEFT JOIN [ULGAPInformation] ulgapI ON ulgapI.AccountingPeriodID = @accountingPeriodID AND ulg.UnitLeaseGroupID = ulgapI.ObjectID
					CROSS APPLY GetObjectBalance(null, @date, ulg.UnitLeaseGroupID, 0, @propertyIDs) AS CB
					CROSS APPLY GetMarketRentByDate(u.UnitID, @date, 1) as MarketRent
					--CROSS APPLY GetObjectBalance(null, DATEADD(DAY, -1, ap.StartDate), ulg.UnitLeaseGroupID, 0, @propertyIDs) AS BB
					--CROSS APPLY GetObjectBalance(ap.StartDate, @date, ulg.UnitLeaseGroupID, 1, @propertyIDs) AS LB
				WHERE --t.AccountID = @accountID
					--AND t.PropertyID = @propertyID
					--AND t.TransactionDate >= ap.StartDate
					--AND t.TransactionDate <= @date
					ulg.UnitLeaseGroupID IN (SELECT ObjectID FROM #TempOutstandingTransactions)
					AND ulg.AccountID = @accountID
					AND b.PropertyID = @propertyID
					AND l.AssessLateFees = 1
					AND ((@unitLeaseGroupID IS NULL) OR (@unitLeaseGroupID = ulg.UnitLeaseGroupID))
					AND ulg.UnitLeaseGroupID IN (SELECT DISTINCT ObjectID FROM #TempOutstandingTransactions)
					-- Get the late fee settings from the current lease
					AND l.LeaseID = (SELECT TOP 1 [Lease].LeaseID 
									 FROM [Lease] 
									 WHERE [Lease].UnitLeaseGroupID = ulg.UnitLeaseGroupID
										AND [Lease].LeaseStatus IN ('Current', 'Under Eviction'))
									   --AND ((@date >= [Lease].LeaseStartDate AND @date <= [Lease].LeaseEndDate) 
										--		OR [Lease].LeaseEndDate = (SELECT MAX(LeaseEndDate) FROM [Lease] WHERE [Lease].UnitLeaseGroupID = ulg.UnitLeaseGroupID))
									 --ORDER BY [Lease].LeaseEndDate DESC)	
		END		

		-- Delete people who moved in this month
		DELETE #tlf
			FROM #TempLateFees #tlf
			INNER JOIN PropertyAccountingPeriod pap ON pap.AccountingPeriodID = @accountingPeriodID AND pap.PropertyID = @propertyID
			WHERE #tlf.MoveInDate >= pap.StartDate
				AND #tlf.MoveInDate <= pap.EndDate

		-- Move rent and other LateFeeAssessable LedgerItemTypes to LateBalance			
		UPDATE #TLF SET LateBalance = ISNULL((SELECT SUM(#TOT.UnPaidAmount)
										   FROM #TempOutstandingTransactions #TOT
											   --INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
											   INNER JOIN PropertyAccountingPeriod pap ON pap.AccountingPeriodID = @accountingPeriodID AND pap.PropertyID = @propertyID
											   --INNER JOIN LedgerItemType lit ON #TOT.LedgerItemTypeID = lit.LedgerItemTypeID
										   WHERE ObjectID = #TLF.UnitLeaseGroupID 
										     AND TranDate >= pap.StartDate
										     AND TranDate <= pap.EndDate
										     /*AND @lateFeeScheduleID IS NULL
										     AND lit.IsLateFeeAssessable = 1*/), 0)
			FROM #TempLateFees #TLF
			
		-- Calculate LateBalance based on the LateFeeScheduleID that was passed in.
		--UPDATE #TLF SET LateBalance = ISNULL((SELECT SUM(#TOT.UnPaidAmount)
		--								   FROM #TempOutstandingTransactions #TOT
		--									   INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
		--									   INNER JOIN LedgerItemType lit ON #TOT.LedgerItemTypeID = lit.LedgerItemTypeID
		--									   INNER JOIN LateFeeScheduleLedgerItemType lfslit ON lit.LedgerItemTypeID = lfslit.LedgerItemTypeID
		--																								AND lfslit.LateFeeScheduleID = @lateFeeScheduleID
		--								   WHERE ObjectID = #TLF.UnitLeaseGroupID 
		--								     AND TranDate >= ap.StartDate
		--								     AND TranDate <= ap.EndDate
		--								     AND @lateFeeScheduleID IS NOT NULL), 0)
		--	FROM #TempLateFees #TLF		
			
		--UPDATE #TLF SET LateBalance = LateBalance - ISNULL((SELECT SUM(pp.Amount)
		--														FROM ProcessorPayment pp
		--															INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
		--														WHERE pp.ObjectID = #TLF.UnitLeaseGroupID
		--														  AND pp.PaymentID IS NULL
		--														  AND pp.DateSettled IS NULL
		--														  AND pp.IntegrationPartnerItemID IN (31, 32)
		--														  AND CONVERT(date, pp.DateCreated) <= @date
		--														  --AND pp.DateCreated >= ap.StartDate
		--														  --AND pp.DateCreated <= ap.EndDate

		--														  ), 0)
		--	FROM #TempLateFees #TLF	
					
		DELETE #TempLateFees WHERE LateBalance <= 0 OR (Threshold IS NOT NULL AND LateBalance < Threshold)		


					  
		UPDATE #TempLateFees SET LateFeeAlreadyCharged = (ISNULL((SELECT SUM(t.Amount)
				FROM [Transaction] t
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
					--INNER JOIN Settings s ON s.LateFeeLedgerItemTypeID = lit.LedgerItemTypeID
					--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
					INNER JOIN PropertyAccountingPeriod pap ON pap.AccountingPeriodID = @accountingPeriodID AND pap.PropertyID = @propertyID
					LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
				WHERE t.AccountID = @accountID
				  AND t.ObjectID = #TempLateFees.UnitLeaseGroupID
				  AND t.TransactionDate >= pap.StartDate
				  AND t.TransactionDate <= pap.EndDate
				  AND tr.TransactionID IS NULL
				  AND t.ReversesTransactionID IS NULL
				  AND tt.[Name] = 'Charge'
				  AND t.LedgerItemTypeID = #TempLateFees.FeeLedgerItemTypeID), 0))
				  
		UPDATE #TempLateFees SET LastLateFeeChargedDate = (SELECT MAX(t.TransactionDate)
				FROM [Transaction] t
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
					--INNER JOIN Settings s ON s.LateFeeLedgerItemTypeID = lit.LedgerItemTypeID
					--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
					INNER JOIN PropertyAccountingPeriod pap ON pap.AccountingPeriodID = @accountingPeriodID AND pap.PropertyID = @propertyID
					LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
				WHERE t.AccountID = @accountID
				  AND t.ObjectID = #TempLateFees.UnitLeaseGroupID
				  AND t.TransactionDate >= pap.StartDate
				  AND t.TransactionDate <= pap.EndDate
				  AND tr.TransactionID IS NULL
				  AND t.ReversesTransactionID IS NULL
				  AND tt.[Name] = 'Charge'
				  AND t.LedgerItemTypeID = #TempLateFees.FeeLedgerItemTypeID)			  

		IF (@lateFeeScheduleID IS NULL)
		BEGIN
					  
			UPDATE #TempLateFees SET RevokedCreditAmount = ISNULL((SELECT SUM(t.Amount)
					FROM [Transaction] t
						INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID 
						LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
						--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
						INNER JOIN PropertyAccountingPeriod pap ON pap.AccountingPeriodID = @accountingPeriodID AND pap.PropertyID = @propertyID
					WHERE t.ObjectID = #TempLateFees.UnitLeaseGroupID
					  AND t.TransactionDate >= pap.StartDate
					  AND t.TransactionDate <= @date
					  AND tt.[Name] = 'Credit'
					  AND tr.TransactionID IS NULL
					  AND t.ReversesTransactionID IS NULL
					  AND t.Origin = 'A'
					  AND lit.IsRevokable = 1), 0)
						  
			UPDATE #TempLateFees SET RevokedCreditCount = (SELECT COUNT(*)
					FROM [Transaction] t
						INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID 
						LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
						--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
						INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyID = @propertyID AND pap.AccountingPeriodID = @accountingPeriodID
					WHERE t.ObjectID = #TempLateFees.UnitLeaseGroupID
					  AND t.TransactionDate >= pap.StartDate
					  AND t.TransactionDate <= @date
					  AND tt.[Name] = 'Credit'
					  AND tr.TransactionID IS NULL
					  AND t.ReversesTransactionID IS NULL
					  AND lit.IsRevokable = 1)
		END
		ELSE
		BEGIN
			UPDATE #TempLateFees SET RevokedCreditAmount = 0
			UPDATE #TempLateFees SET RevokedCreditCount = 0
		END

				  

		-- Rent Case: We care about origin and we do care about LIT.IsLateFeeAssessable
		-- NonRent Case: We don't care about origin or LIT.IsLateFeeAssessable but care that the
		--					LateFeeScheduleLedgerItemType matches the LIT of the charge
		-- Get Billed charges				  
		UPDATE #TempLateFees SET BilledPeriodCharges = (SELECT ISNULL(SUM(t.Amount), 0)
				FROM [Transaction] t
					INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					LEFT JOIN LateFeeScheduleLedgerItemType lfslit ON lit.LedgerItemTypeID = lfslit.LedgerItemTypeID
												AND lfslit.LateFeeScheduleID = @lateFeeScheduleID
					LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
					--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
					INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyID = @propertyID AND pap.AccountingPeriodID = @accountingPeriodID
				WHERE t.ObjectID = #TempLateFees.UnitLeaseGroupID
				  AND t.TransactionDate >= pap.StartDate
				  AND t.TransactionDate <= pap.EndDate
				  AND tt.[Name] = 'Charge'
				  AND (((@lateFeeScheduleID IS NULL) AND (t.Origin IN ('A', 'I')) AND (lit.IsLateFeeAssessable = 1)) 
					OR ((@lateFeeScheduleID IS NOT NULL) AND (lfslit.LateFeeScheduleLedgerItemTypeID IS NOT NULL)))
				  AND tr.TransactionID IS NULL
				  AND t.ReversesTransactionID IS NULL
				  /*AND lit.IsLateFeeAssessable = 1*/)
		
		-- Rent Case: Keep same
		-- Non-Rent Case: Don't care about this
		-- Get billed credits				  				  
		UPDATE #TempLateFees SET BilledPeriodCharges = ISNULL(BilledPeriodCharges, 0) - ISNULL((SELECT ISNULL(SUM(t.Amount), 0)
				FROM [Transaction] t					
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					INNER JOIN PaymentTransaction pt on pt.TransactionID = t.TransactionID
					INNER JOIN Payment p ON p.PaymentID = pt.PaymentID
					LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID					
					-- Only include if it was applied to a charge that was late fee assessable that was posted in the month
					LEFT JOIN [Transaction] ta ON ta.TransactionID = t.AppliesToTransactionID					
					LEFT JOIN [LedgerItemType] talit ON talit.LedgerItemTypeID = ta.LedgerItemTypeID
					LEFT JOIN [TransactionType] tta ON ta.TransactionTypeID = tta.TransactionTypeID
					
					--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
					INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyID = @propertyID AND pap.AccountingPeriodID = @accountingPeriodID
				WHERE t.ObjectID = #TempLateFees.UnitLeaseGroupID
				  AND p.[Date] >= pap.StartDate
				  AND p.[Date] <= pap.EndDate
				  AND tt.[Name] = 'Credit'
				  AND t.Origin IN ('A', 'I')
				  AND tr.TransactionID IS NULL
				  AND t.ReversesTransactionID IS NULL
				  
				  -- This acts like it's a big old IF wrapping around all of this!
				  AND @lateFeeScheduleID IS NULL
				  
				  -- Only include if it was applied to a charge that was late fee assessable that was posted in the month
				  AND tta.Name = 'Charge'
				  AND ta.TransactionDate >= pap.StartDate
				  AND ta.TransactionDate <= pap.EndDate
				  AND talit.IsLateFeeAssessable = 1
				  ),0)
				
-- Beginning of new code for knock off late fees.
-- First we build a table of all of the late fee schedules used in this collection of residents. 
-- Each detail record which has a day that we haven't encountered yet is added to this table.

		INSERT INTO #TempFeeSchedule 
			SELECT DISTINCT lfsd.LateFeeScheduleID, lfsd.LateFeeScheduleDetailID, lfs.Threshold,
							lfsd.[Day], lfsd.IsPercent, lfsd.Amount, lfsd.AssessedBalance, lfsd.FeesAssessedDaily
				FROM LateFeeSchedule lfs
					INNER JOIN LateFeeScheduleDetail lfsd ON lfs.LateFeeScheduleID = lfsd.LateFeeScheduleID
					INNER JOIN #TempLateFees #tlf ON lfs.LateFeeScheduleID = #tlf.LateFeeScheduleID
				WHERE lfs.LateFeeScheduleID IN (SELECT DISTINCT LateFeeScheduleID FROM LateFeeSchedule)
				  AND lfsd.[Day] <= DAY(@date)
				
			UNION ALL

-- Add one final detail row for each record as of the day of the month for which we are calculating late fees.
-- This is our stop record, kind of.  If a row was added for this day in the first clause above, we don't add it.			
			SELECT DISTINCT lfsd.LateFeeScheduleID, null, lfs.Threshold, 
							DAY(@date),	lfsd.IsPercent, lfsd.Amount, lfsd.AssessedBalance, lfsd.FeesAssessedDaily
						FROM LateFeeSchedule lfs
							INNER JOIN #TempLateFees #tlf ON lfs.LateFeeScheduleID = #tlf.LateFeeScheduleID
							INNER JOIN LateFeeScheduleDetail lfsd ON lfs.LateFeeScheduleID = lfsd.LateFeeScheduleID 
									AND lfsd.LateFeeScheduleDetailID = (SELECT TOP 1 LateFeeScheduleDetailID 
																	  FROM LateFeeScheduleDetail
																	  WHERE LateFeeScheduleID = lfs.LateFeeScheduleID
																		AND [Day] < DAY(@date)
																	  ORDER BY [Day] DESC)
							LEFT JOIN LateFeeScheduleDetail lfsdDay ON lfs.LateFeeScheduleID = lfsdDay.LateFeeScheduleID AND lfsd.[Day] = lfsdDay.[Day] 
				WHERE lfs.LateFeeScheduleID IN (SELECT DISTINCT LateFeeScheduleID FROM LateFeeSchedule)
				  AND lfsd.FeesAssessedDaily = 1
				  AND DAY(@date) NOT IN (SELECT [Day] FROM LateFeeScheduleDetail WHERE LateFeeScheduleID = lfs.LateFeeScheduleID)
				  
-- Sort the detail records by day.	
		INSERT #TempFeeSchedule2
			SELECT ROW_NUMBER() OVER (PARTITION BY LateFeeScheduleID ORDER BY [Day]) AS 'Sequence', LateFeeScheduleID, LateFeeScheduleDetailID, Threshold,
					 [Day], IsPercent, Amount, AssessedBalance, FeesAssessedDaily, 0
				FROM #TempFeeSchedule	
				
-- Set the max counter for each schedule, which is the maximum number of detail records.
		UPDATE #tfs2 SET MaxCounter = (SELECT MAX(Sequence)
										FROM #TempFeeSchedule2 
										WHERE LateFeeScheduleID = #tfs2.LateFeeScheduleID
										GROUP BY LateFeeScheduleID)
			FROM #TempFeeSchedule2 #tfs2	
	
-- Merge our resident financial information with our ordered late fee schedules and details.
		INSERT #Calculator 
			SELECT	#tfs2.Sequence, #tfs2.LateFeeScheduleID, #tfs2.LateFeeScheduleDetailID, #tlf.UnitLeaseGroupID, 
					CASE
						WHEN (#tfs2.AssessedBalance = 'MonthlyScheduled') THEN #tlf.BilledPeriodCharges
						WHEN (#tfs2.AssessedBalance = 'BilledOpen') THEN #tlf.LateBalance
						WHEN (#tfs2.AssessedBalance = 'CurrentBalance') THEN #tlf.CurrentBalance
						WHEN (#tfs2.AssessedBalance = 'MarketRent') THEN #tlf.MarketRentCharges
						ELSE 0 END AS 'MathBalance',
					#tlf.LastLateFeeChargedDate AS 'LastChargeDate',
					#tfs2.[Day], #tfs2.IsPercent, #tfs2.Amount, #tfs2.FeesAssessedDaily, #tfs2.MaxCounter, 0
				FROM #TempFeeSchedule2 #tfs2
					INNER JOIN #TempLateFees #tlf ON #tfs2.LateFeeScheduleID = #tlf.LateFeeScheduleID
	
	
--select * from #Calculator
		DELETE #C
			FROM #Calculator #C
				INNER JOIN #TempLateFees #tlf ON #C.UnitLeaseGroupID = #tlf.UnitLeaseGroupID
			WHERE #tlf.LastLateFeeChargedDate IS NOT NULL
			  AND #C.Sequence < (SELECT TOP 1 Sequence 
									FROM #Calculator 
									WHERE UnitLeaseGroupID = #tlf.UnitLeaseGroupID
									  AND [Day] <= DAY(#tlf.LastLateFeeChargedDate) + 1
									ORDER BY [Day] DESC)
					
		DELETE #C
			FROM #Calculator #C
				INNER JOIN #TempLateFees #tlf ON #C.UnitLeaseGroupID = #tlf.UnitLeaseGroupID
			WHERE #tlf.LastLateFeeChargedDate IS NOT NULL
			  AND #C.FeesAssessedDaily = 0
			  AND #C.Sequence <= (SELECT TOP 1 Sequence 
									FROM #Calculator 
									WHERE UnitLeaseGroupID = #tlf.UnitLeaseGroupID
									  AND [Day] <= DAY(#tlf.LastLateFeeChargedDate)
									ORDER BY [Day] DESC)		
									
--select * from #Calculator																
		DELETE #C
			FROM #Calculator #C
				INNER JOIN #TempLateFees #tlf ON #C.UnitLeaseGroupID = #tlf.UnitLeaseGroupID
			WHERE (#tlf.LastLateFeeChargedDate IS NOT NULL AND DAY(#tlf.LastLateFeeChargedDate) = #C.[Day])
			  AND #C.FeesAssessedDaily = 0

		UPDATE #C SET [Day] = (SELECT DAY(LastLateFeeChargedDate) + 1
									FROM #TempLateFees 
									WHERE UnitLeaseGroupID = #C.UnitLeaseGroupID)
			FROM #Calculator #C
				INNER JOIN #TempLateFees #TLF ON #C.UnitLeaseGroupID = #TLF.UnitLeaseGroupID 
			WHERE DAY(#TLF.LastLateFeeChargedDate) > #C.[Day]
			   OR ((DAY(#TLF.LastLateFeeChargedDate) = #C.[Day]) AND (#C.FeesAssessedDaily = 1))

-- Update late fee totals for set amount per day, accumulating daily, except for the last day.  This finds the blocks of days and figures it 
		UPDATE #c SET Total = ISNULL(((SELECT Amount FROM #Calculator WHERE UnitLeaseGroupID = #c.UnitLeaseGroupID AND Sequence = #c.Sequence 
																			AND LateFeeScheduleID = #c.LateFeeScheduleID) * 
												((SELECT [Day] FROM #Calculator WHERE UnitLeaseGroupID = #c.UnitLeaseGroupID AND LateFeeScheduleID = #c.LateFeeScheduleID 
																					AND Sequence = #c.Sequence + 1) - 
												 (SELECT [Day] FROM #Calculator WHERE UnitLeaseGroupID = #c.UnitLeaseGroupID AND LateFeeScheduleID = #c.LateFeeScheduleID 
																					AND Sequence = #c.Sequence))), 0)
			FROM #Calculator #c
			WHERE #c.Sequence < #c.MaxCounter
			  AND #c.FeesAssessedDaily = 1
			  AND #c.IsPercent = 0


-- Update late fee totals for last day of set fee totals, calculations above don't include the day for which we are figuring the late fees.
		UPDATE #c SET Total = ISNULL(Total, 0) + ISNULL((SELECT Amount FROM #Calculator 
															WHERE [Day] = DAY(@date) AND UnitLeaseGroupID = #c.UnitLeaseGroupID AND LateFeeScheduleID = #c.LateFeeScheduleID), 0)
			FROM #Calculator #c
			WHERE /*#c.Sequence = #c.MaxCounter - 1
			  AND*/ #c.FeesAssessedDaily = 1
			  AND #c.IsPercent = 0
			  AND #c.[Day] = DAY(@date)


-- Update late fee totals for fixed amount charged on day it's late, doesn't accumulate daily.	  
		UPDATE #c SET Total = ISNULL((SELECT Amount 
										  FROM #Calculator 
										  WHERE [Day] <= DAY(@date)
											AND LateFeeScheduleID = #c.LateFeeScheduleID
											AND UnitLeaseGroupID = #c.UnitLeaseGroupID
											AND Sequence = #c.Sequence
											AND FeesAssessedDaily = 0
											AND IsPercent = 0), 0)
			FROM #Calculator #c
			WHERE #c.FeesAssessedDaily = 0
			  AND #c.IsPercent = 0

-- Update late totals for a set percent, accumulating daily.
		UPDATE #c SET Total = ISNULL((SELECT CAST(Amount AS decimal(8, 4))/100.0 FROM #Calculator 
													WHERE LateFeeScheduleID = #c.LateFeeScheduleID AND UnitLeaseGroupID = #c.UnitLeaseGroupID AND Sequence = #c.Sequence) * 
								#c.MathBalance * 
								((SELECT [Day] FROM #Calculator WHERE UnitLeaseGroupID = #c.UnitLeaseGroupID AND LateFeeScheduleID = #c.LateFeeScheduleID 
																	AND Sequence = #c.Sequence + 1) - 
								 (SELECT [Day] FROM #Calculator WHERE UnitLeaseGroupID = #c.UnitLeaseGroupID AND LateFeeScheduleID = #c.LateFeeScheduleID 
																	AND Sequence = #c.Sequence)), 0)
			FROM #Calculator #c
			WHERE #c.Sequence < #c.MaxCounter
			  AND #c.FeesAssessedDaily = 1
			  AND #c.IsPercent = 1
			  
-- Update late fee totals for set percentage, not accumulating daily.
		UPDATE #c SET Total = ISNULL((SELECT CAST(Amount AS decimal(8, 4))/100.00 FROM #Calculator 
										WHERE UnitLeaseGroupID = #c.UnitLeaseGroupID AND LateFeeScheduleID = #c.LateFeeScheduleID AND Sequence = #c.Sequence) *
								#c.MathBalance, 0)
			FROM #Calculator #c
			WHERE #c.FeesAssessedDaily = 0
			  AND #c.IsPercent = 1
  
-- Update late fee totals last day.
		UPDATE #c SET Total = ISNULL((SELECT Amount FROM #Calculator 
										WHERE UnitLeaseGroupID = #c.UnitLeaseGroupID AND LateFeeScheduleID = #c.LateFeeScheduleID AND Sequence = #c.Sequence), 0)
			FROM #Calculator #c
			WHERE #c.Sequence = #c.MaxCounter
			  AND #c.[Day] = Day(@date)
			  AND #c.IsPercent = 0
			  AND #c.LateFeeScheduleDetailID IS NOT NULL

-- Update late fee totals for last day if computing totals on that day.
		UPDATE #c SET Total = ISNULL((SELECT CAST(Amount AS decimal(8, 4))/100.00 FROM #Calculator 
										  WHERE UnitLeaseGroupID = #c.UnitLeaseGroupID AND LateFeeScheduleID = #c.LateFeeScheduleID AND Sequence = #c.Sequence) *
								#c.MathBalance, 0)
			FROM #Calculator #c
			WHERE #c.Sequence = #c.MaxCounter
			  AND #c.[Day] = Day(@date)
			  AND #c.IsPercent = 1	
			  --AND #c.LateFeeScheduleDetailID IS NOT NULL 	
			  
		UPDATE #c SET #c.Total = lfsd.MinimumFee
			FROM #Calculator #c
				INNER JOIN LateFeeScheduleDetail lfsd ON #c.LateFeeScheduleDetailID = lfsd.LateFeeScheduleDetailID
			WHERE lfsd.MinimumFee IS NOT NULL
			  AND #c.Total > 0
			  AND #c.Total < lfsd.MinimumFee	
			  AND #c.Sequence = 1			
					
-- Update resident record with sum of all of the individual late fee detail totals.
		UPDATE #tlf SET TotalFeeDue = ISNULL((SELECT SUM(ISNULL(Total, 0)) 
											FROM #Calculator
											WHERE UnitLeaseGroupID = #tlf.UnitLeaseGroupID
											GROUP BY UnitLeaseGroupID), 0)
			FROM #TempLateFees #tlf	
			
		UPDATE #tlf SET RentDueDay = l.RentDueDay
			FROM #TempLateFees #tlf
				INNER JOIN Lease l ON #tlf.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseID = (SELECT TOP 1 LeaseID
																									  FROM Lease 
																									  WHERE UnitLeaseGroupID = l.UnitLeaseGroupID
																									    AND LeaseStatus NOT IN ('Pending', 'Pending Transfer', 'Renewed')
																									  ORDER BY LeaseEndDate DESC)

		-- Set up the various MaximumLateFees depending on type.
		UPDATE #TempLateFees SET MaximumLateFee = (SELECT ISNULL(((CAST(MaximumLateFee AS decimal(5,2)) / 100.00) * [MarketRent].Amount), 0)
													   FROM #TempLateFees #tlf
														   INNER JOIN UnitLeaseGroup ulg ON #tlf.UnitLeaseGroupID = ulg.UnitLeaseGroupID
														   CROSS APPLY GetMarketRentByDate(ulg.UnitID, @date, 1) AS [MarketRent]
													   WHERE #tlf.UnitLeaseGroupID = #TempLateFees.UnitLeaseGroupID
													     AND #TempLateFees.MaximumLateFeeType = 'Percent of Market Rent')
			WHERE MaximumLateFeeType = 'Percent of Market Rent'

		DECLARE @firstOfMonth date = DATEADD(day, -(DATEPART(Day, @date) - 1), @date)													     
		UPDATE #TempLateFees SET MaximumLateFee = ISNULL((SELECT ISNULL(((CAST(MaximumLateFee AS decimal(5,2)) / 100.00) * ISNULL([ActualRent].Amount, 0)), 0)
													   FROM #TempLateFees #tlf
														   INNER JOIN (SELECT lli.LeaseID AS 'LeaseID',
																			  SUM(ISNULL(lli.Amount, 0)) AS 'Amount'
																		   FROM LeaseLedgerItem lli
																		       INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
																		       INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
																		   WHERE lli.LeaseID = #TempLateFees.LeaseID
																		     AND lli.StartDate <= @firstOfMonth
																		     AND lli.EndDate >= @firstOfMonth
																		   GROUP BY lli.LeaseID) AS [ActualRent] ON #tlf.LeaseID = [ActualRent].LeaseID
													   WHERE #tlf.UnitLeaseGroupID = #TempLateFees.UnitLeaseGroupID
													     AND #TempLateFees.MaximumLateFeeType = 'Percent of Actual Rent'), 0)
			WHERE MaximumLateFeeType = 'Percent of Actual Rent'
		
		-- Make sure we don't over charge		
		UPDATE #TempLateFees SET TotalFeeDue = MaximumLateFee - LateFeeAlreadyCharged WHERE (TotalFeeDue + LateFeeAlreadyCharged) > MaximumLateFee
	
		UPDATE #TempLateFees SET TotalFeeDue = ROUND(TotalFeeDue, 2)
						
		SELECT * FROM #TempLateFees 
		WHERE TotalFeeDue > 0
		ORDER BY PaddedUnitNumber
		
--select * from #Calculator order by UnitLeaseGroupID, Sequence		
		

END
GO
