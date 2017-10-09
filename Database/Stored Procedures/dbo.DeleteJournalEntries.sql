SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: July 10, 2012
-- Description:	Deletes a set of manual journal entries
-- =============================================
CREATE PROCEDURE [dbo].[DeleteJournalEntries]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@transactionGroupID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @transactionIDs TABLE (
		ID uniqueidentifier NOT NULL
	)
	
	INSERT INTO @transactionIDs
			SELECT TransactionID 
			FROM TransactionGroup
			WHERE AccountID = @accountID 
				AND TransactionGroupID = @transactionGroupID
				
	-- Delete the journal entries
	DELETE FROM JournalEntry 
	WHERE AccountID = @accountID 
	      AND TransactionID IN (SELECT ID FROM @transactionIDs) 
								
	-- Delete the Bank Transactions if there are any
	DELETE FROM BankTransaction
	WHERE AccountID = @accountID 
	      AND ObjectID IN (SELECT ID FROM @transactionIDs) 
	      
	-- Delete the Transactions
	DELETE FROM [Transaction]
	WHERE AccountID = @accountID 
	      AND TransactionID IN (SELECT ID FROM @transactionIDs) 
	      
	-- Delete the TransactionGroup records
	DELETE FROM TransactionGroup
	WHERE AccountID = @accountID 
	      AND TransactionGroupID = @transactionGroupID
										    
END
GO
