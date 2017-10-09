SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[UpdateTransactionsToNewObjectID] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@propertyID uniqueidentifier,
	@newObjectID uniqueidentifier = null, 
	@oldObjectID uniqueidentifier = null,
	@transferDeposits bit = 0,
	@transferNonDeposits bit = 0
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	UPDATE [Transaction] SET ObjectID = @newObjectID WHERE ObjectID = @oldObjectID AND AccountID = @accountID AND PropertyID = @propertyID
	
	UPDATE Payment
		SET ObjectID = @newObjectID					
		FROM Payment p			
			INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
			INNER JOIN [Transaction] t on t.TransactionID = pt.TransactionID
		WHERE p.ObjectID = @oldObjectID			
			AND t.PropertyID = @propertyID
			AND p.AccountID = @accountID

	--IF (@transferDeposits = 1)
	--BEGIN
	--	UPDATE [Transaction] 
	--		SET ObjectID = @newObjectID
	--		WHERE ObjectID = @oldObjectID
	--		  AND TransactionTypeID IN (SELECT TransactionTypeID
	--										FROM TransactionType
	--										WHERE AccountID = @accountID
	--										  AND Name = 'Deposit')
	--										  --AND [Group] = 'Lease')
	--END
	--IF (@transferNonDeposits = 1)
	--BEGIN
	--	UPDATE [Transaction] 
	--		SET ObjectID = @newObjectID
	--		WHERE ObjectID = @oldObjectID
	--		  AND TransactionTypeID IN (SELECT TransactionTypeID
	--										FROM TransactionType
	--										WHERE AccountID = @accountID
	--										  AND Name IN ('Charge', 'Payment', 'Credit'))
	--										  --AND [Group] = 'Lease')
	--END			
END
GO
