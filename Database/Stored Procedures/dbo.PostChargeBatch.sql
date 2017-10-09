SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 13, 2012
-- Description:	Posts a PostingBatch
-- =============================================
CREATE PROCEDURE [dbo].[PostChargeBatch] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@postingBatchID uniqueidentifier = null,
	@postingPersonID uniqueidentifier = null,
	@date date = null
AS

DECLARE @objectIDs GuidCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	UPDATE PostingBatch SET IsPosted = 1, PostingPersonID = @postingPersonID, PostedDate = @date
		WHERE PostingBatchID = @postingBatchID 
		  AND AccountID = @accountID
	
	UPDATE [Transaction] SET PersonID = @postingPersonID, [TransactionDate] = @date, [TimeStamp] = GETUTCDATE()
		WHERE PostingBatchID = @postingBatchID			
		
	INSERT @objectIDs SELECT DISTINCT t.ObjectID
		FROM [Transaction] t 
		WHERE t.PostingBatchID = @postingBatchID
	
	INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)	
		SELECT	NEWID() AS 'JournalEntryID',
				@accountID AS 'AccountID',
				lit.GLAccountID AS 'GLAccountID',
				t.TransactionID AS 'TransactionID',
				-1 * t.Amount AS 'Amount',
				'Accrual' AS 'AccountingBasis'
			FROM [Transaction] t
				INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN JournalEntry je ON t.TransactionID = je.TransactionID
			WHERE t.PostingBatchID = @postingBatchID
			  AND t.LedgerItemTypeID IS NOT NULL
			  AND je.JournalEntryID IS NULL
			  AND t.SalesTaxForTransactionID IS NULL				

			  
	INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)	
		SELECT	NEWID() AS 'JournalEntryID',
				@accountID AS 'AccountID',
				tt.GLAccountID AS 'GLAccountID',
				t.TransactionID AS 'TransactionID',
				t.Amount AS 'Amount',
				'Accrual' AS 'AccountingBasis'
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				--LEFT JOIN JournalEntry je ON t.TransactionID = je.TransactionID
			WHERE t.PostingBatchID = @postingBatchID
			  AND t.LedgerItemTypeID IS NOT NULL
			  --AND je.JournalEntryID IS NULL
			  AND t.SalesTaxForTransactionID IS NULL				


	IF (0 < (SELECT COUNT(TransactionID) FROM [Transaction] WHERE PostingBatchID = @postingBatchID AND SalesTaxForTransactionID IS NOT NULL))
	BEGIN
		CREATE TABLE #SalesTaxTransactionIDs (
			TransactionID			uniqueidentifier null)

		INSERT #SalesTaxTransactionIDs
			SELECT TransactionID
				FROM [Transaction]
				WHERE PostingBatchID = @postingBatchID
				  AND SalesTaxForTransactionID IS NOT NULL

		INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
			SELECT	NEWID() AS 'JournalEntryID',
					@accountID,
					tt.GLAccountID AS 'GLAccountID',
					originalT.TransactionID,
					originalT.Amount AS 'Amount',
					'Accrual' AS 'AccountingBasis'
				FROM #SalesTaxTransactionIDs #stt
					INNER JOIN [Transaction] originalT ON #stt.TransactionID = originalT.TransactionID
					INNER JOIN TransactionType tt ON originalT.TransactionTypeID = tt.TransactionTypeID

		INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
			SELECT	NEWID() AS 'JournalEntryID',
					@accountID,
					rate..GLAccountID AS 'GLAccountID',
					originalT.TransactionID,
					-originalT.Amount AS 'Amount',
					'Accrual' AS 'AccountingBasis'
				FROM #SalesTaxTransactionIDs #stt
					INNER JOIN [Transaction] originalT ON #stt.TransactionID = originalT.TransactionID
					INNER JOIN TaxRate rate ON originalT.TaxRateID = rate.TaxRateID
	END
		
	EXEC ApplyAvailableBalance @objectIDs, @postingPersonID, @date, null
	
END



GO
