SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO






-- ============================================================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 6, 2015
-- Description:	Gets a list of items for a Bank Ledger and what they paid off
-- ============================================================================
CREATE PROCEDURE [dbo].[RPT_BNKACCT_CheckRegsiterWithDetail]
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@bankAccountID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null,
	@onlyQueuedForPrinting bit = 0,
	@accountingPeriodID uniqueidentifier = null,

	@propertyIDs GuidCollection READONLY,		-- If there are values here then we need to get each property's portion of each check and return the PropertyID from Transaction
	@includeDetail bit = 0						-- If 1, select out a second data set that contains the applications of the payments
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #CheckLedgerInfo (
		PaymentID uniqueidentifier NOT NULL,
		TransactionID uniqueidentifier NULL,
		BankTransactionID uniqueidentifier NULL,
		PropertyID uniqueidentifier NULL,
		[Date] date NULL,
		CheckNumber nvarchar(200) NULL,
		PayTo nvarchar(500) NULL,
		Amount money NULL,
		Memo nvarchar(500) NULL,
		CheckVoidedDate date NULL,
		TransactionTypeGroup nvarchar(200) NULL,
		TransactionTypeName nvarchar(200) NULL,
		ClearedDate date NULL,
		[Status] nvarchar(50) NULL,
		[TimeStamp] datetime NULL)
		
	CREATE TABLE #CheckLedgerDetailItem (
		PaymentID uniqueidentifier NOT NULL,
		[Date] date NULL,
        TransactionTypeName nvarchar(50) NULL,		--TransactionTypeName - Check, Refund, Payment
		PropertyID uniqueidentifier NULL,
		Reference nvarchar(200) NULL,
        [DateTime] Date NULL,
		[Description] nvarchar(200) NULL,
        Amount money NULL)

	-- Build temp table that contains Transaction level details for each check 
	-- Takes into account @propertyIDs to only get the portions of the checks for the selected properties
	-- At the end, select out a sum either grouped by PaymentID if there are no @propertyIDs or grouped by PaymentID and PropertyID if there are
	
	-- Applications
	-- If TT.Group = Invoice and TT.Name = Payment
	--  Join in Transaction.AppliesToTransacitonID back to Invoice
	--  to get Invoice #	Invoice Date	Invoice Desc	Paid Amount (Sum of the payments for that invoice)
	-- If TT.Group = Bank and TT.Name = Check OR tt.Group = Bank AND tt.Name = Refund
	--	Return a single record with the Payment.Description as the InvoiceDescription
	--	Payment.Refercne as Invoicenumber, Payment.Date as Invoice Date, Payment.Amount as PaidAmount
	


	IF (@accountingPeriodID IS NOT NULL)
	BEGIN
		SET @startDate = (SELECT MIN(pap.StartDate)
									FROM PropertyAccountingPeriod pap
									INNER JOIN BankAccountProperty bap ON bap.BankAccountID = @bankAccountID AND bap.PropertyID = pap.PropertyID
									WHERE pap.AccountID = @accountID 
										AND pap.AccountingPeriodID = @accountingPeriodID)

									
		SET @endDate = (SELECT MAX(pap.EndDate)
									FROM PropertyAccountingPeriod pap
									INNER JOIN BankAccountProperty bap ON bap.BankAccountID = @bankAccountID AND bap.PropertyID = pap.PropertyID
									WHERE pap.AccountID = @accountID 
										AND pap.AccountingPeriodID = @accountingPeriodID)
	END
	
	CREATE TABLE #Properties (
		PropertyID uniqueidentifier NOT NULL)
		
	IF (0 < (SELECT COUNT(*) FROM @propertyIDs))
	BEGIN
		INSERT #Properties SELECT Value FROM @propertyIDs
	END
	ELSE
	BEGIN
		INSERT #Properties SELECT PropertyID FROM Property WHERE AccountID = @accountID
	END

	INSERT #CheckLedgerInfo
		SELECT DISTINCT 
				p.PaymentID AS 'PaymentID', 
				t.TransactionID,
				bt.BankTransactionID, 
				t.PropertyID,
				--prop.Abbreviation, 
				CAST(p.[Date] AS Date) AS 'Date',
				bt.ReferenceNumber as 'CheckNumber', 
				p.ReceivedFromPaidTo as 'PayTo', 
				--p.Amount,
				(CASE WHEN att.Name = 'Credit' THEN -t.Amount
					  ELSE t.Amount
				 END),
				--t.Amount, 
				p.[Description] AS 'Memo',
				p.ReversedDate AS 'CheckVoidedDate', 
				--bt.CheckPrintedDate AS 'CheckPrintedDate',
				--CASE WHEN tt.[Group] = 'Invoice' THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS 'InvoicePayment'
				tt.[Group] AS 'TransactionTypeGroup', 
				tt.Name AS 'TransactionTypeName',
				bt.ClearedDate AS 'ClearedDate',
				CASE
					WHEN (bt.BankReconciliationID IS NOT NULL) THEN 'Reconciled'
					WHEN (bt.ClearedDate IS NOT NULL AND bt.BankReconciliationID IS NULL) THEN 'Cleared'
					ELSE 'Open'
					END AS 'Status',
				p.[TimeStamp]
			FROM BankTransaction bt
				INNER JOIN Payment p ON p.PaymentID = bt.ObjectID 
				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN [Property] prop ON t.PropertyID = prop.PropertyID
				INNER JOIN #Properties #p ON prop.PropertyID = #p.PropertyID
				INNER JOIN [Transaction] at ON at.TransactionID = t.AppliesToTransactionID
				INNER JOIN [TransactionType] att ON att.TransactionTypeID = at.TransactionTypeID
				--INNER JOIN [BankAccountProperty] baprop ON baprop.BankAccountID = @bankAccountID AND baprop.PropertyID = t.PropertyID
			WHERE p.AccountID = @accountID
			  AND p.[Date] >= @startDate
			  AND p.[Date] <= @endDate		
			  AND p.[Type] = 'Check'
			  AND t.ObjectID = @bankAccountID
			  AND t.ReversesTransactionID IS NULL
			  AND t.IsDeleted = 0
			  --AND (((tt.[Group] = 'Bank') AND (tt.Name = 'Check' OR tt.Name = 'Refund')) OR ((tt.[Group] = 'Invoice') /*AND (tt.Name = 'Payment' OR tt.Name = 'Intercompany Payment')*/))
			  AND (((tt.[Group] = 'Bank') AND (tt.Name = 'Check' OR tt.Name = 'Refund')) OR ((tt.[Group] = 'Invoice') AND (tt.Name = 'Payment')))
			  AND ((@onlyQueuedForPrinting = 0) OR ((bt.QueuedForPrinting = 1) AND (bt.CheckPrintedDate IS NULL)))
			--ORDER BY [Date]			
		
		/* 
			Similar query above for Invoice Intercompany Payment
			Needs to find any PaymentID that has an Intercompany Payment Transaction record tied to one of the #Properties.PropertyID
			Once you have the PaymentID add every non-Intercompany Payment transaction tied to that payment record and dump the Intercompany Payment PropertyID
			into the table instead of the actual payment propertyID.  Doing that will make the detail queries below work as it will get 
			the details for all payments tied to that intercompany payment regardless of the PropertyID.  The property that paid the invoice will get "credit"
			for all the invoices they paid.
			
		*/
		
		CREATE TABLE #MyIntercompanyPayments (
			PaymentID uniqueidentifier NOT NULL)
			
		INSERT #MyIntercompanyPayments
			SELECT	DISTINCT 
					p.PaymentID 
				FROM BankTransaction bt
					INNER JOIN Payment p ON p.PaymentID = bt.ObjectID 
					INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
					INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
					INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
					INNER JOIN [Property] prop ON t.PropertyID = prop.PropertyID
					INNER JOIN #Properties #p ON prop.PropertyID = #p.PropertyID
				WHERE p.AccountID = @accountID
				  AND p.[Date] >= @startDate
				  AND p.[Date] <= @endDate		
				  AND p.[Type] = 'Check'
				  AND t.ObjectID = @bankAccountID
				  AND t.ReversesTransactionID IS NULL
				  AND t.IsDeleted = 0
				  AND (((tt.[Group] = 'Invoice') AND (tt.Name = 'Intercompany Payment')) 
					   OR ((tt.[Group] = 'Bank') AND (tt.Name = 'Intercompany Refund')))
				  AND ((@onlyQueuedForPrinting = 0) OR ((bt.QueuedForPrinting = 1) AND (bt.CheckPrintedDate IS NULL)))

	INSERT #CheckLedgerInfo
		SELECT DISTINCT 
				p.PaymentID AS 'PaymentID', 
				t.TransactionID,
				bt.BankTransactionID, 
				t.PropertyID,
				--prop.Abbreviation, 
				CAST(p.[Date] AS Date) AS 'Date',
				bt.ReferenceNumber as 'CheckNumber', 
				p.ReceivedFromPaidTo as 'PayTo', 
				--p.Amount,
				(CASE WHEN att.Name = 'Credit' THEN -t.Amount
					  ELSE t.Amount
				 END),
				p.[Description] AS 'Memo',
				p.ReversedDate AS 'CheckVoidedDate', 
				--bt.CheckPrintedDate AS 'CheckPrintedDate',
				--CASE WHEN tt.[Group] = 'Invoice' THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS 'InvoicePayment'
				tt.[Group] AS 'TransactionTypeGroup', 
				tt.Name AS 'TransactionTypeName',
				bt.ClearedDate AS 'ClearedDate',
				CASE
					WHEN (bt.BankReconciliationID IS NOT NULL) THEN 'Reconciled'
					WHEN (bt.ClearedDate IS NOT NULL AND bt.BankReconciliationID IS NULL) THEN 'Cleared'
					ELSE 'Open'
					END AS 'Status',
				p.[TimeStamp]
			FROM BankTransaction bt
				INNER JOIN Payment p ON p.PaymentID = bt.ObjectID 
				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN [Property] prop ON t.PropertyID = prop.PropertyID
				--INNER JOIN #Properties #p ON prop.PropertyID = #p.PropertyID
				--INNER JOIN [BankAccountProperty] baprop ON baprop.BankAccountID = @bankAccountID AND baprop.PropertyID = t.PropertyID
				INNER JOIN [Transaction] at ON at.TransactionID = t.AppliesToTransactionID
				INNER JOIN [TransactionType] att ON att.TransactionTypeID = at.TransactionTypeID
			WHERE p.PaymentID IN (SELECT PaymentID FROM #MyIntercompanyPayments)
			  AND (((tt.[Group] = 'Invoice') AND (tt.Name = 'Payment'))
			        OR ((tt.[Group] = 'Bank') AND (tt.Name = 'Refund')))
			  AND t.TransactionID NOT IN (SELECT TransactionID FROM #CheckLedgerInfo)
		
--select * from #CheckLedgerInfo order by [date]
		
	--UPDATE #CheckLedgerInfo SET PropertyID = (SELECT t.PropertyID
	--											FROM [Transaction] t
	--												INNER JOIN #CheckLedgerInfo #cli1 ON t.AppliesToTransactionID = #cli1.TransactionID
	--												INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] = 'Invoice' AND tt.Name = 'Intercompany Payment'
	--											WHERE #cli1.TransactionID = #CheckLedgerInfo.TransactionID)
	
	UPDATE #cli SET PropertyID = t.PropertyID
		FROM #CheckLedgerInfo #cli
			INNER JOIN [Transaction] t ON #cli.TransactionID = t.AppliesToTransactionID
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
		WHERE tt.[Group] = 'Invoice' AND tt.Name = 'Intercompany Payment'
		
--select * from #CheckLedgerInfo order by [date] 		

	SELECT  #payments.PaymentID,
			#payments.BankTransactionID,
			#payments.PropertyID,	
			prop.Name AS 'PropertyName',
			#payments.[Date],
			#payments.CheckNumber,
			#payments.PayTo,
			SUM(Amount) AS 'Amount',
			#payments.Memo,
			#payments.CheckVoidedDate,
			#payments.TransactionTypeGroup,
			#payments.TransactionTypeName,
			#payments.ClearedDate,
			#payments.[Status],
			#payments.[TimeStamp]
		FROM #CheckLedgerInfo #payments
			INNER JOIN Property prop ON #payments.PropertyID = prop.PropertyID
		GROUP BY #payments.PaymentID, #payments.BankTransactionID, #payments.PropertyID, prop.Name,	#payments.[Date], #payments.CheckNumber, #payments.PayTo, #payments.Memo,
			#payments.CheckVoidedDate, #payments.TransactionTypeGroup, #payments.TransactionTypeName,	#payments.ClearedDate, #payments.[Status], #payments.[TimeStamp]
		ORDER BY #payments.[Date], #payments.CheckNumber, #payments.PaymentID
			
	IF (@includeDetail = 1)
	BEGIN
		--INSERT #CheckLedgerDetailItem
			SELECT	DISTINCT
					#cli.PaymentID,
					#cli.[Date],
					#cli.TransactionTypeName,
					#cli.PropertyID,
					i.Number AS 'Reference',
					i.InvoiceDate AS 'DateTime',
					i.[Description] AS 'Description',
					SUM(
						CASE WHEN i.Credit = 1 THEN -tPayment.Amount
							 ELSE tPayment.Amount
						END) AS 'Amount',
					i.InvoiceID
				FROM #CheckLedgerInfo #cli
					INNER JOIN [Transaction] tPayment ON #cli.TransactionID = tPayment.TransactionID
					INNER JOIN [Transaction] tInvoice ON tPayment.AppliesToTransactionID = tInvoice.TransactionID
					INNER JOIN InvoiceLineItem ili ON tInvoice.TransactionID = ili.TransactionID
					INNER JOIN Invoice i ON ili.InvoiceID = i.InvoiceID
				WHERE #cli.TransactionTypeGroup = 'Invoice' 
				  AND #cli.TransactionTypeName = 'Payment'				  
				GROUP BY #cli.PaymentID, #cli.[Date], #cli.TransactionTypeName,	#cli.PropertyID, i.InvoiceID, i.Number, i.InvoiceDate, i.[Description]
									
			UNION
			
			SELECT	DISTINCT
					#cli.PaymentID,
					#cli.[Date],
					#cli.TransactionTypeName,
					#cli.PropertyID,
					pay.ReferenceNumber,
					pay.[Date] AS 'DateTime',
					pay.[Description],
					pay.Amount,
					pay.PaymentID
				FROM #CheckLedgerInfo #cli
					INNER JOIN Payment pay ON #cli.PaymentID = pay.PaymentID
				WHERE #cli.TransactionTypeGroup = 'Bank'
				  AND #cli.TransactionTypeName IN ('Check', 'Refund')
				ORDER BY #cli.[Date], #cli.PaymentID
	END
	
	
END
GO
