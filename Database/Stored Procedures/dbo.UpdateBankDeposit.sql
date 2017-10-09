SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Olsen
-- Create date: Dec 4, 2012
-- Description:	Updates a bank deposit including 
--				all associated journal entries
-- =============================================
CREATE PROCEDURE [dbo].[UpdateBankDeposit]
	-- Add the parameters for the stored procedure here
	@accountID bigint,	
	@bankTransactionID uniqueidentifier,
	@date datetime,
	@description nvarchar(500),
	@bankAccountID uniqueidentifier,
	@batchNumber int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	   
   -- Added the following logic when we allowed Bank Deposits to span more than one property.
   -- Get all the TransactionIDs that were included in the bank deposit
	DECLARE @transactionIDs GuidCollection	
	INSERT INTO @transactionIDs SELECT t.TransactionID
								FROM [Transaction] t
									INNER JOIN BankTransactionTransaction btt ON btt.TransactionID = t.TransactionID
								WHERE btt.BankTransactionID = @bankTransactionID

    DECLARE @bankAccountGLAccountID uniqueidentifier = (SELECT GLAccountID FROM BankAccount WHERE AccountID = @accountID AND @bankAccountID = BankAccountID)    
    DECLARE @oldGLAccountID uniqueidentifier = (SELECT GLAccountID FROM BankAccount WHERE BankAccountID = (SELECT TOP 1 ObjectID FROM [Transaction] WHERE TransactionID IN (SELECT Value FROM @transactionIDs)))
    DECLARE @batchID uniqueidentifier = (SELECT BatchID FROM Batch WHERE BankTransactionID = @bankTransactionID)
																																									    
    -- Update the actual bank transaction
    UPDATE [Transaction] SET [Description] = @description, 
							 [TransactionDate] = @date,
							 [ObjectID] = @bankAccountID	
	WHERE TransactionID IN (SELECT Value FROM @transactionIDs)
		AND AccountID = @accountID
	
	-- Update the journal entries for the actual bank transaction
	UPDATE [JournalEntry] SET GLAccountID = @bankAccountGLAccountID		
	WHERE TransactionID IN (SELECT Value FROM @transactionIDs)
		AND Amount > 0
		AND GLAccountID = @oldGLAccountID
		AND AccountID = @accountID

	-- Update the batch description and date
	UPDATE Batch SET [Description] = @description,
					 [Date] = @date,
					 Number = @batchNumber
	WHERE BatchID = @batchID					
		AND AccountID = @accountID 

	UPDATE BankTransaction SET ReferenceNumber = @batchNumber
		WHERE BankTransactionID = @bankTransactionID
			AND AccountID = @accountID
    
	-- Update all the journal entries of edited transactions after the
	-- original payment or deposit was batched
	UPDATE [JournalEntry] SET GLAccountID = @bankAccountGLAccountID	
	WHERE TransactionID IN (SELECT pt.TransactionID
							FROM Payment p 
							INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID							
							WHERE p.BatchID = @batchID)
		AND GLAccountID = @oldGLAccountID
		AND AccountID = @accountID
END
GO
