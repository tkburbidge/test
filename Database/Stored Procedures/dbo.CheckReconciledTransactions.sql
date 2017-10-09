SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 6, 2014
-- Description:	Checks reconciled bank transactions
-- =============================================
CREATE PROCEDURE [dbo].[CheckReconciledTransactions] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@bankAccountID uniqueidentifier = null,
	@bankTransactionIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #BankTransactionReconciled (
		RTransactionID uniqueidentifier not null)

	CREATE TABLE #TransactionsForThisObject (
		BankTransactionID uniqueidentifier not null,
		TransactionID uniqueidentifier not null)
		
	INSERT #BankTransactionReconciled 
		SELECT Value FROM @bankTransactionIDs
			
	INSERT #TransactionsForThisObject
		SELECT DISTINCT bt.BankTransactionID, t.TransactionID
			FROM BankTransaction bt 
				INNER JOIN Payment pay ON bt.ObjectID = pay.PaymentID
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			WHERE bt.BankTransactionID IN (SELECT RTransactionID FROM #BankTransactionReconciled)
				-- Don't worry about NSFs and Credit Card Recaptures as these won't have 
				-- a Transaction.ObjectID of the bank account but these can't be changed so 
				-- no worries
				AND pay.[Type] NOT IN ('NSF', 'Credit Card Recapture')
			  --AND t.ObjectID = @bankAccountID
	
	INSERT #TransactionsForThisObject 
		SELECT DISTINCT bt.BankTransactionID, t.TransactionID
			FROM BankTransaction bt 
				INNER JOIN BankTransactionTransaction btt ON bt.BankTransactionID = btt.BankTransactionID
				INNER JOIN [Transaction] t ON btt.TransactionID = t.TransactionID
			WHERE bt.BankTransactionID IN (SELECT RTransactionID FROM #BankTransactionReconciled)
			  --AND t.ObjectID = @bankAccountID

	INSERT #TransactionsForThisObject 
		SELECT DISTINCT bt.BankTransactionID, t.TransactionID
			FROM BankTransaction bt 
				INNER JOIN [Transaction] t ON bt.ObjectID = t.TransactionID
			WHERE bt.BankTransactionID IN (SELECT RTransactionID FROM #BankTransactionReconciled)
			  --AND t.ObjectID = @bankAccountID
			  
	SELECT #tfto.BankTransactionID
		FROM #TransactionsForThisObject #tfto
			INNER JOIN [Transaction] t ON #tfto.TransactionID = t.TransactionID
		WHERE t.ObjectID <> @bankAccountID
		
				
END
GO
