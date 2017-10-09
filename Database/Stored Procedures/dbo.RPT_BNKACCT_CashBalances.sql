SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Apr 16, 2014
-- Description:	Gets a list of items for a Bank Ledger
-- =============================================
CREATE PROCEDURE [dbo].[RPT_BNKACCT_CashBalances] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@startDate date = null,
	@endDate date = null,
	@basis nvarchar(10) = null,
	@groupByProperty bit = 0,
	@accountingPeriodID uniqueidentifier = null	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #BankTransactionLedgerTable (
		ObjectID uniqueidentifier NOT NULL,
		BankTransactionID uniqueidentifier NOT NULL,
		PropertyID uniqueidentifier NOT NULL,
		BankAccountID uniqueidentifier NULL,
		[Date] date NULL,
		[Type] nvarchar(20) NULL,
		--[Group] nvarchar(20) NULL,
		--TransactionType nvarchar(50) NULL,
		--Reference nvarchar(50) NULL,
		--ClearedDate date NULL,
		--BankReconciliationID uniqueidentifier NULL,
		--[Description] nvarchar(500) NULL,
		Amount money NULL,
		--CheckVoidedDate date NULL,
		IsAddition bit NULL,
		--BTimeStamp datetime NULL,
		--Category nvarchar(50) NULL,
		--BankFileID nvarchar(100) NULL,
		--IsVoidingTransaction bit null
		)
		
	CREATE TABLE #MyUnPaidInvoices (
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
			
	CREATE TABLE #BankAccountBeginningBalance (
		BankAccountID uniqueidentifier NOT NULL,
		GLAccountID uniqueidentifier NOT NULL,
		PropertyID uniqueidentifier NOT NULL,
		BeginningBalance money NULL,
		EndingBalance money NULL)
		
	CREATE TABLE #CashBalance (
		PropertyID uniqueidentifier NOT NULL,
		--PropertyName nvarchar(50) NULL,
		--AccountNumber nvarchar(50) NULL,
		--AccountName nvarchar(50) NULL,
		BankAccountID uniqueidentifier NOT NULL,
		BeginningBalance money NULL,
		Debits money NULL,
		Credits money NULL,
		Adjustments money NULL,
		AccountsPayableBalance money NULL)
	
	CREATE TABLE #PropertyIDs(
		PropertyID uniqueidentifier NOT NULL
	)
	
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate [Date] NOT NULL,
		EndDate [Date] NOT NULL)

	-- If they want to see property specific balances then we need to
	-- only get transactions for the specified properties.
	-- Otherwise if they want to see the bank account balances regardless
	-- of the property if the bank is shared, then we need to get all the
	-- transactions from all properties associated with the bank accounts
	-- assocaited with the PropertyIDs passed in.
	IF (@groupByProperty = 1)
	BEGIN
		INSERT INTO #PropertyIDs SELECT DISTINCT Value FROM @propertyIDs
	END
	ELSE
	BEGIN
		INSERT INTO #PropertyIDs
			SELECT DISTINCT bap.PropertyID 
			FROM BankAccountProperty bap
			WHERE bap.BankAccountID IN (SELECT bap2.BankAccountID 
									    FROM BankAccountProperty bap2
										WHERE bap2.PropertyID IN (SELECT Value FROM @propertyIDs))				
	END
	
	INSERT #PropertiesAndDates
		SELECT	#p.PropertyID, pap.StartDate, pap.EndDate
			FROM #PropertyIDs #p
				INNER JOIN PropertyAccountingPeriod pap ON #p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	--DECLARE @statementEndDate date
	--IF (@reconciliationID IS NOT NULL)
	--BEGIN
	--	SET @statementEndDate = (SELECT TOP 1 StatementDate FROM BankAccountReconciliation WHERE BankAccountReconciliationID = @reconciliationID)
	--END
	
	INSERT #BankAccountBeginningBalance
		SELECT bap.BankAccountID, ba.GLAccountID, bap.PropertyID, 0.00, 0.00
			FROM BankAccountProperty bap
			INNER JOIN BankAccount ba ON ba.BankAccountID = bap.BankAccountID
			INNER JOIN #PropertyIDs #p ON #p.PropertyID = bap.PropertyID	

	-- Delete any bank accounts that might have slipped in that 
	-- are not at all associated with the properties we need to return
	DELETE #ba	
	FROM #BankAccountBeginningBalance #ba	
	WHERE (SELECT COUNT(*) 
			FROM BankAccountProperty bap
			WHERE bap.BankAccountID = #ba.BankAccountID
			AND bap.PropertyID IN (SELECT Value FROM @propertyIDs)) = 0	 	

--	DELETE FROM #BankAccountBeginningBalance WHERE BankAccountID <> '715e7e05-5a82-4f44-b396-4182ff20b806'							
	
	-- Bank Transactions tied to BankTransactionTransaction table (system  bank deposits)
	INSERT #BankTransactionLedgerTable
	  	SELECT	 				
				bt.BankTransactionID AS 'ObjectID',				
				bt.BankTransactionID,
				#ba.PropertyID,
				#ba.BankAccountID,
				CAST(t.[TransactionDate] AS Date) AS 'Date',
				'DEP' AS 'Type',				
				--tt.[Group],
				--tt.Name AS 'TransactionType',
				--bt.ReferenceNumber as 'Reference', 
				--bt.ClearedDate,
				--bt.BankReconciliationID,
				--MIN(t.[Description]) AS 'Description',	
				SUM(t.Amount) AS 'Amount',				 
				--NULL,
				CAST(1 AS bit) AS 'IsAddition'
				--MIN(t.[TimeStamp]) AS 'BTimeStamp',	
				--btc.Category AS 'Category',
				--bt.BankFileID,
				--CAST(0 AS BIT) AS 'IsVoidingTransaction'
		FROM BankTransaction bt						
			INNER JOIN BankTransactionTransaction btt ON bt.BankTransactionID = btt.BankTransactionID
			INNER JOIN [Transaction] t ON btt.TransactionID = t.TransactionID
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID				
			INNER JOIN #BankAccountBeginningBalance #ba ON #ba.PropertyID = t.PropertyID AND t.ObjectID = #ba.BankAccountID		

			INNER JOIN JournalEntry je ON t.TransactionID = je.TransactionID AND je.GLAccountID = #ba.GLAccountID AND je.AccountingBasis = @basis
			LEFT JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID						
		WHERE t.AccountID = @accountID		  
		  AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate <= @endDate))
		    OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate <= #pad.EndDate)))
		  --AND t.ObjectID = @bankAccountID
		  AND t.IsDeleted = 0		  
		  AND ((t.ReversesTransactionID IS NULL))
		  --AND (((@type IS NULL) AND (((tt.[Group] = 'Bank') AND (tt.Name in ('Deposit')))	-- Only get bank deposits
				--						OR ((tt.[Group] = 'Bank') AND (tt.Name = @type))))
		  AND ((tt.[Group] = 'Bank') AND tt.Name in ('Deposit'))
		  --AND ((@reconciliationID IS NULL) OR ((bt.BankReconciliationID IS NULL) OR (bt.BankReconciliationID = @reconciliationID))))
		GROUP BY bt.BankTransactionID, bt.BankTransactionID, t.[TransactionDate], tt.[Group], tt.Name, bt.ReferenceNumber, ClearedDate, BankReconciliationID, 
				  bt.BankFileID, #ba.PropertyID, #ba.BankAccountID

	-- Bank Transactions tied to the Payment table
	INSERT #BankTransactionLedgerTable	
		SELECT	 
				t.TransactionID,
				bt.BankTransactionID,
				#ba.PropertyID,
				CASE 
					WHEN (bap.BankAccountPropertyID IS NOT NULL) THEN ba.BankAccountID
					WHEN (bap2.BankAccountPropertyID IS NOT NULL) THEN ba2.BankAccountID
					END AS 'BankAccountID', 
				CAST(p.[Date] AS Date) AS 'Date',
				CASE 
					WHEN tt.Name = 'Adjustment'				
						THEN 'ADJ'
					WHEN tt.Name IN ('Check', 'Vendor Credit') AND tt.[Group] = 'Bank'
						THEN 'VND'
					WHEN tt.Name IN ('Payment', 'Deposit') AND tt.[Group] NOT IN ('Invoice') AND p.[Type] = 'NSF'
						THEN 'NSF-XX'
					WHEN tt.Name IN ('Payment', 'Deposit') AND tt.[Group] NOT IN ('Invoice') AND p.[Type] = 'Credit Card Recapture'
						THEN 'CCR'						
					WHEN tt.Name = 'Deposit'										
						THEN 'DEP'
					WHEN (tt.Name = 'Payment' AND tt.[Group] = 'Invoice') OR
						 (tt.Name = 'Refund' AND tt.[Group] = 'Bank')
						THEN 
							(CASE p.[Type] 
								WHEN 'Check'				THEN 'CHK'
								WHEN 'Money Order'			THEN 'MO'
								WHEN 'Cashiers Check'		THEN 'CCK'
								WHEN 'Debit Card'			THEN 'DBT'
								WHEN 'EFT'					THEN 'EFT'
								WHEN 'Cash'					THEN 'CSH'
								WHEN 'Credit Card'			THEN 'CC'
								END)
					WHEN tt.Name = 'Transfer'					
						THEN 'TRX'
					WHEN tt.Name = 'Withdrawal'				
						THEN 'WDL'					
					END AS [Type],
				--tt.[Group],
				--tt.Name AS 'TransactionType',
				--bt.ReferenceNumber as 'Reference', 
				--bt.ClearedDate,
				--bt.BankReconciliationID,
				--p.ReceivedFromPaidTo AS 'Description',			
				-- Negative actually really doesn't matter as we absolute value everything at the end
				-je.Amount AS 'Amount',				
				--p.ReversedDate AS 'CheckVoidedDate',
				CASE 
					-- if this is an invoice payment that was a debit then we are paying off
					-- a credit invoice and it actually increases cash balance
					WHEN (je.Amount > 0 AND tt.Name = 'Payment' AND tt.[Group] = 'Invoice') THEN CAST(1 AS BIT)
					WHEN (p.Amount > 0 AND tt.Name NOT IN ('Payment', 'Check', 'Withdrawal', 'Refund')) THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
					END	AS 'IsAddition'
				--p.[TimeStamp] AS 'BTimeStamp',
				--btc.Category AS 'Category',
				--bt.BankFileID,
				--CAST(0 AS BIT) AS 'IsVoidingTransaction'
		FROM BankTransaction bt
			INNER JOIN Payment p ON p.PaymentID = bt.ObjectID 
			INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID 
			INNER JOIN #BankAccountBeginningBalance #ba ON #ba.PropertyID = t.PropertyID
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN JournalEntry je ON t.TransactionID = je.TransactionID AND je.AccountingBasis = @basis						
			LEFT JOIN Batch batch on p.BatchID = batch.BatchID
			LEFT JOIN [BankTransactionTransaction] btt on btt.BankTransactionID = batch.BankTransactionID
			LEFT JOIN [Transaction] batTran ON batTran.TransactionID = btt.TransactionID AND batTran.PropertyID = t.PropertyID	
			LEFT JOIN BankAccount ba ON batTran.ObjectID = ba.BankAccountID AND je.GLAccountID = ba.GLAccountID
			LEFT JOIN BankAccount ba2 ON batch.BatchID IS NULL AND t.ObjectID = ba2.BankAccountID 
											AND ba2.GLAccountID = je.GLAccountID 
			LEFT JOIN BankAccountProperty bap ON ba.BankAccountID = bap.BankAccountID AND batTran.PropertyID = bap.PropertyID
			LEFT JOIN BankAccountProperty bap2 ON ba2.BankAccountID = bap2.BankAccountID AND t.PropertyID = bap2.PropertyID
			LEFT JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
		WHERE t.AccountID = @accountID
		  --AND t.TransactionDate >= @startDate
		  AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate <= @endDate))
		    OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate <= #pad.EndDate)))
		  --AND ((t.ObjectID = @bankAccountID) OR (batTran.ObjectID = @bankAccountID))
		  AND ((bap.BankAccountPropertyID IS NOT NULL) OR (bap2.BankAccountPropertyID IS NOT NULL))
		  AND ((bap.BankAccountID = #ba.BankAccountID) OR (bap2.BankAccountID = #ba.BankAccountID))
		  AND tt.Name NOT IN ('Balance Transfer Deposit', 'Balance Transfer Payment', 'Deposit Applied to Deposit', 'Deposit Applied to Balance')
		  AND t.IsDeleted = 0
		  -- Get the NSF and Credit Card Recapture transactions.  The last condition here takes care of scenarios wehre
		  -- a deposit is applied to the balance but then that deposit is then reversed as an NSF.  In this scenario there
		  -- will be a transaction of type Payment and Seposit but the payment won't have a LedgerItemTypeID
		  AND ((t.ReversesTransactionID IS NULL) OR ((p.PaidOut = 0) AND (p.[Type] IN ('NSF', 'Credit Card Recapture')) AND (t.LedgerItemTypeID IS NOT NULL)))
		  AND ((/*(@type IS NULL) AND*/ (((tt.[Group] = 'Bank') AND (tt.Name in ('Adjustment', 'Check', 'Deposit', 'Transfer', 'Withdrawal', 'Refund', 'Vendor Credit')))	-- Get all bank transactions
									   OR ((p.PaidOut = 0) AND (p.[Type] = 'NSF'))																	-- Get all nsf checks
									   OR ([Group] = 'Invoice' AND (tt.Name = 'Payment'))
									   OR ((p.PaidOut = 0) AND (p.[Type] = 'Credit Card Recapture')))															-- Get all invoice payments	
									  /* OR ((tt.[Group] = 'Bank') AND (tt.Name = @type))*/ ))		  
	
	-- Voided checks
	INSERT #BankTransactionLedgerTable	
		  SELECT 
				t.TransactionID,
				bt.BankTransactionID,
				t.PropertyID,
				t.ObjectID AS 'BankAccountID', 
				CAST(p.ReversedDate AS Date) AS 'Date',
				CASE 
					WHEN tt.Name = 'Adjustment'				
						THEN 'ADJ'
					WHEN tt.Name IN ('Check', 'Vendor Credit') AND tt.[Group] = 'Bank'
						THEN 'VND'
					WHEN tt.Name IN ('Payment', 'Deposit') AND tt.[Group] NOT IN ('Invoice') AND p.[Type] = 'NSF'
						THEN 'NSF'
					WHEN tt.Name IN ('Payment', 'Deposit') AND tt.[Group] NOT IN ('Invoice') AND p.[Type] = 'Credit Card Recapture'
						THEN 'CCR'						
					WHEN tt.Name = 'Deposit'										
						THEN 'DEP'
					WHEN (tt.Name = 'Payment' AND tt.[Group] = 'Invoice') OR
						 (tt.Name = 'Refund' AND tt.[Group] = 'Bank')
						THEN 
							(CASE p.[Type] 
								WHEN 'Check'				THEN 'CHK'
								WHEN 'Money Order'			THEN 'MO'
								WHEN 'Cashiers Check'		THEN 'CCK'
								WHEN 'Debit Card'			THEN 'DBT'
								WHEN 'EFT'					THEN 'EFT'
								WHEN 'Cash'					THEN 'CSH'
								WHEN 'Credit Card'			THEN 'CC'
								END)
					WHEN tt.Name = 'Transfer'					
						THEN 'TRX'
					WHEN tt.Name = 'Withdrawal'				
						THEN 'WDL'					
					END AS [Type],
				--tt.[Group],
				--tt.Name AS 'TransactionType',
				--bt.ReferenceNumber as 'Reference', 
				--bt.ClearedDate,
				--bt.BankReconciliationID,
				--p.ReceivedFromPaidTo AS 'Description',
				je.Amount AS 'Amount',				
				--null AS 'CheckVoidedDate',
				(CASE WHEN tt.Name = 'Vendor Credit' THEN CAST(0 AS BIT)
					-- if this is an invoice payment that was a credit then we are voiding
					-- a credit invoice and it actually increases decreases balance
					WHEN (je.Amount < 0 AND tt.Name = 'Payment' AND tt.[Group] = 'Invoice') THEN CAST(0 AS BIT)
				 ELSE CAST(1 AS BIT)
				 END) 'IsAddition'
				--p.[TimeStamp] AS 'BTimeStamp',
				--btc.Category AS 'Category',
				--bt.BankFileID,
				--CAST(1 AS BIT) AS 'IsVoidingTransaction'
		FROM BankTransaction bt
			INNER JOIN Payment p ON p.PaymentID = bt.ObjectID 
			INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			INNER JOIN #BankAccountBeginningBalance #ba ON #ba.PropertyID = t.PropertyID AND #ba.BankAccountID = t.ObjectID			
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID				
			INNER JOIN JournalEntry je ON t.TransactionID = je.TransactionID AND je.AccountingBasis = @basis AND je.GLAccountID = #ba.GLAccountID	
			LEFT JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID	
		WHERE t.AccountID = @accountID
		  AND p.ReversedDate IS NOT NULL
		  --AND p.ReversedDate >= @startDate
		  --AND p.ReversedDate <= @endDate
		  AND (((@accountingPeriodID IS NULL) AND (p.ReversedDate <= @endDate))
		    OR ((@accountingPeriodID IS NOT NULL) AND (p.ReversedDate <= #pad.EndDate)))		  
		  --AND t.ObjectID = @bankAccountID
		  AND t.IsDeleted = 0		 
		  AND t.ReversesTransactionID IS NOT NULL
		  AND (/*(@type IS NULL) AND */ (((tt.[Group] = 'Bank') AND (tt.Name in ('Check', 'Refund', 'Vendor Credit')))	
									   OR ([Group] = 'Invoice' AND (tt.Name = 'Payment'))									   
									/*	OR ((tt.[Group] = 'Bank') AND (tt.Name = @type))*/))
		  --AND ((@reconciliationID IS NULL) OR ((bt.BankReconciliationID IS NULL) OR (bt.BankReconciliationID = @reconciliationID)))
		  ---- Do not include voided checks when we are requesting for a given reconciliation
		  --AND ((@reconciliationID IS NULL) OR (p.ReversedDate IS NULL) OR (p.[Date] > @statementEndDate AND p.[ReversedDate] <= @statementEndDate))			  



	-- Bank Transactions tied to Transaction table
	INSERT #BankTransactionLedgerTable	
		  SELECT DISTINCT 
				CASE WHEN tg.TransactionGroupID IS NOT NULL THEN tg.TransactionGroupID
					 ELSE bt.ObjectID
				END AS 'ObjectID',				
				bt.BankTransactionID,
				prop.PropertyID,
				t.ObjectID, 
				CAST(t.[TransactionDate] AS Date) AS 'Date',
				CASE 
					WHEN tt.Name = 'Adjustment'				
						THEN 'ADJ'
					WHEN tt.Name = 'Check' AND tt.[Group] = 'Bank'
						THEN 'MCHK'
					WHEN tt.Name = 'Deposit'										
						THEN 'DEP'				
					WHEN tt.Name = 'Transfer'					
						THEN 'TRX'
					WHEN tt.Name = 'Withdrawal'				
						THEN 'WDL'
					WHEN tt.Name = 'Cash'
						THEN 'JE'
					END AS [Type],
				--tt.[Group],
				--tt.Name AS 'TransactionType',
				--bt.ReferenceNumber as 'Reference', 
				--bt.ClearedDate,
				--bt.BankReconciliationID,
				--t.[Description] AS 'Description',				
				t.Amount AS 'Amount',				
				--NULL,
				CASE 
					WHEN (t.Amount > 0 AND tt.Name NOT IN ('Payment', 'Check', 'Withdrawal'))
						THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
					END	AS 'IsAddition'
				--t.[TimeStamp] AS 'BTimeStamp',				
				--btc.Category AS 'Category',
				--bt.BankFileID,
				--CAST(0 AS BIT) AS 'IsVoidingTransaction'
		FROM BankTransaction bt			
			INNER JOIN [Transaction] t ON bt.ObjectID = t.TransactionID
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN [Property] prop ON t.PropertyID = prop.PropertyID
			INNER JOIN BankTransactionCategory btc on btc.BankTransactionCategoryID = bt.BankTransactionCategoryID	
			INNER JOIN BankAccountProperty bap ON t.ObjectID = bap.BankAccountID AND t.PropertyID = bap.PropertyID	
			INNER JOIN #BankAccountBeginningBalance #ba ON #ba.PropertyID = t.PropertyID AND #ba.BankAccountID = t.ObjectID			
			INNER JOIN JournalEntry je ON t.TransactionID = je.TransactionID AND je.GLAccountID = #ba.GLAccountID AND je.AccountingBasis = @basis								
			LEFT JOIN [TransactionGroup] tg ON tg.TransactionID = t.TransactionID
			LEFT JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
		WHERE t.AccountID = @accountID
		  --AND t.TransactionDate >= @startDate
		  AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate <= @endDate))
		    OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate <= #pad.EndDate)))
		  --AND t.ObjectID = @bankAccountID
		  AND t.IsDeleted = 0
		  AND tt.Name NOT IN ('Balance Transfer Deposit', 'Balance Transfer Payment', 'Deposit Applied to Deposit', 'Deposit Applied to Balance')
		  AND ((t.ReversesTransactionID IS NULL))
		  AND (((( (tt.Name in ('Adjustment', 'Check', 'Deposit', 'Transfer', 'Withdrawal', 'Refund')))	-- Get all bank transactions									   
									   OR (tt.[Group] = 'Invoice' AND (tt.Name = 'Payment'))							   
										--OR ((tt.[Group] = 'Bank') AND (tt.Name = @type))
										OR (tt.[Group] = 'Journal Entry' AND tt.Name = 'Cash'))))
		  --AND ((@reconciliationID IS NULL) OR ((bt.BankReconciliationID IS NULL) OR (bt.BankReconciliationID = @reconciliationID))))
		  
	INSERT #MyUnPaidInvoices EXEC RPT_INV_UnpaidInvoices @propertyIDs, @endDate, null, 0, @accountingPeriodID		
	UPDATE #MyUnPaidInvoices SET Total = -Total, AmountPaid = -AmountPaid WHERE Credit = 1
	
	-- Get the Beginning Balance for every account that has transactions! Hence, < @startDate	
	UPDATE #ba
	SET #ba.BeginningBalance = (SELECT ISNULL(SUM(CASE WHEN #btlt.IsAddition = 1 THEN ABS(Amount)
													   WHEN #btlt.IsAddition = 0 THEN -ABS(Amount)							
												  END), 0)
								FROM #BankTransactionLedgerTable #btlt
									LEFT JOIN PropertyAccountingPeriod pap ON #btlt.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
								WHERE #btlt.BankAccountID = #ba.BankAccountID
									AND #btlt.PropertyID = #ba.PropertyID
									AND (((@accountingPeriodID IS NULL) AND (#btlt.[Date] < @startDate))
									  OR ((@accountingPeriodID IS NOT NULL) AND (#btlt.[Date] < pap.StartDate))))
	FROM #BankAccountBeginningBalance #ba			

-- Old Transactions have now served their purpose													  
	DELETE #CashBalance
		
-- Get current real transactions
	INSERT #CashBalance
		SELECT	prop.PropertyID,
				ba.BankAccountID,
				0.00 AS 'BeginningBalance',
				(SELECT ISNULL(SUM(ABS(Amount)), 0)
					FROM #BankTransactionLedgerTable #btlt1
						LEFT JOIN #PropertiesAndDates #pad ON #btlt1.PropertyID = #pad.PropertyID
					WHERE IsAddition = 1
					  AND [Type] NOT IN ('JE')
					  AND BankAccountID = #btlt.BankAccountID
					  AND #btlt1.PropertyID = #btlt.PropertyID
					  AND (((@accountingPeriodID IS NULL) AND ([Date] >= @startDate))
					    OR ((@accountingPeriodID IS NOT NULL) AND ([Date] >= #pad.StartDate)))) AS 'Debits',
				(SELECT ISNULL(SUM(ABS(Amount)), 0)
					FROM #BankTransactionLedgerTable #btlt1
						LEFT JOIN #PropertiesAndDates #pad ON #btlt1.PropertyID = #pad.PropertyID
					WHERE IsAddition = 0
					  AND [Type] NOT IN ('JE')
					  AND BankAccountID = #btlt.BankAccountID
					  AND #btlt1.PropertyID = #btlt.PropertyID
					  AND (((@accountingPeriodID IS NULL) AND ([Date] >= @startDate))
					    OR ((@accountingPeriodID IS NOT NULL) AND ([Date] >= #pad.StartDate)))) AS 'Credits',
				((SELECT ISNULL(SUM(ABS(Amount)), 0)
					FROM #BankTransactionLedgerTable #btlt1
						LEFT JOIN #PropertiesAndDates #pad ON #btlt1.PropertyID = #pad.PropertyID
					WHERE IsAddition = 1
					  AND [Type] IN ('JE')
					  AND BankAccountID = #btlt.BankAccountID
					  AND #btlt1.PropertyID = #btlt.PropertyID
					  AND (((@accountingPeriodID IS NULL) AND ([Date] >= @startDate))
					    OR ((@accountingPeriodID IS NOT NULL) AND ([Date] >= #pad.StartDate)))) -
				(SELECT ISNULL(SUM(ABS(Amount)), 0)
					FROM #BankTransactionLedgerTable #btlt1
						LEFT JOIN #PropertiesAndDates #pad ON #btlt1.PropertyID = #pad.PropertyID
					WHERE IsAddition = 0
					  AND [Type] IN ('JE')
					  AND BankAccountID = #btlt.BankAccountID
					  AND #btlt1.PropertyID = #btlt.PropertyID
					  AND (((@accountingPeriodID IS NULL) AND ([Date] >= @startDate))
					    OR ((@accountingPeriodID IS NOT NULL) AND ([Date] >= #pad.StartDate))))) AS 'Adjustments',
				--ISNULL(#ap.PayableBalance, 0) AS 'AccountsPayableBalance'
				(SELECT ISNULL(SUM(Total), 0) - ISNULL(SUM(AmountPaid), 0)
					FROM #MyUnPaidInvoices
					WHERE PropertyID = prop.PropertyID
					GROUP BY PropertyID) AS 'AccountsPayableBalance'
			FROM #BankTransactionLedgerTable #btlt
				INNER JOIN Property prop ON #btlt.PropertyID = prop.PropertyID
				INNER JOIN BankAccount ba ON #btlt.BankAccountID = ba.BankAccountID
				LEFT JOIN #PropertiesAndDates #pad ON #btlt.PropertyID = #pad.PropertyID
				--LEFT JOIN #AccountsPayable #ap ON #btlt.PropertyID = #ap.PropertyID
			WHERE (((@accountingPeriodID IS NULL) AND ([Date] >= @startDate))
					    OR ((@accountingPeriodID IS NOT NULL) AND ([Date] >= #pad.StartDate)))
			GROUP BY #btlt.PropertyID, prop.PropertyID, #btlt.BankAccountID, ba.BankAccountID
			

	UPDATE #babb SET EndingBalance = ISNULL(#cb.Debits, 0) + ISNULL(#cb.Adjustments, 0) + ISNULL(#babb.BeginningBalance, 0) - ISNULL(#cb.Credits, 0)
		FROM #BankAccountBeginningBalance #babb
			LEFT JOIN #CashBalance #cb ON #cb.BankAccountID = #babb.BankAccountID AND #cb.PropertyID = #babb.PropertyID
			
-- Create return set by settings and LEFT JOINING #CashBalance into #BankAccounts
	IF (@groupByProperty = 0)
	BEGIN		
		SELECT DISTINCT p.PropertyID, 
						p.Name AS 'PropertyName', 
						ISNULL((SELECT SUM(ISNULL(Total, 0) - ISNULL(AmountPaid, 0))
							FROM #MyUnPaidInvoices
							WHERE PropertyID = p.PropertyID), 0) AS 'AccountsPayableBalance',
						ba.*
		FROM
		(SELECT	DISTINCT				
				ba.BankAccountID,
				ba.AccountNumberDisplay AS 'AccountNumber',
				ba.AccountName AS 'AccountName',
				ISNULL(SUM(#babb.BeginningBalance), 0) AS 'BeginningBalance',
				ISNULL(SUM(#cb.Debits), 0) AS 'Debits',
				ISNULL(SUM(#cb.Credits), 0) AS 'Credits',
				ISNULL(SUM(#cb.Adjustments), 0) AS 'Adjustments',
				--ISNULL(SUM(#cb.AccountsPayableBalance), 0) AS 'AccountsPayableBalance',				
				ISNULL(SUM(#babb.EndingBalance), 0) AS 'TotalEndingBalance'
			FROM #BankAccountBeginningBalance #babb
				INNER JOIN BankAccount ba ON #babb.BankAccountID = ba.BankAccountID				
				LEFT JOIN #CashBalance #cb ON #babb.BankAccountID = #cb.BankAccountID AND #babb.PropertyID = #cb.PropertyID
			GROUP BY ba.BankAccountID, ba.AccountNumberDisplay, ba.AccountName)  ba
		INNER JOIN BankAccountProperty bap ON bap.BankAccountID = ba.BankAccountID
		INNER JOIN Property p ON p.PropertyID = bap.PropertyID
		WHERE bap.PropertyID IN (SELECT Value FROM @propertyIDs)
		ORDER BY ba.AccountName

	END
	ELSE
	BEGIN
		SELECT	DISTINCT
				prop.PropertyID AS 'PropertyID',
				prop.Name AS 'PropertyName',
				ba.BankAccountID,
				ba.AccountNumberDisplay AS 'AccountNumber',
				ba.AccountName AS 'AccountName',
				ISNULL(#babb.BeginningBalance, 0) AS 'BeginningBalance',
				ISNULL(#cb.Debits, 0) AS 'Debits',
				ISNULL(#cb.Credits, 0) AS 'Credits',
				ISNULL(#cb.Adjustments, 0) AS 'Adjustments',
				--ISNULL(#cb.AccountsPayableBalance, 0) AS 'AccountsPayableBalance',
				ISNULL((SELECT SUM(ISNULL(Total, 0) - ISNULL(AmountPaid, 0))
					FROM #MyUnPaidInvoices
					WHERE PropertyID = #babb.PropertyID), 0) AS 'AccountsPayableBalance',
				ISNULL(#babb.EndingBalance, 0) AS 'TotalEndingBalance'
			FROM #BankAccountBeginningBalance #babb
				INNER JOIN BankAccount ba ON #babb.BankAccountID = ba.BankAccountID
				INNER JOIN Property prop ON #babb.PropertyID = prop.PropertyID
				LEFT JOIN #CashBalance #cb ON #babb.BankAccountID = #cb.BankAccountID AND #babb.PropertyID = #cb.PropertyID	
			ORDER BY AccountName
	END
	
END
GO
