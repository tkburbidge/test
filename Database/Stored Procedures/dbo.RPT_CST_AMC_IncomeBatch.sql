SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: Feb. 22, 2017
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_AMC_IncomeBatch] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null,
	@includeTransactionDetail bit = 0
AS

DECLARE @defaultAccountingBasis nvarchar(50) = 'Accrual'
DECLARE @accountID bigint = 1

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;



    CREATE TABLE #Transactions (
		ID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		PropertyID uniqueidentifier not null,
		ObjectID uniqueidentifier not null,
		ObjectType nvarchar(50) null,
		Name nvarchar(200) null,
		Unit nvarchar(50) null,
		UnitID uniqueidentifier null,
		[Date] date null,
		TransactionTypeName nvarchar(50) null,
		[Description] nvarchar(500) null,
		LedgerItemTypeName nvarchar(50) not null,
		Notes nvarchar(200) null,
		Reference nvarchar(100) null,
		Amount money null,
		[Timestamp] datetime null,
		LedgerItemTypeID uniqueidentifier null)

	DECLARE @empty StringCollection
	INSERT INTO #Transactions
		EXEC [RPT_TNS_TransactionLists] null, null, @propertyIDs, @empty, @accountingPeriodID

	-- Add values needed for export
	ALTER TABLE #Transactions ADD  AccountingPeriodEndDate date
	ALTER TABLE #Transactions ADD  GLAccountID uniqueidentifier
	ALTER TABLE #Transactions ADD  BatchID uniqueidentifier

	UPDATE #Transactions SET BatchID = (SELECT BatchID FROM Payment WHERE PaymentID = #Transactions.ID)
	UPDATE #Transactions SET AccountingPeriodEndDate = (SELECT TOP 1 EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
	UPDATE #Transactions SET GLAccountID = (SELECT GLAccountID FROM LedgerItemType WHERE LedgerItemTypeID = #Transactions.LedgerItemTypeID)
	SET @accountID = (SELECT TOP 1 AccountID FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
	
	-- Set the GL Account of deposited payments to the bank account GL Account
	UPDATE #Transactions SET GLAccountID = (SELECT TOP 1 ba.GLAccountID
											FROM Payment p
											INNER JOIN Batch b ON b.BatchID = p.BatchID
											INNER JOIN BankTransaction bt ON bt.BankTransactionID = b.BankTransactionID
											INNER JOIN BankTransactionTransaction btt ON btt.BankTransactionID = bt.BankTransactionID
											INNER JOIN [Transaction] t on t.TransactionID = btt.TransactionID
											INNER JOIN BankAccount ba ON ba.BankAccountID = t.ObjectID
											WHERE p.PaymentID = #Transactions.ID
											AND #Transactions.TransactionTypeName IN ('Payment', 'Deposit'))
	WHERE TransactionTypeName IN ('Payment', 'Deposit')
		AND BatchID IS NOT NULL

	-- Update Deposit Applications to point to the Security Deposit GL
	UPDATE #Transactions SET GLAccountID = (SELECT GLAccountID FROM GLAccount WHERE Number = '219100') WHERE LedgerItemTypeName IN ('Deposit Applied to Deposit', 'Balance Transfer Deposit', 'Deposit Applied to Balance', 'Balance Transfer Payment')

	-- Update Deposit Refunds to point to Deposits in Transit
	UPDATE #Transactions SET GLAccountID = (SELECT GLAccountID FROM GLAccount WHERE Number = '219101') WHERE LedgerItemTypeName IN ('Deposit Refund')

	-- Update Payment Refunds to point to AR
	UPDATE #Transactions SET GLAccountID = (SELECT GLAccountID FROM GLAccount WHERE Number = '113000') WHERE LedgerItemTypeName IN ('Payment Refund')	
	

	CREATE TABLE #IncomeBatchDataToExport (
		PropertyID uniqueidentifier not null,
		AccountingPeriodEndDate date not null,
		LedgerItemTypeAbbreviation nvarchar(50) null,
		LedgerItemTypeName nvarchar(500) null,
		GLAccountNumber nvarchar(50) null,
		LedgerItemTypeID uniqueidentifier null,
		GLAccountID uniqueidentifier null,
		Amount money null,
		TransactionTypeName nvarchar(100),
		OrderBy int
		)

	-- Group entries by GL Account
	INSERT INTO #IncomeBatchDataToExport
		SELECT	
			PropertyID,
			AccountingPeriodEndDate,
			lit.Abbreviation,
			COALESCE(lit.Name, #t.LedgerItemTypeName),
			gl.Number,
			lit.LedgerItemTypeID,
			gl.GLAccountID,
			SUM(#t.Amount),
			#t.TransactionTypeName,
			0
		FROM #Transactions #t
			LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = #t.LedgerItemTypeID
			LEFT JOIN GLAccount gl ON gl.GLAccountID = #t.GLAccountID
		GROUP BY PropertyID, AccountingPeriodEndDate, lit.Abbreviation, lit.Name, gl.Number, lit.LedgerItemTypeID, gl.GLAccountID, #t.LedgerItemTypeName, #t.TransactionTypeName

	UPDATE #IncomeBatchDataToExport SET Amount = -Amount WHERE TransactionTypeName IN ('Charge', 'Deposit Refund')

	-- Add an entry for Accounts Receivable
	INSERT INTO #IncomeBatchDataToExport
		SELECT	
			PropertyID,
			AccountingPeriodEndDate,
			'',
			gl.Name,
			gl.Number,
			null,
			gl.GLAccountID,
			-SUM(#t.Amount),
			'AR',
			0
		FROM #IncomeBatchDataToExport #t
			INNER JOIN Settings s ON s.AccountID = @accountID
			INNER JOIN GLAccount gl ON gl.GLAccountID = s.AccountsReceivableGLAccountID
		WHERE TransactionTypeName IN ('Charge', 'Credit', 'Payment', 'Deposit Applied to Balance', 'Balance Transfer Payment', 'Payment Refund')
		GROUP BY PropertyID, AccountingPeriodEndDate, gl.Name, gl.Number, gl.GLAccountID

	-- Add an entry for deposits
	INSERT INTO #IncomeBatchDataToExport
		SELECT	
			PropertyID,
			AccountingPeriodEndDate,
			'',
			gl.Name,
			gl.Number,
			null,
			gl.GLAccountID,
			-SUM(#t.Amount),
			'Deposit',
			0
		FROM #IncomeBatchDataToExport #t			
			INNER JOIN GLAccount gl ON gl.Number = '219100' AND gl.AccountID = @accountID
		WHERE TransactionTypeName IN ('Deposit', 'Deposit Refund', 'Deposit Applied to Deposit', 'Balance Transfer Deposit')
		GROUP BY PropertyID, AccountingPeriodEndDate, gl.Name, gl.Number, gl.GLAccountID

	-- Order the report
	UPDATE #IncomeBatchDataToExport SET OrderBY = 1 WHERE TransactionTypeName = 'Charge'
	UPDATE #IncomeBatchDataToExport SET OrderBY = 2 WHERE TransactionTypeName = 'Credit'
	UPDATE #IncomeBatchDataToExport SET OrderBY = 3 WHERE TransactionTypeName IN ('Deposit Applied to Balance', 'Balance Transfer Payment', 'Payment Refund')
	UPDATE #IncomeBatchDataToExport SET OrderBY = 4 WHERE TransactionTypeName = 'Payment'	
	UPDATE #IncomeBatchDataToExport SET OrderBY = 5 WHERE TransactionTypeName = 'AR'
	UPDATE #IncomeBatchDataToExport SET OrderBY = 6 WHERE TransactionTypeName IN ('Deposit', 'Deposit Refund', 'Deposit Applied to Deposit', 'Balance Transfer Deposit')
	
	SELECT	PropertyID,
			AccountingPeriodEndDate,
			ISNULL(LedgerItemTypeAbbreviation, '') AS 'LedgerItemTypeAbbreviation',
			LedgerItemTypeName,
			GLAccountNumber,
			Amount,
			TransactionTypeName
		FROM #IncomeBatchDataToExport
		WHERE Amount <> 0
		ORDER BY PropertyID, OrderBy, GLAccountNumber, LedgerItemTypeAbbreviation

	
	IF (@includeTransactionDetail = 1)
	BEGIN
		SELECT
			#t.*,
			lit.Abbreviation AS 'LedgerItemTypeAbbreviation',
			null AS 'CreditGLNumber',
			null AS 'DebitGLNumber'
		FROM #Transactions #t
			LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = #t.LedgerItemTypeID

	END

END

GO
