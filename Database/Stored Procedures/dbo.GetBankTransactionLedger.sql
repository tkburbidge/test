SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 22, 2011
-- Description:	Gets a list of items for a Bank Ledger
-- =============================================
CREATE PROCEDURE [dbo].[GetBankTransactionLedger] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@bankAccountID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null,
	@type nvarchar(50) = null,
	@reconciliationID uniqueidentifier = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	IF (@accountingPeriodID IS NOT NULL)
	BEGIN
		SET @startDate = (SELECT MIN(pap.StartDate)
									FROM PropertyAccountingPeriod pap
									WHERE pap.AccountID = @accountID 
										AND pap.AccountingPeriodID = @accountingPeriodID)

									
		SET @endDate = (SELECT MAX(pap.EndDate)
									FROM PropertyAccountingPeriod pap
									WHERE pap.AccountID = @accountID 
										AND pap.AccountingPeriodID = @accountingPeriodID)
	END

	CREATE TABLE #BankTransactionLedgerTable (
		ObjectID uniqueidentifier NOT NULL,
		BankTransactionID uniqueidentifier NOT NULL,
		[Date] date NULL,
		[Type] nvarchar(20) NULL,
		[Group] nvarchar(20) NULL,
		TransactionType nvarchar(50) NULL,
		Reference nvarchar(50) NULL,
		ClearedDate date NULL,
		BankReconciliationID uniqueidentifier NULL,
		[Description] nvarchar(500) NULL,
		Amount money NULL,
		CheckVoidedDate date NULL,
		IsAddition bit NULL,
		BTimeStamp datetime NULL,
		Category nvarchar(50) NULL,
		BankFileID nvarchar(100) NULL,
		IsVoidingTransaction bit null)
	
	DECLARE @statementEndDate date
	IF (@reconciliationID IS NOT NULL)
	BEGIN
		SET @statementEndDate = (SELECT TOP 1 StatementDate FROM BankAccountReconciliation WHERE BankAccountReconciliationID = @reconciliationID)
	END

	-- Bank Transactions tied to BankTransactionTransaction table (system  bank deposits)
	INSERT #BankTransactionLedgerTable
	  	SELECT	DISTINCT 				
				bt.BankTransactionID AS 'ObjectID',				
				bt.BankTransactionID,
				CAST(t.[TransactionDate] AS Date) AS 'Date',
				'DEP' AS 'Type',				
				tt.[Group],
				tt.Name AS 'TransactionType',
				bt.ReferenceNumber as 'Reference', 
				bt.ClearedDate,
				bt.BankReconciliationID,
				MIN(t.[Description]) AS 'Description',	
				SUM(t.Amount) AS 'Amount',				 
				NULL,
				CAST(1 AS bit) AS 'IsAddition',
				MIN(t.[TimeStamp]) AS 'BTimeStamp',	
				btc.Category AS 'Category',
				bt.BankFileID,
				CAST(0 AS BIT) AS 'IsVoidingTransaction'
		FROM BankTransaction bt						
			INNER JOIN BankTransactionTransaction btt ON bt.BankTransactionID = btt.BankTransactionID
			INNER JOIN [Transaction] t ON btt.TransactionID = t.TransactionID
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID			
			INNER JOIN BankTransactionCategory btc on btc.BankTransactionCategoryID = bt.BankTransactionCategoryID								
		WHERE t.AccountID = @accountID
		  AND t.TransactionDate >= @startDate
		  AND t.TransactionDate <= @endDate
		  AND t.ObjectID = @bankAccountID
		  AND t.IsDeleted = 0		  
		  AND ((t.ReversesTransactionID IS NULL))
		  AND (((@type IS NULL) AND (((tt.[Group] = 'Bank') AND (tt.Name in ('Deposit')))	-- Only get bank deposits
										OR ((tt.[Group] = 'Bank') AND (tt.Name = @type))))
		  AND ((@reconciliationID IS NULL) OR ((bt.BankReconciliationID IS NULL) OR (bt.BankReconciliationID = @reconciliationID))))
		GROUP BY bt.BankTransactionID, bt.BankTransactionID, t.[TransactionDate], tt.[Group], tt.Name, bt.ReferenceNumber, ClearedDate, BankReconciliationID, 
				 btc.Category, bt.BankFileID
		OPTION (RECOMPILE)

	-- Bank Transactions tied to the Payment table
	INSERT #BankTransactionLedgerTable	
		SELECT	DISTINCT 
				bt.ObjectID,
				bt.BankTransactionID,
				--prop.PropertyID,
				--prop.Abbreviation as 'PropertyAbbreviation', 
				CAST(p.[Date] AS Date) AS 'Date',
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
								WHEN 'ACH'					THEN 'ACH'
								END)
					WHEN tt.Name = 'Transfer'					
						THEN 'TRX'
					WHEN tt.Name = 'Withdrawal'				
						THEN 'WDL'					
					END AS [Type],
				tt.[Group],
				tt.Name AS 'TransactionType',
				bt.ReferenceNumber as 'Reference', 
				bt.ClearedDate,
				bt.BankReconciliationID,
				p.ReceivedFromPaidTo AS 'Description',			
				p.Amount AS 'Amount',				
				p.ReversedDate AS 'CheckVoidedDate',
				CASE 
					WHEN (p.Amount > 0 AND tt.Name NOT IN ('Payment', 'Check', 'Withdrawal', 'Refund')) THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
					END	AS 'IsAddition',
				p.[TimeStamp] AS 'BTimeStamp',
				btc.Category AS 'Category',
				bt.BankFileID,
				CAST(0 AS BIT) AS 'IsVoidingTransaction'
		FROM BankTransaction bt
			INNER JOIN Payment p ON p.PaymentID = bt.ObjectID 
			INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN [Property] prop ON t.PropertyID = prop.PropertyID
			INNER JOIN BankTransactionCategory btc on btc.BankTransactionCategoryID = bt.BankTransactionCategoryID
			LEFT JOIN Batch batch on p.BatchID = batch.BatchID
			LEFT JOIN [BankTransactionTransaction] btt on btt.BankTransactionID = batch.BankTransactionID
			LEFT JOIN [Transaction] batTran ON batTran.TransactionID = btt.TransactionID AND batTran.PropertyID = t.PropertyID		
		WHERE t.AccountID = @accountID
		  AND t.TransactionDate >= @startDate
		  AND t.TransactionDate <= @endDate
		  AND ((t.ObjectID = @bankAccountID) OR (batTran.ObjectID = @bankAccountID))
		  AND tt.Name NOT IN ('Balance Transfer Deposit', 'Balance Transfer Payment', 'Deposit Applied to Deposit', 'Deposit Applied to Balance')
		  AND t.IsDeleted = 0
		  -- Get the NSF and Credit Card Recapture transactions.  The last condition here takes care of scenarios wehre
		  -- a deposit is applied to the balance but then that deposit is then reversed as an NSF.  In this scenario there
		  -- will be a transaction of type Payment and Seposit but the payment won't have a LedgerItemTypeID
		  AND ((t.ReversesTransactionID IS NULL) OR ((p.PaidOut = 0) AND (p.[Type] IN ('NSF', 'Credit Card Recapture')) AND (t.LedgerItemTypeID IS NOT NULL)))
		  AND (((@type IS NULL) AND (((tt.[Group] = 'Bank') AND (tt.Name in ('Adjustment', 'Check', 'Deposit', 'Transfer', 'Withdrawal', 'Refund', 'Vendor Credit')))	-- Get all bank transactions
									   OR ((p.PaidOut = 0) AND (p.[Type] = 'NSF'))																	-- Get all nsf checks
									   OR ([Group] = 'Invoice' AND (tt.Name = 'Payment'))
									   OR ((p.PaidOut = 0) AND (p.[Type] = 'Credit Card Recapture')))															-- Get all invoice payments	
									   OR ((tt.[Group] = 'Bank') AND (tt.Name = @type))))
		  AND ((@reconciliationID IS NULL) OR ((bt.BankReconciliationID IS NULL) OR (bt.BankReconciliationID = @reconciliationID)))
		  -- Do not include voided checks when we are requesting for a given reconciliation unless
		  -- the void occurs after the statement end date
		  AND ((@reconciliationID IS NULL) OR (p.ReversedDate IS NULL) OR (p.ReversedDate > @statementEndDate))
		OPTION (RECOMPILE)

	-- Voided checks
	INSERT #BankTransactionLedgerTable	
		  SELECT DISTINCT
				bt.ObjectID,
				bt.BankTransactionID,
				--prop.PropertyID,
				--prop.Abbreviation as 'PropertyAbbreviation', 
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
								WHEN 'ACH'					THEN 'ACH'
								END)
					WHEN tt.Name = 'Transfer'					
						THEN 'TRX'
					WHEN tt.Name = 'Withdrawal'				
						THEN 'WDL'					
					END AS [Type],
				tt.[Group],
				tt.Name AS 'TransactionType',
				bt.ReferenceNumber as 'Reference', 
				bt.ClearedDate,
				bt.BankReconciliationID,
				p.ReceivedFromPaidTo AS 'Description',
				p.Amount AS 'Amount',				
				null AS 'CheckVoidedDate',
				(CASE WHEN tt.Name = 'Vendor Credit' THEN CAST(0 AS BIT)
				 ELSE CAST(1 AS BIT)
				 END) 'IsAddition',
				p.[TimeStamp] AS 'BTimeStamp',
				btc.Category AS 'Category',
				bt.BankFileID,
				CAST(1 AS BIT) AS 'IsVoidingTransaction'
		FROM BankTransaction bt
			INNER JOIN Payment p ON p.PaymentID = bt.ObjectID 
			INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN [Property] prop ON t.PropertyID = prop.PropertyID
			INNER JOIN BankTransactionCategory btc on btc.BankTransactionCategoryID = bt.BankTransactionCategoryID				
		WHERE t.AccountID = @accountID
		  AND p.ReversedDate IS NOT NULL
		  AND p.ReversedDate >= @startDate
		  AND p.ReversedDate <= @endDate
		  AND t.ObjectID = @bankAccountID
		  AND t.IsDeleted = 0		 
		  AND ((@type IS NULL) AND (((tt.[Group] = 'Bank') AND (tt.Name in ('Check', 'Refund', 'Vendor Credit')))	
									   OR ([Group] = 'Invoice' AND (tt.Name = 'Payment'))									   
										OR ((tt.[Group] = 'Bank') AND (tt.Name = @type))))
		  AND ((@reconciliationID IS NULL) OR ((bt.BankReconciliationID IS NULL) OR (bt.BankReconciliationID = @reconciliationID)))
		  -- Do not include voided checks when we are requesting for a given reconciliation
		  AND ((@reconciliationID IS NULL) OR (p.ReversedDate IS NULL) OR (p.[Date] > @statementEndDate AND p.[ReversedDate] <= @statementEndDate))			  
		OPTION (RECOMPILE)

	-- Bank Transactions tied to Transaction table
	INSERT #BankTransactionLedgerTable	
		  SELECT DISTINCT 
				CASE WHEN tg.TransactionGroupID IS NOT NULL THEN tg.TransactionGroupID
					 ELSE bt.ObjectID
				END AS 'ObjectID',				
				bt.BankTransactionID,
				--prop.PropertyID,
				--prop.Abbreviation as 'PropertyAbbreviation', 
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
				tt.[Group],
				tt.Name AS 'TransactionType',
				bt.ReferenceNumber as 'Reference', 
				bt.ClearedDate,
				bt.BankReconciliationID,
				t.[Description] AS 'Description',				
				t.Amount AS 'Amount',				
				NULL,
				CASE 
					WHEN (t.Amount > 0 AND tt.Name NOT IN ('Payment', 'Check', 'Withdrawal'))
						THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
					END	AS 'IsAddition',
				t.[TimeStamp] AS 'BTimeStamp',				
				btc.Category AS 'Category',
				bt.BankFileID,
				CAST(0 AS BIT) AS 'IsVoidingTransaction'
		FROM BankTransaction bt			
			INNER JOIN [Transaction] t ON bt.ObjectID = t.TransactionID
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN [Property] prop ON t.PropertyID = prop.PropertyID
			INNER JOIN BankTransactionCategory btc on btc.BankTransactionCategoryID = bt.BankTransactionCategoryID					
			LEFT JOIN [TransactionGroup] tg ON tg.TransactionID = t.TransactionID
		WHERE t.AccountID = @accountID
		  AND t.TransactionDate >= @startDate
		  AND t.TransactionDate <= @endDate
		  AND t.ObjectID = @bankAccountID
		  AND t.IsDeleted = 0
		  AND tt.Name NOT IN ('Balance Transfer Deposit', 'Balance Transfer Payment', 'Deposit Applied to Deposit', 'Deposit Applied to Balance')
		  AND ((t.ReversesTransactionID IS NULL))
		  AND (((@type IS NULL) AND (((tt.[Group] = 'Bank') AND (tt.Name in ('Adjustment', 'Check', 'Deposit', 'Transfer', 'Withdrawal', 'Refund')))	-- Get all bank transactions									   
									   OR (tt.[Group] = 'Invoice' AND (tt.Name = 'Payment'))									   
										OR ((tt.[Group] = 'Bank') AND (tt.Name = @type))
										OR (tt.[Group] = 'Journal Entry' AND tt.Name = 'Cash')))
		  AND ((@reconciliationID IS NULL) OR ((bt.BankReconciliationID IS NULL) OR (bt.BankReconciliationID = @reconciliationID))))		  

		OPTION (RECOMPILE)

	SELECT * FROM #BankTransactionLedgerTable
	WHERE [Type] IS NOT NULL -- Hack to deal with situations where a payment is transferred and then NSFed on the new ledger
		ORDER BY [Date], IsAddition DESC, BTimeStamp
END
GO
