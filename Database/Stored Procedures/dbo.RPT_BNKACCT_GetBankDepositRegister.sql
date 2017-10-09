SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 29, 2012
-- Description:	Generates the data for the BankDepositRegister Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_BNKACCT_GetBankDepositRegister] 
	-- Add the parameters for the stored procedure here
	@bankAccountID uniqueidentifier = null, 
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Deposits
	(
		BankTransactionID uniqueidentifier, 
		BatchID uniqueidentifier,
		[Type] nvarchar(100) null,
		[Date] date,
		Reference nvarchar(100),
		[Description] nvarchar(500),
		Amount money,
		ClearedDate date null,
		PaymentAmount money,
		DepositAmount money
	)
	
	DECLARE @accountID bigint = (SELECT AccountID FROM BankAccount WHERE BankAccountID = @bankAccountID)

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
																
	INSERT INTO #Deposits
		SELECT 
				bt.BankTransactionID AS 'BankTransactionID',
				b.BatchID,
				'Bank Deposit' AS 'Type',
				MIN(t.TransactionDate) AS 'Date',  -- Should all be the same
				bt.ReferenceNumber AS 'Reference',
				MIN(t.[Description]) AS 'Description', -- Should all be the same
				SUM(t.Amount) AS 'Amount',
				bt.ClearedDate AS 'ClearedDate',
				0,
				0	
			FROM BankTransaction bt
				INNER JOIN Batch b ON b.BankTransactionID = bt.BankTransactionID
				INNER JOIN BankTransactionTransaction btt ON btt.BankTransactionID = bt.BankTransactionID
				INNER JOIN [Transaction] t ON btt.TransactionID = t.TransactionID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID						
			WHERE ba.BankAccountID = @bankAccountID
			  AND t.TransactionDate >= @startDate
			  AND t.TransactionDate <= @endDate
			GROUP BY bt.BankTransactionID, b.BatchID, bt.ReferenceNumber, bt.ClearedDate
	
	UPDATE #Deposits SET
		PaymentAmount = ISNULL((SELECT SUM(Amount)
								FROM  (SELECT DISTINCT pay.PaymentID, pay.Amount
										FROM Payment pay
											INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
											INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
															AND t.TransactionID = (SELECT TOP 1 t1.TransactionID 
																						FROM [Transaction] t1
																						INNER JOIN TransactionType tt1 ON t1.TransactionTypeID = tt1.TransactionTypeID AND tt1.Name IN ('Payment')
																						INNER JOIN PaymentTransaction pt1 ON t1.TransactionID = pt1.TransactionID																		
																						WHERE pt1.PaymentID = pay.PaymentID
																						AND t1.ObjectID = t.ObjectID
																						-- Deposit applications will not have a LedgerItemTypeID
																						AND t1.LedgerItemTypeID IS NOT NULL
																						ORDER BY t1.TimeStamp)				
										WHERE pay.BatchID = #Deposits.BatchID
											AND pay.[Type] NOT IN ('NSF', 'Credit Card Recapture')) payments), 0),		
		DepositAmount = ISNULL((SELECT SUM(Amount)
						FROM (SELECT DISTINCT pay.PaymentID, pay.Amount
								FROM Payment pay
								INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
								INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
												AND t.TransactionID = (SELECT TOP 1 t1.TransactionID 
																		 FROM [Transaction] t1
																			INNER JOIN TransactionType tt1 ON t1.TransactionTypeID = tt1.TransactionTypeID AND tt1.Name IN ('Deposit')
																			INNER JOIN PaymentTransaction pt1 ON t1.TransactionID = pt1.TransactionID																
																		  WHERE pt1.PaymentID = pay.PaymentID
																			AND t1.ObjectID = t.ObjectID
																			-- Deposit applications will not have a LedgerItemTypeID
																			AND t1.LedgerItemTypeID IS NOT NULL
																		  ORDER BY t1.TimeStamp)				
							WHERE pay.BatchID = #Deposits.BatchID
								AND pay.[Type] NOT IN ('NSF', 'Credit Card Recapture')) Deposits), 0)		

	INSERT INTO #Deposits
		SELECT DISTINCT
				bt.BankTransactionID AS 'BankTransactionID',
				b.BatchID,
				py.[Type] AS 'Type',
				py.[Date] AS 'Date',
				bt.ReferenceNumber AS 'Reference',
				py.[Description] AS 'Description',
				py.Amount AS 'Amount',
				bt.ClearedDate AS 'ClearedDate',
				0 AS 'PaymentAmount',
				0 AS 'DepositAmount'
			FROM Payment py
				INNER JOIN BankTransaction bt ON py.PaymentID = bt.ObjectID
				INNER JOIN Batch b ON py.BatchID = b.BatchID
				INNER JOIN BankTransactionTransaction btt ON b.BankTransactionID = btt.BankTransactionID
				INNER JOIN [Transaction] t ON btt.TransactionID = t.TransactionID				
			WHERE py.[Type] IN ('NSF', 'Credit Card Recapture')
			  AND t.ObjectID = @bankAccountID
			  AND py.Amount < 0			 
			  AND py.[Date] >= @startDate
			  AND py.[Date] <= @endDate		

	
	SELECT * FROM #Deposits
	ORDER BY [Date], Reference
	
END
GO
