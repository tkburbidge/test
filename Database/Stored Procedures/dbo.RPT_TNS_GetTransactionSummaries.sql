SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO






-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 9, 2012
-- Description:	Generates the data for the TransactionSummary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_GetTransactionSummaries] 
	-- Add the parameters for the stored procedure here
	@accountingPeriodID uniqueidentifier = null, 
	@propertyIDs GuidCollection READONLY,
	@periodOnly bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @accountID bigint
	DECLARE @fiscalYearStartDate date
	DECLARE @fiscalYearBegin int
     
    CREATE TABLE #TransactionSummary (
		LedgerItemTypeName nvarchar(50) not null,
		TransactionTypeName nvarchar(50) not null,
		YTDPriorPeriodAmount money null,	
		PeriodAmount money null)
		
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		FiscalYearStartDate date null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #MyTransactions (
		TransactionID uniqueidentifier not null,
		Amount money null,
		TTName nvarchar(50) null,
		LedgerItemTypeName nvarchar(50) null,
		PostingBatchID uniqueidentifier null)

	CREATE NONCLUSTERED INDEX [idx_MyTrans] ON [#MyTransactions]
	( [LedgerItemTypeName] ASC ) INCLUDE (Amount, TTName, PostingBatchID)
		WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

		
	-- Get the fiscal year start date	
	SET @accountID = (SELECT AccountID 
						  FROM AccountingPeriod 
						  WHERE AccountingPeriodID = @accountingPeriodID)

	INSERT #PropertiesAndDates
		SELECT p.PropertyID, null, pap.StartDate, pap.EndDate
			FROM Property p
				INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
	
	UPDATE #PropertiesAndDates SET FiscalYearStartDate = (SELECT dbo.[GetFiscalyearStartDate](@accountID, @accountingPeriodID, #PropertiesAndDates.PropertyID))
	
	-- Add all the Ledger Item Types that will be returned into the temp table
	INSERT INTO #TransactionSummary
	SELECT DISTINCT 
			CASE
				WHEN lit.LedgerItemTypeID IS NOT NULL THEN lit.Name
				ELSE tt.Name 
				END AS 'LedgerItemTypeName',
			--tt.Name AS 'TransactionTypeName',
			CASE WHEN tt.Name IN ('Balance Transfer Payment', 'Deposit Applied to Balance', 'Payment Refund') THEN 'Payment'
				 WHEN tt.Name IN ('Balance Transfer Deposit', 'Deposit Applied to Deposit', 'Deposit Refund') THEN 'Deposit'
				 ELSE tt.Name
			END AS 'TransactionTypeName',
			null AS 'YTDPriorPeriodAmount',
			null AS 'PeriodAmount'
		FROM [Transaction] t
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN Property p ON t.PropertyID = p.PropertyID
			INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
			LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
			LEFT JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
			LEFT JOIN Payment py ON py.PaymentID = pt.PaymentID
			LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID
			LEFT JOIN PostingBatch pb1 ON py.PostingBatchID = pb1.PostingBatchID
		WHERE tt.Name NOT IN ('Prepayment', 'Over Credit')
		  AND tt.[Group] IN ('Lease', 'Non-Resident Account', 'WOIT Account', 'Unit', 'Prospect')
		  AND (((py.PaymentID IS NOT NULL) AND (py.Date >= #pad.FiscalYearStartDate)) OR ((py.PaymentID IS NULL) AND (t.TransactionDate >= #pad.FiscalYearStartDate)))
		  AND (((py.PaymentID IS NOT NULL) AND (py.Date <= #pad.EndDate)) OR ((py.PaymentID IS NULL) AND (t.TransactionDate <= #pad.EndDate)))		  
		  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
		  AND ((pb1.PostingBatchID IS NULL) OR (pb1.IsPosted = 1))				   		 		

			IF NOT EXISTS(SELECT * FROM #TransactionSummary WHERE LedgerItemTypeName = 'Deposit Applied to Balance')		  
			BEGIN
				INSERT INTO #TransactionSummary VALUES ('Deposit Applied to Balance', 'Payment', null, null)		  			   		 		
			END	
			IF NOT EXISTS(SELECT * FROM #TransactionSummary WHERE LedgerItemTypeName = 'Deposit Applied to Deposit')		  
			BEGIN	
				INSERT INTO #TransactionSummary VALUES ('Deposit Applied to Deposit', 'Deposit', null, null)		  			   		 		
			END
			IF NOT EXISTS(SELECT * FROM #TransactionSummary WHERE LedgerItemTypeName = 'Balance Transfer Payment')		  
			BEGIN
				INSERT INTO #TransactionSummary VALUES ('Balance Transfer Payment', 'Payment', null, null)		  			   		 		
			END
			IF NOT EXISTS(SELECT * FROM #TransactionSummary WHERE LedgerItemTypeName = 'Balance Transfer Deposit')		  
			BEGIN		
				INSERT INTO #TransactionSummary VALUES ('Balance Transfer Deposit', 'Deposit', null, null)		  			   		 		
			END
		  
	IF (@periodOnly = 0)
	BEGIN
		-- Sum non-charge Prior Period YTD amounts  

		UPDATE #TransactionSummary SET YTDPriorPeriodAmount = ISNULL(YTDPriorPeriodAmount, 0) + (SELECT Amount	
			-- Sum all the transactions and update the temp table
			FROM (SELECT Payments.LedgerItemTypeName, ISNULL(SUM(Payments.Amount), 0) Amount
					 -- Need to get a distinct list of all transactions in the payment table
					 FROM (SELECT DISTINCT 
								py.PaymentID,
								-- Get the LedgerItemType.Name or the TransactionType.Name for the category
								CASE WHEN lit.LedgerItemTypeID IS NULL THEN tt.Name
									 ELSE lit.Name
								END AS 'LedgerItemTypeName',
								-- Payment and Deposit refund transactions are posted as positive amounts
								-- but we group them in the Payment and Deposit section so they  need to
								-- show as money coming out, thus the negative number
								CASE WHEN tt.Name IN ('Payment Refund', 'Deposit Refund') THEN -py.Amount
									 ELSE py.Amount
								END AS 'Amount'
							FROM Payment py
								INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
								INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
								INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
								INNER JOIN Property p ON t.PropertyID = p.PropertyID
								INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
								LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
								LEFT JOIN PostingBatch pb ON py.PostingBatchID = pb.PostingBatchID
							WHERE  tt.Name IN ('Payment', 'Credit', 'Deposit', 'Payment Refund', 'Deposit Refund')						  
							  AND tt.[Group] IN ('Lease', 'Non-Resident Account', 'WOIT Account', 'Unit', 'Prospect')
							  AND py.Date >= #pad.FiscalYearStartDate
							  --AND py.Date <= DATEADD(day, -1, ap.StartDate)
							  AND py.Date <= DATEADD(day, -1, #pad.StartDate)
							  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
							  -- When we do a balance transfer or a deposit application a Payment or Credit
							  -- is posted to be allocated to charges but no LedgerItemTypeID is specified
							  -- for that transaction.  Don't include those transactions with this condition
							  AND NOT (tt.Name IN ('Payment', 'Credit') AND t.LedgerItemTypeID IS NULL)) Payments
					GROUP BY Payments.LedgerItemTypeName) SummedPayments 	
			WHERE SummedPayments.LedgerItemTypeName = #TransactionSummary.LedgerItemTypeName)	
			
		INSERT #MyTransactions 
			SELECT t.TransactionID, t.Amount, tt.Name, lit.Name, t.PostingBatchID
				FROM [Transaction] t
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
									AND t.TransactionDate >= #pad.FiscalYearStartDate AND t.TransactionDate <= DATEADD(DAY, -1, #pad.StartDate)
					LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				WHERE tt.Name IN ('Charge', 'Deposit Applied to Balance', 'Deposit Applied to Deposit', 'Balance Transfer Payment', 'Balance Transfer Deposit')
				  AND tt.[Group] IN ('Lease', 'Non-Resident Account', 'WOIT Account', 'Unit', 'Prospect')
				 
			   
		UPDATE #TransactionSummary SET YTDPriorPeriodAmount = ISNULL(YTDPriorPeriodAmount, 0) + (SELECT ISNULL(SUM(t.Amount), 0)
																									FROM #MyTransactions t
																										LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID
																									WHERE ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
																									  -- Get the LedgerItemType.Name or the TransactionType.Name for the category
																									  AND (((t.LedgerItemTypeName IS NOT NULL) AND (t.LedgerItemTypeName = #TransactionSummary.LedgerItemTypeName))
																											OR
																										   ((t.LedgerItemTypeName IS NULL) AND (t.TTName = #TransactionSummary.LedgerItemTypeName))))	
			OPTION (RECOMPILE)

		TRUNCATE TABLE #MyTransactions
	END		

	-- See comments above
	UPDATE #TransactionSummary SET PeriodAmount = ISNULL(PeriodAmount, 0) + (SELECT Amount	
		FROM (SELECT Payments.LedgerItemTypeName, ISNULL(SUM(Payments.Amount), 0) Amount
				 FROM (SELECT DISTINCT 
							py.PaymentID,
							CASE WHEN lit.LedgerItemTypeID IS NULL THEN tt.Name
								 ELSE lit.Name
							END AS 'LedgerItemTypeName',
							CASE WHEN tt.Name IN ('Payment Refund', 'Deposit Refund') THEN -py.Amount
								 ELSE py.Amount
							END AS 'Amount'
						FROM Payment py
							INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
							INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
							INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
							INNER JOIN Property p ON t.PropertyID = p.PropertyID
							--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
							LEFT JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
							LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
							LEFT JOIN PostingBatch pb ON py.PostingBatchID = pb.PostingBatchID
						WHERE tt.Name IN ('Payment', 'Credit', 'Deposit', 'Payment Refund', 'Deposit Refund') --('Prepayment', 'Over Credit', 'Charge', 'Deposit Applied to Balance', 'Deposit Applied Deposit', 'Payment Refund', 'Deposit Refund')
						  AND tt.[Group] IN ('Lease', 'Non-Resident Account', 'WOIT Account', 'Unit', 'Prospect')
						  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
						  --AND py.Date >= ap.StartDate
						  --AND py.Date <= ap.EndDate
						  AND py.[Date] >= #pad.StartDate
						  AND py.[Date] <= #pad.EndDate
						  AND NOT (tt.Name IN ('Payment', 'Credit') AND t.LedgerItemTypeID IS NULL)) Payments
				GROUP BY Payments.LedgerItemTypeName) SummedPayments
		WHERE SummedPayments.LedgerItemTypeName = #TransactionSummary.LedgerItemTypeName)	

	INSERT #MyTransactions 
		SELECT t.TransactionID, t.Amount, tt.Name, lit.Name, t.PostingBatchID
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
								AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
			WHERE tt.Name IN ('Charge', 'Deposit Applied to Balance', 'Deposit Applied to Deposit', 'Balance Transfer Payment', 'Balance Transfer Deposit')
			  AND tt.[Group] IN ('Lease', 'Non-Resident Account', 'WOIT Account', 'Unit', 'Prospect')
	
			   
	UPDATE #TransactionSummary SET PeriodAmount = ISNULL(PeriodAmount, 0) + (SELECT ISNULL(SUM(t.Amount), 0)
																				FROM #MyTransactions t
																					LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID
																				WHERE ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
																				  AND (((t.LedgerItemTypeName IS NOT NULL) AND (t.LedgerItemTypeName = #TransactionSummary.LedgerItemTypeName))
																						OR
																					   ((t.LedgerItemTypeName IS NULL) AND (t.TTName = #TransactionSummary.LedgerItemTypeName))))
	OPTION (RECOMPILE)			   

	SELECT 
			LedgerItemTypeName,
			TransactionTypeName,
			ISNULL(YTDPriorPeriodAmount, 0) AS 'YTDPriorPeriodAmount',
			ISNULL(PeriodAmount, 0) AS 'PeriodAmount'
		FROM #TransactionSummary
		ORDER BY TransactionTypeName, LedgerItemTypeName

END
GO
