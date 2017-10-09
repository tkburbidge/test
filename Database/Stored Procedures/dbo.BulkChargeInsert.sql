SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 3, 2012
-- Description:	Performs the bulk insert of Charges
-- =============================================
CREATE PROCEDURE [dbo].[BulkChargeInsert] 
	-- Add the parameters for the stored procedure here
	@charges BulkTransactionCollection READONLY, 
	@accountID bigint = null,
	@date date = null,
	@personID uniqueidentifier = null,
	@propertyID uniqueidentifier = null,
	@transactionTypeID uniqueidentifier = null,
	@transactionTypeGLAccountID uniqueidentifier = null,
	@ledgerItemTypeID uniqueidentifier = null,
	@ledgerItemTypeGLAccountID uniqueidentifier = null,
	@description nvarchar(500) = null,
	@notes nvarchar(500) = null,
	@origin nvarchar(20) = null,
	@taxGroupID uniqueidentifier = null
	
AS

DECLARE @objectIDs				GuidCollection
DECLARE @i						int
DECLARE @iMax					int
DECLARE @newTransactionID		uniqueidentifier
DECLARE @ulgid					uniqueidentifier
DECLARE @amount					money

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #Transactions (
		Sequence int identity,
		ULGID uniqueidentifier not null,
		Amount money not null)
		
	INSERT INTO #Transactions
		SELECT ULGID, Amount FROM @charges
		
	SET @iMax = (SELECT MAX(Sequence) FROM #Transactions)
	SET @i = 1
	
	WHILE (@i <= @iMax)
	BEGIN
		SET @newTransactionID = NEWID()
		SELECT @ulgid = ULGID, @amount = Amount FROM #Transactions WHERE Sequence = @i
		INSERT [Transaction] (TransactionID, AccountID, ObjectID, TransactionTypeID, LedgerItemTypeID, PropertyID, PersonID, NotVisible, Origin, 
									Amount, [Description], Note, TransactionDate, IsDeleted, TimeStamp, TaxRateGroupID)
			VALUES (@newTransactionID, @accountID, @ulgid, @transactionTypeID, @ledgerItemTypeID, @propertyID, @personID, 0, @origin,
									@amount, @description, @notes, @date, 0, GETDATE(), @taxGroupID)
		INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
			VALUES (NEWID(), @accountID, @transactionTypeGLAccountID, @newTransactionID, @amount, 'Accrual')
		INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
			VALUES (NEWID(), @accountID, @ledgerItemTypeGLAccountID, @newTransactionID, -1*@amount, 'Accrual')
		SET @i = @i + 1
	END

	INSERT @objectIDs 
		SELECT DISTINCT ULGID FROM #Transactions
		
	EXEC ApplyAvailableBalance @objectIDs, @personID, @date

END
GO
