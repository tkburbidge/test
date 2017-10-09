SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Art Olsen
-- Create date: Jan. 29, 2014
-- Description:	Post recurring vendor payments
-- =============================================


CREATE PROCEDURE [dbo].[TSK_PostRecurringVendorPayments]
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@itemType nvarchar(50) = null,
	@date date,
	@postData VendorPaymentTemplatePostData READONLY,
	@postingPersonID uniqueIdentifier = null
AS

DECLARE @ctr int = 1
DECLARE @maxCtr int
DECLARE @lineItemCtr int
DECLARE @maxLineItemCtr int
DECLARE @newTransactionID uniqueidentifier
DECLARE @newPaymentID uniqueidentifier
DECLARE @recurringItemID uniqueidentifier
DECLARE @vendorPaymentTemplateID uniqueidentifier
DECLARE @vendorPayemntJournalEntryTemplateID uniqueidentifier

DECLARE @bankAccountID uniqueidentifier
DECLARE @personID uniqueidentifier
DECLARE @recurringItemName nvarchar(600)
DECLARE @assignedToPersonID uniqueidentifier
DECLARE @addedDate datetime
DECLARE @checkNumber int
DECLARE @memo nvarchar(100)
DECLARE @doNotUpdateNextcheckNumber bit
DECLARE @bankGLAccountID uniqueidentifier
DECLARE @paymentMethod nvarchar(50)

DECLARE @transactionOrigin nvarchar(1)
DECLARE @totalAmount money
DECLARE @lineItemAmount money
DECLARE @isCredit bit
DECLARE @transactionTypeID uniqueidentifier
DECLARE @propertyID uniqueidentifier
DECLARE @vendorID uniqueidentifier
DECLARE @vendorPaymentAmount money
DECLARE @vendorPaymentjournalEntryAmount money
DECLARE @vendorPaymentjournalEntryGLAccountID uniqueidentifier
DECLARE @payTo nvarchar(500)
DECLARE @referenceNumber nvarchar(25)
declare @notes nvarchar(425)
DECLARE @NewLineChar AS CHAR(2) = CHAR(13) + CHAR(10)
DECLARE @reportOn1099 bit
DECLARE @objectID uniqueidentifier
DECLARE @objectType nvarchar(100)
DECLARE @objectName nvarchar(100)

DECLARE @newAlertTaskID uniqueidentifier
/*
DECLARE @newInvoiceID uniqueidentifier
*/
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	

	CREATE TABLE #RecurringItems (
		Sequence	int identity not null,
		RecurringItemID uniqueidentifier not null,
		AccountID bigint not null,
		PersonID uniqueidentifier not null,
		Name nvarchar(500) null,
		AssignedToPersonID uniqueidentifier not null)
		
	CREATE TABLE #RecurringLineItems (
		Sequence	int identity not null,
		VendorPaymentJournalEntryTemplateID uniqueidentifier not null)
		
	-- If we aren't posting a particular set of RecurringItems then get all
	-- RecurringItems for the given date.  Otherwise, just post get 
	-- the recurring items of the IDs passed in
	IF (0 = (SELECT COUNT(*) FROM @postData))
	BEGIN
			
		CREATE TABLE #RecurringItems2 (
		Sequence	int identity not null,
		RecurringItemID uniqueidentifier not null,
		AccountID bigint not null,
		PersonID uniqueidentifier not null,
		Name nvarchar(500) null,
		AssignedToPersonID uniqueidentifier not null)
				
		INSERT INTO #RecurringItems2 EXEC GetRecurringItemsByType @accountID, @itemType, @date
		
		INSERT INTO #RecurringItems ( RecurringItemID, AccountID, PersonID, Name, AssignedToPersonID)
			SELECT ri2.RecurringItemID, ri2.AccountID, ri2.PersonID, ri2.Name, ri2.AssignedToPersonID
			FROM #RecurringItems2 ri2
		
		SET @transactionOrigin = 'R'
	END
	ELSE
	BEGIN
		INSERT INTO #RecurringItems 
			SELECT r.RecurringItemID, r.AccountID, r.PersonID, r.Name, r.AssignedToPersonID
			FROM RecurringItem r 
				JOIN @postData pd on r.RecurringItemID = pd.RecurringItemID 
			WHERE r.RecurringItemID IN (SELECT RecurringItemID FROM @postData)
		SET @transactionOrigin = 'U'
	END
	
	SET @maxCtr = (SELECT MAX(Sequence) FROM #RecurringItems)		
	--SELECT @maxCtr
	--SELECT * FROM #RecurringItems
	WHILE (@ctr <= @maxCtr)
	BEGIN
		-- Get the RecurringItem info
		SELECT @recurringItemID = RecurringItemID, @accountID = AccountID, @personID = PersonID,
		 @recurringItemName = Name, @assignedToPersonID = AssignedToPersonID
			FROM #RecurringItems ri
			WHERE Sequence = @ctr
		-- get the vendorPaymentTemplateData we will need
		SELECT	@bankAccountID = vpt.BankAccountID,
				@totalAmount = vpt.Amount, 
				@isCredit = vpt.IsCredit, 
				@propertyID = vpt.PropertyID, 
				@memo = COALESCE(pd.Memo, vpt.Memo),
				@bankGLAccountID = ba.GLAccountID,
				@vendorPaymentTemplateID = vpt.VendorPaymentTemplateID,
				@vendorID = vpt.VendorID, 
				@payTo = v.CompanyName,
				@paymentMethod = vpt.PaymentMethod,
				@doNotUpdateNextcheckNumber = vpt.DoNotUpdateNextCheckNumber,
				@checkNumber = ba.NextCheckNumber,
				@notes = v.CompanyName + @NewLineChar + 
						coalesce(a.StreetAddress, '') + @NewLineChar +
						coalesce(a.City, '')  + ', ' + coalesce(a.[State], '') + ' ' + coalesce(a.Zip, ''),
				@referenceNumber = pd.CheckNumber
		FROM VendorPaymentTemplate vpt
		JOIN BankAccount ba ON vpt.BankAccountID = ba.BankAccountID
		JOIN Vendor v ON v.VendorID = vpt.VendorID
		JOIN VendorPerson vp ON v.VendorID = vp.VendorID
		JOIN Person per ON vp.PersonID = per.PersonID
		JOIN PersonType pert ON per.PersonID = pert.PersonID
		JOIN [Address] a ON per.PersonID = a.ObjectID
		LEFT JOIN @postData pd ON vpt.RecurringItemID = pd.RecurringItemID 
		WHERE vpt.RecurringItemID = @recurringItemID and pert.[Type] = 'VendorPayment'
		
		-- get the transactiontypeid		
		-- Note that if this is a vendor credit then the journal entry
		-- needs to debit the bank account GL Account
		IF (@isCredit = 0)
		BEGIN
			SELECT @transactionTypeID = TransactionTypeID
			FROM TransactionType
			WHERE Name = 'Check' AND [Group] = 'Bank' AND AccountID = @accountID
			SET @vendorPaymentAmount = -@totalAmount
		END
		ELSE
		BEGIN
			SELECT @transactionTypeId = TransactionTypeID
			FROM TransactionType
			WHERE Name = 'Vendor Credit' AND [Group] = 'Bank' AND AccountID = @accountID
			SET @vendorPaymentAmount = @totalAmount
		END
		-- create a transaction entry
		SET @newTransactionID = NEWID()
		DECLARE @distributionJournalEntryIDs nvarchar(max) = ''
		
		INSERT INTO [Transaction] 
			(TransactionID,
			AccountID,
			ObjectID,
			TransactionTypeID,
			Amount,
			PersonID,
			PropertyID,
			TransactionDate,
			Origin,
			[Description],
			IsDeleted,
			NotVisible,
			[TimeStamp]) 
		VALUES 
			(@newTransactionID,
			@accountID,
			@bankAccountID,
			@transactionTypeId,
			@totalAmount,
			@personID,
			@propertyID,
			@date,
			@transactionOrigin,
			ISNULL(@memo, @payTo),
			0,
			0,
			GETUTCDATE())
			
		-- bank Cash JE		
		INSERT INTO [JournalEntry]
			(JournalEntryID,
			AccountID,
			GLAccountID,
			TransactionID,
			Amount,
			AccountingBasis)
		VALUES
			(NEWID(),
			@accountID,
			@bankGLAccountID,
			@newTransactionID,
			@vendorPaymentAmount,
			'Cash')
		-- bank Accrual je
		INSERT INTO [JournalEntry]
			(JournalEntryId,
			AccountID,
			GLAccountID,
			TransactionID,
			Amount,
			AccountingBasis)
		VALUES
			(NEWID(),
			@accountID,
			@bankGLAccountID,
			@newTransactionID,
			@vendorPaymentAmount,
			'Accrual')
		
		-- work the template line items
		INSERT INTO #RecurringLineItems 
			SELECT VendorPaymentJournalEntryTemplateID 
				FROM VendorPaymentJournalEntryTemplate 
				WHERE VendorPaymentTemplateID = @vendorPaymentTemplateID
				
		SET @maxLineItemCtr = (SELECT MAX(Sequence) FROM #RecurringLineItems)
		SET @lineItemCtr = 1
		WHILE (@lineItemCtr <= @maxLineItemCtr)
		BEGIN
			SELECT @vendorPayemntJournalEntryTemplateID = VendorPaymentJournalEntryTemplateID
			FROM #RecurringLineItems
			WHERE Sequence = @lineItemCtr
			
			SELECT @vendorPaymentjournalEntryGLAccountID = GLAccountID, 
				   @vendorPaymentjournalEntryAmount = Amount,
				   @reportOn1099 = ReportOn1099,
				   @objectID = ObjectID,
				   @objectType = ObjectType,
				   @objectName = Objectname
			FROM VendorPaymentJournalEntryTemplate
			WHERE VendorPaymentJournalEntryTemplateID = @vendorPayemntJournalEntryTemplateID				
			
			-- Distribution Cash Entry
			DECLARE @cashJournalEntryID uniqueidentifier = NEWID()
			INSERT INTO [JournalEntry]
				(JournalEntryId,
				AccountID,
				GLAccountID,
				TransactionID,
				Amount,
				AccountingBasis)
			VALUES
				(@cashJournalEntryID,
				@accountID,
				@vendorPaymentjournalEntryGLAccountID,
				@newTransactionID,
				@vendorPaymentjournalEntryAmount,
				'Cash')
			INSERT INTO [VendorPaymentJournalEntry]
				(JournalEntryID,
				AccountID,
				TransactionID,
				ReportOn1099,
				ObjectID,
				ObjectType,
				ObjectName)
			VALUES
				(@cashJournalEntryID,
				@accountID,
				@newTransactionID,
				@reportOn1099,
				@objectID,
				@objectType,
				@objectName)

			-- Distribution Accrual Entry
			DECLARE @accrualJournalEntryID uniqueidentifier = NEWID()

			INSERT INTO [JournalEntry]
				(JournalEntryId,
				AccountID,
				GLAccountID,
				TransactionID,
				Amount,
				AccountingBasis)
			VALUES
				(@accrualJournalEntryID,
				@accountID,
				@vendorPaymentjournalEntryGLAccountID,
				@newTransactionID,
				@vendorPaymentjournalEntryAmount,
				'Accrual')
			INSERT INTO [VendorPaymentJournalEntry]
				(JournalEntryID,
				AccountID,
				TransactionID,
				ReportOn1099,
				ObjectID,
				ObjectType,
				ObjectName)
			VALUES
				(@accrualJournalEntryID,
				@accountID,
				@newTransactionID,
				@reportOn1099,
				@objectID,
				@objectType,
				@objectName)

			SET @distributionJournalEntryIDs = @distributionJournalEntryIDs + CONVERT(nvarchar(100), @accrualJournalEntryID) + ','
			SET @lineItemCtr = @lineItemCtr + 1
		END		
		TRUNCATE TABLE #RecurringLineItems

		-- Store the distribution JournalEntryIDs in the Transaction.Note to be used
		-- when displaying the distribution line items. This is a hack but we now are 
		-- allowing negative VALUES in the distribution and we have no other
		-- way to determine which one is the main bank entry vs the distribution
		UPDATE [Transaction] SET Note = @distributionJournalEntryIDs WHERE TransactionID = @newTransactionID

		-- get the check number
		-- if the posted data for this payment has a DoNotUpdateNextcheckNumber, we put in the check number as either what they gave us, or string.empty
		-- otherwise we get the next check number for that bank account, use it, and then increment that check number
		
		IF (@paymentMethod = 'Check' and @doNotUpdateNextcheckNumber = 0)
		BEGIN
			SET @referenceNumber = @checkNumber
			UPDATE BankAccount SET NextCheckNumber = @checkNumber + 1
				WHERE BankAccountID = @bankAccountID
		END
		--ELSE
		--BEGIN
		--	SET @referenceNumber = ''
		--END
		
		-- create the payment record
		SET @newPaymentID = NEWID()
		INSERT INTO Payment 
				(PaymentID,
				AccountID,
				Amount,
				PaidOut,
				ReceivedFromPaidTo,
				[Date],
				ReferenceNumber,
				[Type],
				[Description],
				Notes,
				ObjectID,
				ObjectType,
				Reversed,
				[TimeStamp])
		 VALUES 
				(@newPaymentID,
				@accountID,
				@totalAmount,
				1,
				@payTo,
				@date,
				@referenceNumber,
				@paymentMethod,
				@memo,
				@notes,
				@vendorID,
				'Vendor',
				0,
				GETUTCDATE())

		-- create the transactionpayment record
		INSERT INTO PaymentTransaction
		 (AccountID,
		  PaymentID,
		  TransactionID)
		 VALUES
		 (@accountID,
		 @newPaymentID,
		 @newTransactionID)
		
		-- create the banktransaction
		INSERT INTO BankTransaction
		(BankTransactionID,
		 AccountID,
		 ObjectID,
		 ObjectType,
		 ReferenceNumber,
		 BankTransactionCategoryID,
		 QueuedForPrinting)
		VALUES
		(NEWID(),
		@accountID,
		@newPaymentID,
		'Payment',
		@referenceNumber,
		(SELECT btc.BankTransactionCategoryID 
			FROM BankTransactionCategory btc 
			WHERE btc.AccountID = @accountID and btc.Category = 'Check' ),
		0)
				 
		-- Add a task for the user to update the needed values
		
		--SET @newInvoiceID = NEWID()	
		SET @newAlertTaskID = NEWID()
		
		INSERT INTO AlertTask (AlertTaskID, AccountID, AssignedByPersonID, ObjectID, ObjectType, [Type], Importance, DateAssigned, DateDue, DateMarkedRead, NotifiedViaEmail, [Subject], TaskStatus)
			VALUES (@newAlertTaskID, @accountID, @personID, @newPaymentID, 'Vendor Payment', null, 'High', @date, @date, null, 0, 'Posted Recurring Vendor Payment: ' + @recurringItemName, 'Not Started')
		
		INSERT INTO TaskAssignment (TaskAssignmentID, AccountID, AlertTaskID, PersonID, DateMarkedRead, IsCarbonCopy)
			VALUES (NEWID(), @accountID, @newAlertTaskID, @assignedToPersonID, NULL, 0)

		IF (@postingPersonID is null)
		BEGIN
			UPDATE dbo.RecurringItem 
				SET LastRecurringPostDate = @date
				WHERE RecurringItemID = @recurringItemID
		END
		ELSE
		BEGIN
			UPDATE dbo.RecurringItem
				SET LastManualPostDate = @date, LastManualPostPersonID = @postingPersonID
				WHERE RecurringItemID = @recurringItemID
		END		

		SET @ctr = @ctr + 1
	END
END
GO
