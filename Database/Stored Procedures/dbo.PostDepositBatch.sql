SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO







-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 13, 2012
-- Description:	Posts a PostingBatch
-- =============================================
CREATE PROCEDURE [dbo].[PostDepositBatch] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@postingBatchID uniqueidentifier = null,
	@postingPersonID uniqueidentifier = null,
	@date date = null,
	@updatePaymentDate bit = 1
AS

DECLARE @objectIDs GuidCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	
	
	UPDATE PostingBatch SET IsPosted = 1, PostingPersonID = @postingPersonID, PostedDate = @date
		WHERE PostingBatchID = @postingBatchID 
		  AND AccountID = @accountID
		  
	IF (@updatePaymentDate = 1)
	BEGIN
		UPDATE [Transaction] SET PersonID = @postingPersonID, TransactionDate = @date
			WHERE PostingBatchID = @postingBatchID
				AND AccountID = @accountID
		
		UPDATE Payment SET [Date] = @date
			WHERE PostingBatchID = @postingBatchID
				AND AccountID = @accountID
	END
	-- Credit deposit gl
	INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis, AccountingBookID)
		SELECT	NEWID() AS 'JournalEntryID',
				@accountID AS 'AccountID',
				lit.GLAccountID AS 'GLAccountID',
				t.TransactionID AS 'TransactionID',
				-1 * t.Amount AS 'Amount',
				'Accrual' AS 'AccountingBasis',
				null
			FROM [Transaction] t
				INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN JournalEntry je ON t.TransactionID = je.TransactionID
			WHERE t.PostingBatchID = @postingBatchID
			  AND t.LedgerItemTypeID IS NOT NULL
			  AND je.JournalEntryID IS NULL
	
	-- Debit undeposited funds		  
	INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis, AccountingBookID)
		SELECT	NEWID() AS 'JournalEntryID',
				@accountID AS 'AccountID',
				tt.GLAccountID AS 'GLAccountID',
				t.TransactionID AS 'TransactionID',
				t.Amount AS 'Amount',
				'Accrual' AS 'AccountingBasis',
				null
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID				
			WHERE t.PostingBatchID = @postingBatchID
			  AND t.LedgerItemTypeID IS NOT NULL	

	-- Credit deposit gl
	INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis, AccountingBookID)	
		SELECT	NEWID() AS 'JournalEntryID',
				@accountID AS 'AccountID',
				lit.GLAccountID AS 'GLAccountID',
				t.TransactionID AS 'TransactionID',
				-1 * t.Amount AS 'Amount',
				'Cash' AS 'AccountingBasis',
				null
			FROM [Transaction] t
				INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID				
			WHERE t.PostingBatchID = @postingBatchID
			  AND t.LedgerItemTypeID IS NOT NULL

	-- Debit undeposited funds		  			  
	INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis, AccountingBookID)
		SELECT	NEWID() AS 'JournalEntryID',
				@accountID AS 'AccountID',
				tt.GLAccountID AS 'GLAccountID',
				t.TransactionID AS 'TransactionID',
				t.Amount AS 'Amount',
				'Cash' AS 'AccountingBasis',
				null
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID				
			WHERE t.PostingBatchID = @postingBatchID
			  AND t.LedgerItemTypeID IS NOT NULL
			  
			  
	SELECT PaymentID FROM Payment WHERE AccountID = @accountID and PostingBatchID = @postingBatchID			  		  

END
GO
