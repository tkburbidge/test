SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Updated By: Trevor Burbidge
-- =============================================
CREATE PROCEDURE [dbo].[TSK_PostRecurringInvoices]
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@itemType nvarchar(50) = null,
	@date date,
	@postData InvoiceTemplatePostData READONLY,
	@postingPersonID uniqueIdentifier = null,
	@postAsApproved bit = null
AS

DECLARE @ctr int = 1
DECLARE @maxCtr int
DECLARE @lineItemCtr int
DECLARE @maxLineItemCtr int
DECLARE @newTransactionID uniqueidentifier
DECLARE @newInvoiceID uniqueidentifier
DECLARE @recurringItemID uniqueidentifier
DECLARE @invoiceTemplateID uniqueidentifier
DECLARE @invoiceLineItemTemplateID uniqueidentifier
DECLARE @creditInvoiceTransactionTypeID uniqueidentifier
DECLARE @chargeInvoiceTransactionTypeID uniqueidentifier
DECLARE @creditGLAccountID uniqueidentifier
DECLARE @chargeGLAccountID uniqueidentifier
DECLARE @transactionTypeID uniqueidentifier
DECLARE @GLAccountID uniqueidentifier
DECLARE @personID uniqueidentifier
DECLARE @creditInvoice bit
DECLARE @recurringItemName nvarchar(600)
DECLARE @assignedToPersonID uniqueidentifier
DECLARE @alternateDescription nvarchar(2000)
DECLARE @invoiceNumber nvarchar(100)
declare @addedDate datetime
DECLARE @newAlertTaskID uniqueidentifier

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
		AssignedToPersonID uniqueidentifier not null,
		[Description] nvarchar(2000) null,
		InvoiceNumber nvarchar(100) null)
		
	CREATE TABLE #RecurringLineItems (
		Sequence	int identity not null,
		InvoiceLineItemTemplateID uniqueidentifier not null)
		
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
		
		insert into #RecurringItems ( RecurringItemID, AccountID, PersonID, Name, AssignedToPersonID)  
		select RecurringItemID, AccountID, PersonID, Name, AssignedToPersonID from #RecurringItems2
		
	END
	ELSE
	BEGIN
		INSERT INTO #RecurringItems 
			SELECT r.RecurringItemID, r.AccountID, r.PersonID, r.Name, r.AssignedToPersonID, pd.[Description] , pd.InvoiceNumber
				FROM RecurringItem r join @postData pd on r.RecurringItemID = pd.RecurringItemID
				WHERE r.RecurringItemID IN (SELECT RecurringItemID FROM @postData)
	END
	
	SET @maxCtr = (SELECT MAX(Sequence) FROM #RecurringItems)		
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		-- Get the RecurringItem info
		SELECT @recurringItemID = RecurringItemID, @accountID = AccountID, @personID = PersonID, @recurringItemName = Name,
		 @assignedToPersonID = AssignedToPersonID, @invoiceNumber = InvoiceNumber, @alternateDescription = [Description]
			FROM #RecurringItems 
			WHERE Sequence = @ctr

		-- Get the needed TransactionTypeIDs
		SELECT @chargeGLAccountID = GLAccountID, @chargeInvoiceTransactionTypeID = TransactionTypeID
			FROM TransactionType
			WHERE Name = 'Charge' AND [Group] = 'Invoice' AND AccountID = @accountID
		SELECT @creditGLAccountID = GLAccountID, @creditInvoiceTransactionTypeID = TransactionTypeID
			FROM TransactionType
			WHERE Name = 'Credit' AND [Group] = 'Invoice' AND AccountID = @accountID
		
		SET @newInvoiceID = NEWID()			
		
		-- Add the invoice
		INSERT Invoice (InvoiceID, AccountID, VendorID, Number, InvoiceDate, DueDate, ReceivedDate, AccountingDate, Notes, Total, [Description], PaymentStatus, SummaryVendorID, Credit, PostingBatchID, ExpenseTypeID, CreatedByPersonID)
			SELECT @newInvoiceID, AccountID, VendorID, coalesce(@invoiceNumber, '') , @date, @date, @date, @date, Notes, Total, coalesce(@alternateDescription, [Description]), null, null, Credit, null, ExpenseTypeID, Coalesce(@postingPersonID, @personID)
				FROM InvoiceTemplate
				WHERE RecurringItemID = @recurringItemID
				
		-- Add the POInvoiceNote
		set @addedDate = GETDATE()
		INSERT POInvoiceNote (POInvoiceNoteID, AccountID, ObjectID, PersonID, AltObjectID, AltObjectType, [Date], [Status], Notes, [Timestamp])
			SELECT NEWID(), AccountID, @newInvoiceID, Coalesce(@postingPersonID, @personID), NULL, NULL, @date, 'Pending Approval', 'Posted as a Recurring Invoice', GETDATE()
				FROM InvoiceTemplate
				WHERE RecurringItemID = @recurringItemID
		-- if we ant it approved at this time, also add a POInvoiceNote for a status
		if (@postAsApproved = 1)
		begin
			INSERT POInvoiceNote (POInvoiceNoteID, AccountID, ObjectID, PersonID, AltObjectID, AltObjectType, [Date], [Status], Notes, [Timestamp])
			SELECT NEWID(), AccountID, @newInvoiceID, Coalesce(@postingPersonID, @personID), NULL, NULL, @date, 'Approved', 'Posted as a Recurring Invoice with status approved', DATEADD(second, 30, @addedDate)
				FROM InvoiceTemplate
				WHERE RecurringItemID = @recurringItemID
		end
				
		SELECT @invoiceTemplateID = InvoiceTemplateID, @creditInvoice = Credit
			FROM InvoiceTemplate
			WHERE RecurringItemID = @recurringItemID
			
		-- Cache the invoice line items
		INSERT #RecurringLineItems 
			SELECT InvoiceLineItemTemplateID
				FROM InvoiceLineItemTemplate
				WHERE InvoiceTemplateID = @invoiceTemplateID
				
		SET @maxLineItemCtr = (SELECT MAX(Sequence) FROM #RecurringLineItems)
		SET @lineItemCtr = 1
		
		-- Get the correct TransactionTypeID and GLAccountID
		IF (@creditInvoice = 1)
		BEGIN
			SET @transactionTypeID = @creditInvoiceTransactionTypeID
			SET @GLAccountID = @creditGLAccountID
		END
		ELSE
		BEGIN
			SET @transactionTypeID = @chargeInvoiceTransactionTypeID
			SET @GLAccountID = @chargeGLAccountID		
		END
		
		-- Add the invoice line items
		WHILE (@lineItemCtr <= @maxLineItemCtr)
		BEGIN
			SELECT @invoiceLineItemTemplateID = InvoiceLineItemTemplateID
				FROM #RecurringLineItems 
				WHERE Sequence = @lineItemCtr
				
			-- Add a Transaction for each InvoiceLineItem
			SET @newTransactionID = NEWID()
			INSERT [Transaction] (TransactionID, AccountID, ObjectID, TransactionTypeID, LedgerItemTypeID, AppliesToTransactionID, ReversesTransactionID, PropertyID,
								  PersonID, TaxRateGroupID, NotVisible, Origin, Amount, [Description], Note, TransactionDate, [TimeStamp], IsDeleted, PostingBatchID)
				SELECT @newTransactionID, AccountID, @newInvoiceID, @transactionTypeID, null, null, null, PropertyID, Coalesce(@postingPersonID, @personID), TaxRateGroupID, 0, 'R', Total, 
						[Description], null, @date, GETDATE(), 0, null
					FROM InvoiceLineItemTemplate
					WHERE InvoiceLineItemTemplateID = @invoiceLineItemTemplateID
					
			-- Add the JournalEntry records tied to the transaction
			INSERT JournalEntry (JournalEntryID, AccountID, GLAccountID, TransactionID, Amount, AccountingBasis)
				SELECT NEWID(), AccountID, GLAccountID, @newTransactionID, Total, 'Accrual'
					FROM InvoiceLineItemTemplate 
					WHERE InvoiceLineItemTemplateID = @invoiceLineItemTemplateID
				UNION
				SELECT NEWID(), AccountID, @GLAccountID, @newTransactionID, -1.0*(Total), 'Accrual'
					FROM InvoiceLineItemTemplate
					WHERE InvoiceLineItemTemplateID = @invoiceLineItemTemplateID
					
			-- Add the Invoice Line Items
			INSERT InvoiceLineItem (InvoiceLineItemID, AccountID, TransactionID, ObjectType, ObjectID, InvoiceID, GLAccountID, OrderBy, Quantity, UnitPrice, PaymentStatus, Taxable, TaxRateGroupID, SalesTaxAmount, Report1099, PropertyID, IsReplacementReserve)
				SELECT NEWID(), ilit.AccountID, @newTransactionID, ilit.ObjectType, ilit.ObjectID, @newInvoiceID, ilit.GLAccountID, ilit.OrderBy, ilit.Quantity, ilit.UnitPrice, null, ilit.Taxable, ilit.TaxRateGroupID, ilit.SalesTaxAmount, v.Gets1099, ilit.PropertyID, ilit.IsReplacementReserve
					FROM InvoiceLineItemTemplate ilit
						INNER JOIN InvoiceTemplate it ON ilit.InvoiceTemplateID = it.InvoiceTemplateID
						INNER JOIN Vendor v ON v.VendorID = it.VendorID
					WHERE InvoiceLineItemTemplateID = @invoiceLineItemTemplateID
				
			SET @lineItemCtr = @lineItemCtr + 1
		END
		
		-- Add a task for the user to update the needed values
		SET @newAlertTaskID = NEWID()
		INSERT INTO AlertTask (AlertTaskID, AccountID, AssignedByPersonID, ObjectID, ObjectType, [Type], Importance, DateAssigned, DateDue, DateMarkedRead, NotifiedViaEmail, [Subject], TaskStatus)
			VALUES (@newAlertTaskID, @accountID, @personID, @newInvoiceID, 'Invoice', null, 'High', @date, @date, null, 0, 'Update Recurring Invoice: ' + @recurringItemName, 'Not Started')
		
		INSERT INTO TaskAssignment (TaskAssignmentID, AccountID, AlertTaskID, PersonID, DateMarkedRead, IsCarbonCopy)
			VALUES (NEWID(), @accountID, @newAlertTaskID, @assignedToPersonID, NULL, 0)

		TRUNCATE TABLE #RecurringLineItems
		SET @ctr = @ctr + 1
		
		IF (@postingPersonID is null)
		BEGIN
			update dbo.RecurringItem SET LastRecurringPostDate = @date
			where RecurringItemID = @recurringItemID
		END
		ELSE
		BEGIN
			update dbo.RecurringItem
			SET LastManualPostDate = @date, LastManualPostPersonID = @postingPersonID
			where RecurringItemID = @recurringItemID
		END		
	END
END


GO
