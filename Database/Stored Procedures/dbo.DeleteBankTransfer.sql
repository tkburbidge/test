SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: March 18, 2013
-- Description:	Deletes a bank transfer.  
--				Can't do in EF due to cyclical dependency
-- =============================================
create PROCEDURE [dbo].[DeleteBankTransfer]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@fromTransactionID uniqueidentifier,
	@toTransactionID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DELETE FROM BankTransaction WHERE ObjectID = @fromTransactionID AND AccountID = @accountID
	DELETE FROM BankTransaction WHERE ObjectID = @toTransactionID AND AccountID = @accountID
	
	DELETE FROM JournalEntry WHERE TransactionID = @fromTransactionID AND AccountID = @accountID
	DELETE FROM JournalEntry WHERE TransactionID = @toTransactionID AND AccountID = @accountID
	
	DELETE FROM [Transaction] WHERE TransactionID = @fromTransactionID AND AccountID = @accountID
	DELETE FROM [Transaction] WHERE TransactionID = @toTransactionID AND AccountID = @accountID
END
GO
