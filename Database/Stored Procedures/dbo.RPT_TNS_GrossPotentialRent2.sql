SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[RPT_TNS_GrossPotentialRent2] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection readonly,
	@accountingPeriodID uniqueidentifier,
	@startDate date OUTPUT,
	@endDate date OUTPUT,
	@lossToLeaseGLAccountID uniqueidentifier OUTPUT,
	@lossToLeaseGLAccountNumber nvarchar(100) OUTPUT,
	@lossToLeaseGLAccountName nvarchar(100) OUTPUT,
	@gainToLeaseGLAccountID uniqueidentifier OUTPUT,
	@gainToLeaseGLAccountNumber nvarchar(100) OUTPUT,
	@gainToLeaseGLAccountName nvarchar(100) OUTPUT	
AS
BEGIN
		
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    	
	DECLARE @lossToLeaseLedgerItemTypeID uniqueidentifier
	DECLARE @gainToLeaseLedgerItemTypeID uniqueidentifier
	DECLARE @vacancyLossGLAccountID uniqueidentifier

	--SELECT @startDate = StartDate, @endDate = EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID
	
	SELECT	@lossToLeaseLedgerItemTypeID = LossToLeaseLedgerItemTypeID, 
			@gainToLeaseLedgerItemTypeID = GainToLeaseLedgerItemTypeID,
			@lossToLeaseGLAccountID = ltlgl.GLAccountID,
			@lossToLeaseGLAccountNumber = ltlgl.Number,
			@lossToLeaseGLAccountName = ltlgl.Name,
			@gainToLeaseGLAccountID = gtlgl.GLAccountID,
			@gainToLeaseGLAccountNumber = gtlgl.Number,
			@gainToLeaseGLAccountName = gtlgl.Name
		FROM Settings s		
		INNER JOIN GLAccount ltlgl ON ltlgl.GLAccountID = s.LossToLeaseGLAccountID
		INNER JOIN GLAccount gtlgl ON gtlgl.GLAccountID = s.GainToLeaseGLAccountID
		WHERE s.AccountID = @accountID			

	CREATE TABLE #Units 
	(	
		PropertyName nvarchar(100),
		PropertyID uniqueidentifier null,
		UnitID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		UnitNumber nvarchar(50),
		PaddedNumber nvarchar(50),
		UnitType nvarchar(50),
		SquareFeet int,
		UnitTypeSquareFeet int,
		UnitLeaseGroupID uniqueidentifier null,				
		MarketRent money null,
		--LossToLease money,
		--GainToLease money,
		ActualRent money,
		--VacancyLoss money,
		Credits money,
		RentCollected money,		
		RentDelinquency money,
		PriorRentPaid money
	)
	
	CREATE TABLE #Residents
	(
		UnitLeaseGroupID uniqueidentifier,
		LeaseID uniqueidentifier, 
		LeaseStartDate date,
		LeaseEndDate date,
		Residents nvarchar(1000)
	)

	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		UnitStatus nvarchar(200) not null,
		UnitStatusLedgerItemTypeID uniqueidentifier not null,
		RentLedgerItemTypeID uniqueidentifier not null,
		MarketRent money null,
		Amenities nvarchar(MAX) null)	
		
	CREATE TABLE #PropertiesAndDates (
		Sequence int identity not null,
		PropertyID uniqueidentifier not null,
		StartDate date not null,
		EndDate date not null)
		
	CREATE TABLE #Deductions (
		UnitNumber nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		Amount money null,
		GLAccountID uniqueidentifier null,
		GLAccountNumber nvarchar(20) null,
		GLAccountName nvarchar(50) null,
		AccountingBasis nvarchar(20) null,
		IsVacancyLoss bit not null)
		
	CREATE TABLE #Credits (
		TransactionID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitLeaseGroupID uniqueidentifier not null,
		GLAccountID uniqueidentifier not null,
		Amount money null)
			
	CREATE TABLE #Vacancy
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,	
		UnitNumber nvarchar(50),
		MoveInDate date null,
		MoveOutDate date null,
		VacancyLossGLAccountID uniqueidentifier		
	)

	CREATE TABLE #Activity 
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		LeaseID uniqueidentifier,
		Unit nvarchar(50),
		MoveInDate date null,
		MoveOutDate date null	
	)
		
	DECLARE @propertyID uniqueidentifier, @ctr int = 1, @maxCtr int, @unitIDs GuidCollection, @date date
	
	INSERT #PropertiesAndDates SELECT pIDs.Value, pap.StartDate, pap.EndDate
		FROM @propertyIDs pIDs
			INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	DECLARE @hapLedgersExist BIT  = 0
	SET @hapLedgersExist = (CASE WHEN ((SELECT COUNT(*) FROM WOITAccount woit
							INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = woit.PropertyID
							WHERE woit.BillingAccountID IS NOT NULL) > 0) THEN 1
							ELSE 0
							END)
	SELECT @startDate = MIN(StartDate), @endDate = MAX(EndDate) FROM #PropertiesAndDates
			
	SET @maxCtr = (SELECT MAX(Sequence) FROM #PropertiesAndDates)
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @propertyID = PropertyID, @date = EndDate FROM #PropertiesAndDates WHERE Sequence = @ctr
		DELETE FROM @unitIDs
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
							WHERE u.IsHoldingUnit = 0
		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 0
		SET @ctr = @ctr + 1
	END				

	INSERT INTO #nits
		SELECT 
			p.Name,
			p.PropertyID,
			u.UnitID,
			u.UnitTypeID,
			u.Number,
			u.PaddedNumber,
			ut.Name,
			u.SquareFootage AS 'SquareFeet',
			ut.SquareFootage AS 'UnitTypeSquareFeet',
			null AS 'UnitLeaseGroupID',			
			#ua.MarketRent AS 'MarketRent',			
			0 AS 'ActualRent',			
			0 AS 'Credits', 
			0 AS 'RentCollected',			
			0 AS 'Delinquency',
			0 AS 'PriorRentPaid'		
		FROM Unit u
		INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
		INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
		INNER JOIN Building b on b.BuildingID = u.BuildingID
		INNER JOIN Property p on p.PropertyID = b.PropertyID	
		INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = p.PropertyID
		WHERE  u.IsHoldingUnit = 0

	-- Get all of the Non Loss-To-Lease Credits that apply to Rent.  
	-- But, we put these in the #Credits table, we need to transfer them to the #Deductions table.
	INSERT #Credits
		SELECT DISTINCT t.TransactionID, ulg.UnitID, t.ObjectID, gl.GLAccountID, t.Amount
			FROM [Transaction] t
				-- Join in applied to rent transactions
				INNER JOIN [Transaction] ta ON t.AppliesToTransactionID = ta.TransactionID				
				INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID				
				LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
				INNER JOIN GLAccount gl ON gl.GLAccountID = lit.GLAccountID
				INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
				LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
				LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
				LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID																						
				INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = t.PropertyID
			WHERE 
			-- Transaction is in the given month
			  t.TransactionDate >= #pad.StartDate --@startDate
			  AND t.TransactionDate <= #pad.EndDate --@endDate
			-- Applied to a transaction in the given month
			  AND ta.TransactionDate >= #pad.StartDate --@startDate
			  AND ta.TransactionDate <= #pad.EndDate --@endDate
			-- Credit transaction
			  AND (lit.IsCredit = 1 OR lit.LedgerItemTypeID IS NULL)
			-- Credit transaction NOT LossToLease
			  --AND lit.LedgerItemTypeID <> @lossToLeaseLedgerItemTypeID
			-- Applied to rent
			  AND alit.IsRent = 1
			-- Transaction isn't reversed								
			  AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate /*@endDate*/)
			  AND (tar.TransactionID IS NULL OR tar.TransactionDate > #pad.EndDate /*@endDate*/)
			  AND t.ReversesTransactionID IS NULL
			  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))

	IF (@hapLedgersExist = 1)
	BEGIN
		INSERT #Credits
			SELECT DISTINCT t.TransactionID, ulg.UnitID, t.ObjectID, gl.GLAccountID, t.Amount
				FROM [Transaction] t
					-- Join in applied to rent transactions
					INNER JOIN [Transaction] ta ON t.AppliesToTransactionID = ta.TransactionID				
					INNER JOIN WOITAccount woit ON woit.WOITAccountID = t.ObjectID
					INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = woit.BillingAccountID
					LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
					INNER JOIN GLAccount gl ON gl.GLAccountID = lit.GLAccountID
					INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
					LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
					LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
					LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID																						
					INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = t.PropertyID
				WHERE 
				-- Transaction is in the given month
				  t.TransactionDate >= #pad.StartDate --@startDate
				  AND t.TransactionDate <= #pad.EndDate --@endDate
				-- Applied to a transaction in the given month
				  AND ta.TransactionDate >= #pad.StartDate --@startDate
				  AND ta.TransactionDate <= #pad.EndDate --@endDate
				-- Credit transaction
				  AND (lit.IsCredit = 1 OR lit.LedgerItemTypeID IS NULL)
				-- Credit transaction NOT LossToLease
				  --AND lit.LedgerItemTypeID <> @lossToLeaseLedgerItemTypeID
				-- Applied to rent
				  AND alit.IsRent = 1
				-- Transaction isn't reversed								
				  AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate /*@endDate*/)
				  AND (tar.TransactionID IS NULL OR tar.TransactionDate > #pad.EndDate /*@endDate*/)
				  AND t.ReversesTransactionID IS NULL
				  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
	END

	-- Transfer Credits to the #Deductions table.			
	INSERT #Deductions
		SELECT	u.Number, #c.UnitID, #c.Amount, gla.GLAccountID, gla.Number, gla.Name,
				'Cash', 0
			FROM #Credits #c
				INNER JOIN Unit u ON #c.UnitID = u.UnitID
				INNER JOIN GLAccount gla ON #c.GLAccountID = gla.GLAccountID					
				
	UPDATE #Units SET Credits = (SELECT ISNULL(SUM(Amount), 0)
								 FROM #Deductions
								 WHERE #units.UnitID = #Deductions.UnitID)							

	-- Get all rent charges charged to a given lease											
	UPDATE #Units SET ActualRent = (SELECT ISNULL(SUM(t.Amount), 0)
											FROM [Transaction] t
											INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = t.ObjectID
											INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
											INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
											LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
											LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID											
											WHERE ulg.UnitID = #units.UnitID
												AND t.TransactionDate >= #pad.StartDate --@startDate
												AND t.TransactionDate <= #pad.EndDate --@endDate
												AND lit.IsRent = 1
												--AND (tr.TransactionID IS NULL OR tr.TransactionDate > @endDate)
												--AND t.ReversesTransactionID IS NULL
												AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))

	IF (@hapLedgersExist = 1)
	BEGIN
		UPDATE #Units SET ActualRent = ISNULL(ActualRent, 0) + (SELECT ISNULL(SUM(t.Amount), 0)
											FROM [Transaction] t
											INNER JOIN WOITAccount woit ON woit.WOITAccountID = t.ObjectID
											INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = woit.BillingAccountID
											INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
											INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
											LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
											LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID											
											WHERE ulg.UnitID = #units.UnitID
												AND t.TransactionDate >= #pad.StartDate --@startDate
												AND t.TransactionDate <= #pad.EndDate --@endDate
												AND lit.IsRent = 1
												--AND (tr.TransactionID IS NULL OR tr.TransactionDate > @endDate)
												--AND t.ReversesTransactionID IS NULL
												AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))
	END

	UPDATE #Units SET RentDelinquency = ActualRent	

	UPDATE #Units SET RentCollected = (SELECT ISNULL(SUM(t.Amount), 0)
										FROM [Transaction] t
										INNER JOIN [TransactionType] tt on t.TransactionTypeID = tt.TransactionTypeID
										-- Join in applied to rent transactions
										INNER JOIN [Transaction] ta ON t.AppliesToTransactionID = ta.TransactionID
										INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = t.ObjectID
										--INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
										INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
										INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
										LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
										LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
										LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID											
										WHERE ulg.UnitID = #units.UnitID
											-- Transaction is in the given month
											AND t.TransactionDate >= #pad.StartDate --@startDate
											AND t.TransactionDate <= #pad.EndDate  --@endDate
											-- Applied to a transaction in the given month
											AND ta.TransactionDate >= #pad.StartDate --@startDate
											AND ta.TransactionDate <= #pad.EndDate --@endDate
											-- Payment transaction											
											--AND lit.IsPayment = 1
											AND tt.Name = 'Payment'
											-- Applied to rent
											AND (alit.IsRent = 1 OR alit.LedgerItemTypeID = @gainToLeaseLedgerItemTypeID)
											AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate /*@endDate*/)
											AND (tar.TransactionID IS NULL OR tar.TransactionDate > #pad.EndDate /*@endDate*/)
											AND t.ReversesTransactionID IS NULL
											AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))		

	IF (@hapLedgersExist = 1)
	BEGIN
		UPDATE #Units SET RentCollected = ISNULL(RentCollected, 0) + (SELECT ISNULL(SUM(t.Amount), 0)
																	FROM [Transaction] t
																	INNER JOIN WOITAccount woit ON woit.WOITAccountID = t.ObjectID
																	INNER JOIN [TransactionType] tt on t.TransactionTypeID = tt.TransactionTypeID
																	-- Join in applied to rent transactions
																	INNER JOIN [Transaction] ta ON t.AppliesToTransactionID = ta.TransactionID
																	INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = woit.BillingAccountID
																	--INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
																	INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
																	INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
																	LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
																	LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
																	LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID											
																	WHERE ulg.UnitID = #units.UnitID
																		-- Transaction is in the given month
																		AND t.TransactionDate >= #pad.StartDate --@startDate
																		AND t.TransactionDate <= #pad.EndDate  --@endDate
																		-- Applied to a transaction in the given month
																		AND ta.TransactionDate >= #pad.StartDate --@startDate
																		AND ta.TransactionDate <= #pad.EndDate --@endDate
																		-- Payment transaction											
																		--AND lit.IsPayment = 1
																		AND tt.Name = 'Payment'
																		-- Applied to rent
																		AND (alit.IsRent = 1 OR alit.LedgerItemTypeID = @gainToLeaseLedgerItemTypeID)
																		AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate /*@endDate*/)
																		AND (tar.TransactionID IS NULL OR tar.TransactionDate > #pad.EndDate /*@endDate*/)
																		AND t.ReversesTransactionID IS NULL
																		AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))	
	END
																											
	UPDATE #Units SET RentDelinquency = RentDelinquency - (SELECT ISNULL(SUM(t.Amount), 0)
															FROM [Transaction] t
															-- Join in applied to rent transactions
															INNER JOIN [Transaction] ta ON t.AppliesToTransactionID = ta.TransactionID
															INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = t.ObjectID
															LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
															INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
															INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
															LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
															LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
															LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID											
															WHERE ulg.UnitID = #units.UnitID
																-- Transaction is in the given month
																AND t.TransactionDate >= #pad.StartDate --@startDate
																AND t.TransactionDate <= #pad.EndDate --@endDate
																-- Applied to a transaction in the given month
																AND ta.TransactionDate >= #pad.StartDate --@startDate
																AND ta.TransactionDate <= #pad.EndDate --@endDate
																-- Credit transaction
																	-- If a deposit is applied to a rent charge the ledger item
																	-- type will be null											
																AND (lit.IsCredit = 1 OR lit.IsPayment = 1 OR lit.LedgerItemTypeID IS NULL)															
																-- Applied to rent
																AND (alit.IsRent = 1 AND alit.LedgerItemTypeID <> @gainToLeaseLedgerItemTypeID)
																AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate /*@endDate*/)
																AND (tar.TransactionID IS NULL OR tar.TransactionDate > #pad.EndDate /*@endDate*/)
																AND t.ReversesTransactionID IS NULL
																AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))		
					
	IF (@hapLedgersExist = 1)
	BEGIN
		UPDATE #Units SET RentDelinquency = RentDelinquency - (SELECT ISNULL(SUM(t.Amount), 0)
																FROM [Transaction] t
																-- Join in applied to rent transactions
																INNER JOIN [Transaction] ta ON t.AppliesToTransactionID = ta.TransactionID
																INNER JOIN WOITAccount woit ON woit.WOITAccountID = t.ObjectID
																INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = woit.BillingAccountID
																LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
																INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
																INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
																LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
																LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
																LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID											
																WHERE ulg.UnitID = #units.UnitID
																	-- Transaction is in the given month
																	AND t.TransactionDate >= #pad.StartDate --@startDate
																	AND t.TransactionDate <= #pad.EndDate --@endDate
																	-- Applied to a transaction in the given month
																	AND ta.TransactionDate >= #pad.StartDate --@startDate
																	AND ta.TransactionDate <= #pad.EndDate --@endDate
																	-- Credit transaction
																		-- If a deposit is applied to a rent charge the ledger item
																		-- type will be null											
																	AND (lit.IsCredit = 1 OR lit.IsPayment = 1 OR lit.LedgerItemTypeID IS NULL)															
																	-- Applied to rent
																	AND (alit.IsRent = 1 AND alit.LedgerItemTypeID <> @gainToLeaseLedgerItemTypeID)
																	AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate /*@endDate*/)
																	AND (tar.TransactionID IS NULL OR tar.TransactionDate > #pad.EndDate /*@endDate*/)
																	AND t.ReversesTransactionID IS NULL
																	AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))	
	END

	UPDATE #Units SET RentDelinquency = 0 WHERE RentDelinquency < 0					
	
	-- Need a column (PriorRentPaid) for payments made to rent charges where the payment is in the period but the charge 
	-- it was applied to is not 

	-- Payments
	-- Payment.[Date] in period
	-- TransactionType.Name = Payment
	-- Don't care about reversals
	-- AppliesToTransaction.Date outside of period
	-- AppliesToTransaction.LedgerItemType.IsRent = 1

	
	UPDATE #Units SET PriorRentPaid = ISNULL((SELECT SUM(ta.Amount)
											FROM [Transaction] t
												INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
												INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
												-- Make sure the application was a payment
												INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name IN ('Payment')
												-- Make sure the charge is a rent charge
												INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
												INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID
												INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
												INNER JOIN #PropertiesAndDates #pad On t.PropertyID = #pad.PropertyID
											WHERE
											  -- Make sure its not a reversal 
											  pay.Amount > 0
											  -- Payment date is in the period
											  AND ta.TransactionDate >= #pad.StartDate --@startDate
											  AND ta.TransactionDate <= #pad.EndDate --@endDate
											  -- Original charge was not in the period
											  AND (t.TransactionDate < #pad.StartDate /*@startDate*/ OR t.TransactionDate > #pad.EndDate /*@endDate*/)
											  -- Tie it to the unit
											  AND ulg.UnitID = #Units.UnitID), 0)

	IF (@hapLedgersExist = 1)
	BEGIN

		UPDATE #Units SET PriorRentPaid = ISNULL(PriorRentPaid, 0) + ISNULL((SELECT SUM(ta.Amount)
											FROM [Transaction] t
												INNER JOIN WOITAccount woit ON woit.WOITAccountID = t.ObjectID
												INNER JOIN UnitLeaseGroup ulg ON woit.BillingAccountID = ulg.UnitLeaseGroupID
												INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
												-- Make sure the application was a payment
												INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name IN ('Payment')
												-- Make sure the charge is a rent charge
												INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
												INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID
												INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
												INNER JOIN #PropertiesAndDates #pad On t.PropertyID = #pad.PropertyID
											WHERE
											  -- Make sure its not a reversal 
											  pay.Amount > 0
											  -- Payment date is in the period
											  AND ta.TransactionDate >= #pad.StartDate --@startDate
											  AND ta.TransactionDate <= #pad.EndDate --@endDate
											  -- Original charge was not in the period
											  AND (t.TransactionDate < #pad.StartDate /*@startDate*/ OR t.TransactionDate > #pad.EndDate /*@endDate*/)
											  -- Tie it to the unit
											  AND ulg.UnitID = #Units.UnitID), 0)
	END
	-- Add in reversals
	-- Payment.[Date] in period
	-- Payment.Amount < 0
	-- TransactionType.Name=  Payment
	-- Transaction t ReversesTransactionID is not null
	-- JOIN ReveressTransaction
	-- JOIN application transaction 
	-- Charge is outside of period
	-- AppliesToTransaction.LedgerItemType.IsRent = 1
	
	UPDATE #Units SET PriorRentPaid = ISNULL(PriorRentPaid, 0) + ISNULL((SELECT SUM(tar.Amount)
																			  FROM [Transaction] tar
																					INNER JOIN PaymentTransaction pt on pt.TransactionID = tar.TransactionID
																					INNER JOIN Payment pay on pay.PaymentID = pt.PaymentID
																				  -- Get the application to the rent
																				  INNER JOIN [Transaction] ta ON tar.ReversesTransactionID = ta.TransactionID
																				  -- Applied to a rent charge
																				  INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
																				  INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID 
																												AND tta.Name IN ('Payment')
																				 -- Make sure charge was a rent charge
																				  INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID 
																												AND lit.IsRent = 1
																				  INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID	
																				  INNER JOIN #PropertiesAndDates #pad ON tar.PropertyID = #pad.PropertyID																			 
																				WHERE
																				  -- Make sure it is a reversal 
																				  pay.Amount < 0
																				  -- Payment was in the period
																				  AND tar.[TransactionDate] >= #pad.StartDate --@startDate
																				  AND tar.[TransactionDate] <= #pad.EndDate --@endDate
																				  -- Original charge was not in the period
																				  AND (t.TransactionDate < #pad.StartDate /*@startDate*/ OR t.TransactionDate > #pad.EndDate /*@endDate*/)
																				  -- Tie to the unit
																				  AND ulg.UnitID = #Units.UnitID), 0)
	
					
	IF (@hapLedgersExist = 1)
	BEGIN
		UPDATE #Units SET PriorRentPaid = ISNULL(PriorRentPaid, 0) + ISNULL((SELECT SUM(tar.Amount)
																			  FROM [Transaction] tar
																					INNER JOIN PaymentTransaction pt on pt.TransactionID = tar.TransactionID
																					INNER JOIN Payment pay on pay.PaymentID = pt.PaymentID
																				  -- Get the application to the rent
																				  INNER JOIN [Transaction] ta ON tar.ReversesTransactionID = ta.TransactionID
																				  -- Applied to a rent charge
																				  INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
																				  INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID 
																												AND tta.Name IN ('Payment')
																				 -- Make sure charge was a rent charge
																				  INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID 
																												AND lit.IsRent = 1
																				  INNER JOIN WOITAccount woit ON woit.WOITAccountID = t.ObjectID
																				  INNER JOIN UnitLeaseGroup ulg ON woit.BillingAccountID = ulg.UnitLeaseGroupID	
																				  INNER JOIN #PropertiesAndDates #pad ON tar.PropertyID = #pad.PropertyID																			 
																				WHERE
																				  -- Make sure it is a reversal 
																				  pay.Amount < 0
																				  -- Payment was in the period
																				  AND tar.[TransactionDate] >= #pad.StartDate --@startDate
																				  AND tar.[TransactionDate] <= #pad.EndDate --@endDate
																				  -- Original charge was not in the period
																				  AND (t.TransactionDate < #pad.StartDate /*@startDate*/ OR t.TransactionDate > #pad.EndDate /*@endDate*/)
																				  -- Tie to the unit
																				  AND ulg.UnitID = #Units.UnitID), 0)
	END
																			
	INSERT INTO #Activity
		SELECT b.PropertyID,
			   u.UnitID, 
			   l.LeaseID,
			   u.Number, 		   
			   (SELECT MIN(pl.MoveInDate) 
				FROM PersonLease pl 
				WHERE pl.LeaseID = l.LeaseID
					AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted')),
			   (SELECT MAX(pl.MoveOutDate) 
				FROM PersonLease pl 
				WHERE pl.LeaseID = l.LeaseID
					AND pl.ResidencyStatus IN ('Former', 'Evicted')
					AND pl.MoveOutDate IS NOT NULL
					AND l.LeaseStatus IN ('Former', 'Evicted'))			
		FROM Unit u
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitID = u.UnitID
			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted')
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = b.PropertyID

	-- Don't need anything where the MoveOutDate is before the period
	-- or the MoveInDate is after the period
	DELETE #act 
		FROM #Activity #act
			INNER JOIN #PropertiesAndDates #pad ON #act.PropertyID = #pad.PropertyID
	WHERE
		(MoveOutDate IS NOT NULL AND MoveOutDate < #pad.StartDate /*@startDate*/)
		OR (MoveInDate > #pad.EndDate /*@endDate*/)

	INSERT INTO #Vacancy 
		SELECT b.PropertyID, u.UnitID, u.Number, null, null, lit.GLAccountID
		FROM Unit u
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = b.PropertyID
			CROSS APPLY GetUnitStatusByUnitID(u.UnitID, #pad.StartDate /*@startDate*/) AS us
			INNER JOIN UnitStatus us2 ON us2.UnitStatusID = us.UnitStatusID
			INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = us2.StatusLedgerItemTypeID
			LEfT JOIN #Activity #a ON #a.UnitID = u.UnitID
		WHERE #a.UnitID IS NULL

	-- Don't need anything that was occupied during the whole date range
	DELETE #act 
		FROM #Activity #act
			INNER JOIN #PropertiesAndDates #pad ON #act.PropertyID = #pad.PropertyID
	WHERE 
		MoveInDate < #pad.StartDate /*@startDate*/ 
		AND (MoveOutDate IS NULL OR MoveOutDate >= #pad.EndDate /*@endDate*/)

	INSERT INTO #Vacancy
		SELECT #a.PropertyID, #a.UnitID, #a.Unit, #a.MoveInDate, #a.MoveOutDate, lit.GLAccountID
		FROM #Activity #a
			INNER JOIN #PropertiesAndDates #pad ON #a.PropertyID = #pad.PropertyID
			CROSS APPLY GetUnitStatusByUnitID(#a.UnitID, ISNULL(#a.MoveOutDate, #pad.EndDate /*@endDate*/)) us
			INNER JOIN UnitStatus us2 ON us2.UnitStatusID = us.UnitStatusID
			INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = us2.StatusLedgerItemTypeID	

	CREATE TABLE #Leases
	(
		UnitID uniqueidentifier,
		UnitLeaseGroupID uniqueidentifier,
		MoveInDate date,
		MoveOutDate date,
		NoMoveOut int
	)

	INSERT INTO #Leases
		--SELECT * FROM
		SELECT	Accounts.UnitID, Accounts.UnitLeaseGroupID, Accounts.MoveInDate, Accounts.MoveOutDate, Accounts.NoMoveOut
			FROM
				(SELECT ulg.UnitID,		
					ulg.UnitLeaseGroupID,	
					#pad.EndDate AS 'TheEndIsNear',						  
					MIN(pl.MoveInDate) AS 'MoveInDate', 
					MAX(pl.MoveOutDate) AS 'MoveOutDate',
					(SELECT COUNT(*) FROM PersonLease WHERE LeaseID = l.LeaseID AND MoveOutDate IS NULL) AS 'NoMoveOut'													 								  
				FROM Lease l
					INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID							   							   
					INNER JOIN Unit u ON u.UnitID = ulg.UnitID
					INNER JOIN Building b ON b.BuildingID = u.BuildingID
					INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID							   
					INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = b.PropertyID
				WHERE l.LeaseStatus IN ('Current', 'Former', 'Under Eviction', 'Evicted')
				  AND pl.ResidencyStatus IN ('Current',  'Former', 'Under Eviction', 'Evicted')																							
				GROUP BY ulg.UnitID, ulg.UnitLeaseGroupID, l.LeaseID, #pad.EndDate) AS Accounts
			WHERE MoveInDate <= Accounts.TheEndIsNear /*@endDate*/ AND (MoveOutDate IS NULL OR NoMoveOut > 0 OR MoveOutDate >= Accounts.TheEndIsNear /*@endDate*/)
			ORDER BY MoveInDate DESC

	UPDATE #Units SET UnitLeaseGroupID = (SELECT TOP 1 UnitLeaseGroupID
										  FROM #Leases
										  WHERE #Leases.UnitID = #units.UnitID
										  ORDER BY MoveInDate DESC)				


	INSERT INTO #Residents
		SELECT #units.UnitLeaseGroupID,
				l.LeaseID,
				l.LeaseStartDate,
				l.LeaseEndDate,
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						FROM Person 
							INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID							
						WHERE PersonLease.LeaseID = l.LeaseID
							AND PersonLease.MainContact = 1
						FOR XML PATH ('')), 1, 2, '') AS 'Name'
		FROM Lease l
			INNER JOIN #Units on #units.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN #PropertiesAndDates #pad ON #units.PropertyID = #pad.PropertyID
			WHERE  l.LeaseID = (SELECT TOP 1 l2.LeaseID
								 FROM Lease l2
								 WHERE l2.UnitLeaseGroupID = l.UnitLeaseGroupID
									AND l2.LeaseStartDate <= #pad.EndDate --@endDate
								 ORDER BY l2.LeaseStartDate DESC)						

	SELECT 
		#units.PropertyName, 
		#units.UnitID,
		#units.UnitNumber, 
		#units.UnitType,
		#Units.UnitTypeID,
		#units.SquareFeet,
		#Units.UnitTypeSquareFeet,
		#Residents.Residents,
		#Residents.LeaseID,
		#Residents.LeaseStartDate,
		#Residents.LeaseEndDate,
		#units.MarketRent, 
		--LossToLease, 
		--GainToLease, 
		#units.ActualRent, 
		--VacancyLoss,
		#units.Credits,
		#units.RentCollected,
		#units.RentDelinquency,
		#units.PriorRentPaid
	FROM #Units 
		LEFT JOIN #Residents ON #Residents.UnitLeaseGroupID = #units.UnitLeaseGroupID
	ORDER BY PaddedNumber
	
	SELECT #v.*,  #ua.MarketRent, p.Name AS 'PropertyName', gl.Number AS 'VacancyLossGLAccountNumber', gl.Name AS 'VacancyLossGLAccountName'
	FROM #Vacancy #v
		INNER JOIN #UnitAmenities #ua ON #ua.UnitID = #v.UnitID
		INNER JOIN Property p ON p.PropertyID = #v.PropertyID
		INNER JOIN GLAccount gl ON gl.GLAccountID = #v.VacancyLossGLAccountID

	SELECT
			#dude.UnitNumber, #dude.UnitID, #dude.Amount, #dude.GLAccountID, 
			#dude.GLAccountNumber, #dude.GLAccountName, #dude.AccountingBasis,
			#u.PaddedNumber, p.Name AS 'PropertyName'
		FROM #Units #u
			LEFT JOIN #Deductions #dude ON #u.UnitID = #dude.UnitID
			INNER JOIN Unit u ON u.UnitID = #u.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN Property p ON p.PropertyID = b.PropertyID
		WHERE #dude.Amount <> 0
		ORDER BY #u.PaddedNumber

	SELECT	#cred.GLAccountID,
			p.Name AS 'PropertyName',
			gla.Number AS 'GLAccountNumber',
			gla.Name AS 'GLAccountName',
			u.Number AS 'UnitNumber',
			#cred.UnitLeaseGroupID AS 'ObjectID',
			STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						FROM Person 
							INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID							
						WHERE PersonLease.LeaseID = l.LeaseID
							AND PersonLease.MainContact = 1
						FOR XML PATH ('')), 1, 2, '') AS 'Residents',
			#cred.Amount
		FROM #Credits #cred
			INNER JOIN GLAccount gla ON #cred.GLAccountID = gla.GLAccountID
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = #cred.UnitLeaseGroupID
			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON #cred.UnitID = u.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN Property p ON p.PropertyID = b.PropertyID
			INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
		WHERE  l.LeaseID = (SELECT TOP 1 l2.LeaseID
								 FROM Lease l2
								 WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
									AND l2.LeaseStartDate <= #pad.EndDate --@endDate
								 ORDER BY l2.LeaseStartDate DESC)					

END
GO
