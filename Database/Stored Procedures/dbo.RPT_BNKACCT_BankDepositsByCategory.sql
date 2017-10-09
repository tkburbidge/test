SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE PROCEDURE [dbo].[RPT_BNKACCT_BankDepositsByCategory]
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@startDate date,
	@endDate date,
	@accountingPeriodID uniqueidentifier
AS
BEGIN
	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs
	CREATE TABLE #BatchIDs ( BatchID uniqueidentifier, Number int, BankAccountID uniqueidentifier)

	CREATE TABLE #Applications
	(
		PropertyID uniqueidentifier,
		BankAccountID uniqueidentifier,	
		Deposits money,
		[Returns] money,
		Category nvarchar(100),
		GLNumber nvarchar(100),
		GLName nvarchar(100)	
	)

	-- Get all the bank deposits for the date range and for the bank accounts
	-- associated with the properties passed in
	INSERT INTO #BatchIDs
		SELECT DISTINCT b.BatchID, b.Number, t.ObjectID
		FROM BankTransaction bt
		INNER JOIN BankTransactionTransaction btt ON btt.BankTransactionID = bt.BankTransactionID
		INNER JOIN Batch b ON b.BankTransactionID = bt.BankTransactionID
		INNER JOIN [Transaction] t ON t.TransactionID = btt.TransactionID	
		--INNER JOIN BankAccountProperty bap ON t.ObjectID = bap.BankAccountID	
		INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
		LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE bt.AccountID = @accountID
		--AND t.TransactionDate >= @startDate 
		--AND t.TransactionDate <= @endDate
		AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate >= @startDate) AND (t.TransactionDate <= @endDate))
				  OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate >= pap.StartDate) AND (t.TransactionDate <= pap.EndDate)))

	INSERT INTO #Applications
		SELECT PropertyID,
				BankAccountID,
				SUM(Amount) AS [Deposits],
				0 AS [Returns],
				ChargeLedgerItemTypeName,
				Number,
				Name			
		FROM
			(SELECT DISTINCT
				ta.PropertyID,
				ta.TransactionID,
				#b.BankAccountID,
				ta.Amount,	
				CASE
					-- If the origin is 'T' then it was a transferred payment and we want to report is as such
					WHEN (ta.Origin = 'T') THEN 'Transferred'
					-- If a deposit and the LedgerItemType is null then set the name to the applied Ledger Item Type
					WHEN ((tta.Name = 'Deposit') AND (lit.Name IS NULL)) THEN lita.Name					
					-- Report prepayments
					WHEN (tta.Name = 'Payment') AND (ta.AppliesToTransactionID IS NULL) THEN 'Prepayment'
					-- Show balance transfers
					WHEN (tta.Name IN ('Balance Transfer Deposit', 'Balance Transfer Payment')) THEN 'Balance Transfer'
					-- Show deposit applications
					WHEN (tta.Name IN ('Deposit Applied to Balance', 'Deposit Applied to Deposit')) THEN 'Deposit Application'
					ELSE lit.Name END AS 'ChargeLedgerItemTypeName',				
				COALESCE(gl.Number, gla.Number) AS [Number], 
				--gl.Number,
				gl.Name		
			FROM Payment pay
				INNER JOIN #BatchIDs #b ON #b.BatchID = pay.BatchID
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] ta ON pt.TransactionID = ta.TransactionID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = ta.PropertyID
				INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name NOT IN ('Prepayment', 'Balance Transfer Payment', 'Deposit Applied to Balance', 'Payment Refund')
				LEFT JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
				LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN GLAccount gl ON lit.GLAccountID = gl.GLAccountID				
				LEFT JOIN LedgerItemType lita ON ta.LedgerItemTypeID = lita.LedgerItemTypeID
				LEFT JOIN GLAccount gla ON lita.GLAccountID = gla.GLAccountID
			WHERE
				pay.[Type] NOT IN ('NSF', 'Credit Card Recapture') -- Don't pull out NSF or CCR here
				AND tar.TransactionID IS NULL
				AND ta.ReversesTransactionID IS NULL
				) t
		GROUP BY PropertyID, BankAccountID, Number, Name, ChargeLedgerItemTypeName
				
				--AND ta.Amount > 0			
				
	INSERT INTO #Applications
		SELECT PropertyID,
				BankAccountID,
				0 AS [Deposits],
				SUM(Amount) AS [Returns],
				ChargeLedgerItemTypeName,
				Number,
				Name			
		FROM
			(SELECT DISTINCT
				tr.PropertyID,
				tr.TransactionID,
				depTran.ObjectID AS 'BankAccountID',
				tr.Amount,
				CASE
					-- If the origin is 'T' then it was a transferred payment and we want to report is as such
					WHEN (ta.Origin = 'T') THEN 'Transferred'
					-- If a deposit and the LedgerItemType is null then set the name to the applied Ledger Item Type
					WHEN ((tta.Name = 'Deposit') AND (lit.Name IS NULL)) THEN lita.Name					
					-- Report prepayments
					WHEN (tta.Name = 'Payment') AND (ta.AppliesToTransactionID IS NULL) THEN 'Prepayment'
					-- Show balance transfers
					WHEN (tta.Name IN ('Balance Transfer Deposit', 'Balance Transfer Payment')) THEN 'Balance Transfer'
					-- Show deposit applications
					WHEN (tta.Name IN ('Deposit Applied to Balance', 'Deposit Applied to Deposit')) THEN 'Deposit Application'
					ELSE lit.Name END AS 'ChargeLedgerItemTypeName',
					gl.Number, 
					gl.Name	
			FROM Payment pay
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] tr ON pt.TransactionID = tr.TransactionID
				INNER JOIN [Transaction] ta ON ta.TransactionID = tr.ReversesTransactionID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = ta.PropertyID
				INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name NOT IN ('Prepayment', 'Balance Transfer Payment', 'Deposit Applied to Balance')

				-- Charge it was applied to
				LEFT JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID	
				LEFT JOIN GLAccount gl ON lit.GLAccountID = gl.GLAccountID
				LEFT JOIN LedgerItemType lita ON ta.LedgerItemTypeID = lita.LedgerItemTypeID

				INNER JOIN BankTransaction bt ON pay.PaymentID = bt.ObjectID
				INNER JOIN Batch b ON pay.BatchID = b.BatchID
				INNER JOIN BankTransactionTransaction btt ON b.BankTransactionID = btt.BankTransactionID
				INNER JOIN [Transaction] depTran ON btt.TransactionID = depTran.TransactionID
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE pay.[Type] IN ('NSF', 'Credit Card Recapture')	
				AND pay.Amount < 0
				--AND pay.[Date] >= @startDate
				--AND pay.[Date] <= @endDate) t
				AND (((@accountingPeriodID IS NULL) AND (pay.[Date] >= @startDate) AND (pay.[Date] <= @endDate))
				  OR ((@accountingPeriodID IS NOT NULL) AND (pay.[Date] >= pap.StartDate) AND (pay.[Date] <= pap.EndDate)))
				) t
		GROUP BY PropertyID, BankAccountID, Number, Name, ChargeLedgerItemTypeName		
				
	-- Get payment refunds
	INSERT INTO #Applications						 			
		SELECT
			pr.PropertyID,
			#b.BankAccountID,
			SUM(-pr.Amount),
			0,
			'Payment Refund',
			null,
			null
		FROM Payment pay
		INNER JOIN #BatchIDs #b ON #b.BatchID = pay.BatchID
			INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] ta ON pt.TransactionID = ta.TransactionID
			INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID --AND tta.Name IN ('Prepayment')
			INNER JOIN [Transaction] pr ON pr.AppliesToTransactionID = ta.TransactionID
			INNER JOIN [TransactionType] prta on prta.TransactionTypeID = pr.TransactionTypeID AND prta.Name = 'Payment Refund'
			LEFT JOIN [Transaction] prrt ON prrt.ReversesTransactionID = pr.TransactionID		
		WHERE prrt.TransactionID IS NULL	
		GROUP BY pr.PropertyID, #b.BankAccountID			
		

	UPDATE #Applications SET GLNumber = '', GLName = '' WHERE Category IN ('Prepayment', 'Balance Transfer', 'Deposit Application', 'Transferred')

	SELECT
		p.PropertyID,
		p.Name AS 'PropertyName',
		ba.AccountName AS 'BankAccountName',
		ba.AccountNumberDisplay AS 'BankAccountNumber',
		gl.Number AS 'BankGLNumber', 
		#a.Category,
		#a.GLNumber AS 'CategoryGLNumber',
		#a.GLName AS 'CategoryGLName', 
		-- We are not including reversals in the original calculation so add them back in here
		(ISNULL(SUM(ISNULL(#a.Deposits, 0)), 0) -ISNULL(SUM(ISNULL(#a.[Returns], 0)), 0)) AS 'Deposits',
		ISNULL(SUM(ISNULL(#a.[Returns], 0)), 0) AS 'Returns'
	FROM #Applications #a
	INNER JOIN BankAccount ba ON ba.BankAccountID = #a.BankAccountID
	INNER JOIN GLAccount gl ON gl.GLAccountID = ba.GLAccountID
	INNER JOIN Property p ON p.PropertyID = #a.PropertyID
	GROUP BY p.PropertyID, p.Name, ba.BankAccountID, ba.AccountName, ba.AccountNumberDisplay, gl.Number, #a.Category, #a.GLNumber, #a.GLName
	ORDER BY #a.Category
					
						 		
END
GO
