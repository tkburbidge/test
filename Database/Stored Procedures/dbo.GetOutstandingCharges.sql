SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 26, 2011
-- Description:	This Stored Procedure sums up a All Charges for a given PersionID (ObjectID) less payments, even partial payments.
-- =============================================
CREATE PROCEDURE [dbo].[GetOutstandingCharges] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@objectID uniqueidentifier = null,
	@transactionTypeGroup nvarchar(20) = null,
	@currentLeaseOnly bit = 0,
	@date date = null,
	@includeFuturePayments bit = 1,
	@includePaymentsOnDate bit = 1
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    CREATE TABLE #TempTransactionsBlue (
		ObjectID			uniqueidentifier		NOT NULL,
		TransactionID		uniqueidentifier		NOT NULL,
		Amount				money					NOT NULL,
		TaxAmount			money					NULL,
		TaxesPaid			money					NULL,
		UnPaidAmount		money					NULL,
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
		
	INSERT #TempTransactionsBlue 


		SELECT  ObjectID, 
				TransactionID, 
				Amount, 0, 0, 0, 
				[Transaction].[Description], 
				TransactionDate, 
				(CASE WHEN [Transaction].TaxRateID IS NOT NULL THEN tr.GLAccountID
					 ELSE lit.GLAccountID
				END), 
				lit.OrderBy, 
				[Transaction].TaxRateGroupID, 
				lit.LedgerItemTypeID, 
				lit.Abbreviation, 
				(CASE WHEN [Transaction].TaxRateID IS NOT NULL THEN trgl.Number
					 ELSE gl.Number
				END),	
				lit.IsWriteOffable, 
				[Transaction].Note,
				[Transaction].TaxRateID
			FROM [Transaction] 
				INNER JOIN [TransactionType]  ON [Transaction].[TransactionTypeID] = [TransactionType].[TransactionTypeID]
				LEFT JOIN [LedgerItemType] lit  ON [Transaction].[LedgerItemTypeID] = lit.[LedgerItemTypeID] 
				LEFT JOIN [GLAccount] gl ON lit.GLAccountID = gl.GLAccountID
				LEFT JOIN [PostingBatch] pb ON [Transaction].PostingBatchID = pb.PostingBatchID	
				LEFT JOIN TaxRate tr ON tr.TaxRateID = [Transaction].TaxRateID					
				LEFT JOIN GLAccount trgl ON trgl.GLAccountID = tr.GLAccountID	
			WHERE [Transaction].AccountID = @accountID
				AND [Transaction].PropertyID = @propertyID
				AND ((@date IS NULL) OR ([Transaction].TransactionDate <= @date))
				AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
				AND (([TransactionType].[Group] = @transactionTypeGroup) OR ([TransactionType].[Group] = 'Tax'))
				--AND [TransactionType].[Name] IN ('Charge', 'Tax Charge')
				--AND ObjectID = @objectID
				AND ((@objectID IS NULL) OR ([Transaction].ObjectID = @objectID))
				-- Ensure that the charge wasn't transferred to a different unit lease group
				AND (([TransactionType].[Name] = 'Charge') AND ([Transaction].AppliesToTransactionID IS NULL))
				AND [Transaction].ReversesTransactionID IS NULL
				-- Ensure that the Charge Transaction has not been reversed
				AND NOT EXISTS (SELECT * 
								FROM [Transaction] t2 
								WHERE [Transaction].TransactionID = t2.ReversesTransactionID)
				-- If @currentLeasesOnly bit is set, only return ObjectIDs associated to current leases.
				AND ((@currentLeaseOnly = 0) OR (0 < (SELECT COUNT(*)
														  FROM Lease
														  WHERE LeaseStatus IN ('Current', 'Under Eviction')
														    AND UnitLeaseGroupID = [Transaction].ObjectID)))
								
--select * from #TempTransactions								
						
	UPDATE #TempTransactionsBlue SET UnPaidAmount = (SELECT #TempTransactionsBlue.Amount - ISNULL(SUM(t.Amount), 0) 
		FROM [Transaction] t
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
			INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
		WHERE t.AppliesToTransactionID = #TempTransactionsBlue.TransactionID 
			  AND tt.Name NOT IN ('Tax Charge')
			  -- Ensure that the Payment Transaction has not been reversed
			  AND NOT EXISTS (SELECT * 
						  FROM [Transaction] t2 
						  WHERE t.TransactionID = t2.ReversesTransactionID)
			  -- Ensure that the Payment was made on or prior the the date passed in, if a date was passed in
			  AND ((@includeFuturePayments = 1) OR (@date IS NULL) OR (@includePaymentsOnDate = 1 AND pay.[Date] <= @date) OR (@includePaymentsOnDate = 0 AND pay.[Date] < @date)))
						  
	--UPDATE #TempTransactionsBlue SET TaxAmount = (SELECT ISNULL(SUM(t.Amount), 0) 
	--	FROM [Transaction] t
	--		INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
	--	WHERE t.AppliesToTransactionID = #TempTransactionsBlue.TransactionID 
	--		  AND tt.Name IN ('Tax Charge')
	--		  -- Ensure that the Payment Transaction has not been reversed
	--		  AND NOT EXISTS (SELECT * 
	--					  FROM [Transaction] t2 
	--					  WHERE t.TransactionID = t2.ReversesTransactionID))
						  
	--UPDATE #TempTransactionsBlue SET TaxesPaid = (SELECT ISNULL(SUM(ta.Amount), 0)
	--	FROM [Transaction] t
	--		INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
	--		INNER JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
	--		INNER JOIN [TransactionType] tta ON ta.TransactionTypeID = tta.TransactionTypeID
	--	WHERE t.AppliesToTransactionID = #TempTransactionsBlue.TransactionID
	--		  AND ((tta.Name IN ('Tax Payment')) OR (tta.Name IN ('Tax Credit')))
	--		  -- Ensure that the original Credit hasn't been reversed, reversing the Tax Credits.
	--		  AND NOT EXISTS (SELECT * 
	--					  FROM [Transaction] t2 
	--					  WHERE t.TransactionID = t2.ReversesTransactionID))	
	
	IF (@objectID IS NULL)
	BEGIN
		IF (1 = (SELECT OrderChargesByDate FROM Settings WHERE AccountID = @accountID))
		BEGIN
			SELECT ObjectID as [ObjectID], TransactionID as [TransactionID], Amount as [OriginalAmount], TaxAmount as [TaxAmount], UnPaidAmount as [UnpaidAmount],
					TaxAmount - TaxesPaid as [TaxUnpaidAmount], [Description] as [Description], TranDate as [TransactionDate], [GLAccountID] as [GLAccountID],
					[OrderBy] as [OrderBy], [TaxRateGroupID] as [TaxRateGroupID], [LedgerItemTypeID] as [LedgerItemTypeID], LedgerItemTypeAbbr, GLNumber, IsWriteOffable,
					Notes, TaxRateID
				FROM #TempTransactionsBlue
					INNER JOIN Settings s ON s.AccountID = @accountID
				WHERE (UnPaidAmount + TaxAmount - TaxesPaid) > 0
				ORDER BY TranDate, OrderBy
		END
		ELSE
		BEGIN
			SELECT ObjectID as [ObjectID], TransactionID as [TransactionID], Amount as [OriginalAmount], TaxAmount as [TaxAmount], UnPaidAmount as [UnpaidAmount],
					TaxAmount - TaxesPaid as [TaxUnpaidAmount], [Description] as [Description], TranDate as [TransactionDate], [GLAccountID] as [GLAccountID],
					[OrderBy] as [OrderBy], [TaxRateGroupID] as [TaxRateGroupID], [LedgerItemTypeID] as [LedgerItemTypeID], LedgerItemTypeAbbr, GLNumber, IsWriteOffable,
					Notes, TaxRateID
				FROM #TempTransactionsBlue
					INNER JOIN Settings s ON s.AccountID = @accountID
				WHERE (UnPaidAmount + TaxAmount - TaxesPaid) > 0
				ORDER BY OrderBy, TranDate
		END	
	END
	ELSE
	BEGIN
		IF (1 = (SELECT OrderChargesByDate FROM Settings WHERE AccountID = @accountID))
		BEGIN
			SELECT ObjectID as [ObjectID], TransactionID as [TransactionID], Amount as [OriginalAmount], TaxAmount as [TaxAmount], UnPaidAmount as [UnpaidAmount],
					TaxAmount - TaxesPaid as [TaxUnpaidAmount], [Description] as [Description], TranDate as [TransactionDate], [GLAccountID] as [GLAccountID],
					[OrderBy] as [OrderBy], [TaxRateGroupID] as [TaxRateGroupID], [LedgerItemTypeID] as [LedgerItemTypeID], LedgerItemTypeAbbr, GLNumber, IsWriteOffable,
					Notes, TaxRateID
				FROM #TempTransactionsBlue
					INNER JOIN Settings s ON s.AccountID = @accountID
				WHERE (UnPaidAmount + TaxAmount - TaxesPaid) > 0
				ORDER BY TranDate, OrderBy
		END
		ELSE
		BEGIN
			SELECT ObjectID as [ObjectID], TransactionID as [TransactionID], Amount as [OriginalAmount], TaxAmount as [TaxAmount], UnPaidAmount as [UnpaidAmount],
					TaxAmount - TaxesPaid as [TaxUnpaidAmount], [Description] as [Description], TranDate as [TransactionDate], [GLAccountID] as [GLAccountID],
					[OrderBy] as [OrderBy], [TaxRateGroupID] as [TaxRateGroupID], [LedgerItemTypeID] as [LedgerItemTypeID], LedgerItemTypeAbbr, GLNumber, IsWriteOffable,
					Notes, TaxRateID
				FROM #TempTransactionsBlue
					INNER JOIN Settings s ON s.AccountID = @accountID
				WHERE (UnPaidAmount + TaxAmount - TaxesPaid) > 0
				ORDER BY OrderBy, TranDate
		END
	END
		
END
GO
