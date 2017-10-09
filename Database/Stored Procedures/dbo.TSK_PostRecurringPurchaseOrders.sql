SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Updated By: Trevor Burbidge
--
--
-- Updated By: Joshua Grigg
--       Date: July 23, 2015
--Description: Added ExpenseTypeID(s) to PurchaseOrder(s)
-- =============================================
CREATE PROCEDURE [dbo].[TSK_PostRecurringPurchaseOrders]
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@itemType nvarchar(50) = null,
	@date date,
	@recurringItemIDs GuidCollection READONLY,
	@postingPersonID uniqueIdentifier = null
AS

DECLARE @ctr int = 1
DECLARE @maxCtr int
DECLARE @lineItemCtr int
DECLARE @maxLineItemCtr int
DECLARE @newTransactionID uniqueidentifier
DECLARE @newPurchaseOrderID uniqueidentifier
DECLARE @recurringItemID uniqueidentifier
DECLARE @purchaseOrderTemplateID uniqueidentifier
DECLARE @purchaseOrderLineItemTemplateID uniqueidentifier
DECLARE @personID uniqueidentifier
DECLARE @recurringItemName nvarchar(600)
DECLARE @assignedToPersonID uniqueidentifier
DECLARE @nextPONumber int = null
declare @currentPropertyID uniqueidentifier = null
declare @poNumber nvarchar(50) = '';
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
		AssignedToPersonID uniqueidentifier not null)
		
	CREATE TABLE #RecurringLineItems (
		Sequence	int identity not null,
		PurchaseOrderLineItemTemplateID uniqueidentifier not null)
		
	-- If we aren't posting a particular set of RecurringItems then get all
	-- RecurringItems for the given date.  Otherwise, just post get 
	-- the recurring items of the IDs passed in
	IF (0 = (SELECT COUNT(*) FROM @recurringItemIDs))
	BEGIN
		INSERT INTO #RecurringItems EXEC GetRecurringItemsByType @accountID, @itemType, @date
	END
	ELSE
	BEGIN
		INSERT INTO #RecurringItems 
			SELECT RecurringItemID, AccountID, PersonID, Name, AssignedToPersonID
				FROM RecurringItem
				WHERE RecurringItemID IN (SELECT Value FROM @recurringItemIDs)
	END
	
	SET @maxCtr = (SELECT MAX(Sequence) FROM #RecurringItems)		
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		-- Get the RecurringItem info
		SELECT @recurringItemID = RecurringItemID, @accountID = AccountID, @personID = PersonID, @recurringItemName = Name, @assignedToPersonID = AssignedToPersonID
			FROM #RecurringItems 
			WHERE Sequence = @ctr
		
		set @nextPONumber = null
		-- see if the po should be auto numbered
		SELECT  @nextPONumber =  s.NextPurchaseOrderNumber , @currentPropertyID = p.PropertyID
			from Property p
			INNER JOIN PurchaseOrderLineItemTemplate POLIT ON p.PropertyID = polit.PropertyID
			 inner join PurchaseOrderTemplate pt on POLIT.PurchaseOrderTemplateID = pt.PurchaseOrderTemplateID
			join settings s on p.AccountID = s.AccountID
			where pt.RecurringItemID = @recurringItemID
			 and pt.AutoGeneratePurchaseOrderNumber = 1
		
		if (@nextPONumber is not null)
			begin
				set @poNumber = @nextPONumber
				update settings set NextPurchaseOrderNumber = @nextPONumber + 1
				where Settings.AccountID = @accountID
			end
		else
			begin
				set @poNumber = ''
			end
		SET @newPurchaseOrderID = NEWID()			
		
		-- Add the purchaseOrder
		INSERT PurchaseOrder (PurchaseOrderID, AccountID, Number, VendorID, CreatedByPersonID, Total, Shipping, Discount, Notes, [Description], [Date], ExpenseTypeID, CurrentWorkflowGroupID)
			SELECT @newPurchaseOrderID, AccountID, @poNumber, pot.VendorID, coalesce(@postingPersonID, @assignedToPersonID), pot.Total,
			 pot.Shipping, pot.Discount, pot.Notes, pot.[Description], @date, pot.ExpenseTypeID, '00000000-0000-0000-0000-000000000000'
				FROM PurchaseOrderTemplate pot
				WHERE RecurringItemID = @recurringItemID
				
		-- Add the POInvoiceNote
		INSERT POInvoiceNote (POInvoiceNoteID, AccountID, ObjectID, PersonID, AltObjectID, AltObjectType, [Date], [Status], Notes, [Timestamp])
			SELECT NEWID(), AccountID, @newPurchaseOrderID, Coalesce(@postingPersonID, @personID), NULL, NULL, @date, 'Pending Approval', 'Posted as a Recurring PurchaseOrder', GETDATE()
				FROM PurchaseOrderTemplate
				WHERE RecurringItemID = @recurringItemID
				
		SELECT @purchaseOrderTemplateID = PurchaseOrderTemplateID
			FROM PurchaseOrderTemplate
			WHERE RecurringItemID = @recurringItemID
			
		-- Add the ApprovalNotificationProcess record so it will get picked up by processor and create approval records
		INSERT ApprovalNotificationProcess (ApprovalNotificationProcessID, AccountID, ObjectID, ObjectType, Processed, [Type])
			SELECT NEWID(), AccountID, @newPurchaseOrderID, 'PurchaseOrder', 0, 'PendingFromRecurring'
				FROM PurchaseOrderTemplate pot
				WHERE RecurringItemID = @recurringItemID

		-- Cache the purchaseOrder line items
		INSERT #RecurringLineItems 
			SELECT PurchaseOrderLineItemTemplateID
				FROM PurchaseOrderLineItemTemplate
				WHERE PurchaseOrderTemplateID = @purchaseOrderTemplateID
				
		SET @maxLineItemCtr = (SELECT MAX(Sequence) FROM #RecurringLineItems)
		SET @lineItemCtr = 1
		
		-- Add the purchaseOrder line items
		WHILE (@lineItemCtr <= @maxLineItemCtr)
		BEGIN
			SELECT @purchaseOrderLineItemTemplateID = PurchaseOrderLineItemTemplateID
				FROM #RecurringLineItems 
				WHERE Sequence = @lineItemCtr				
				
			-- Add the PurchaseOrder Line Items
			INSERT PurchaseOrderLineItem (PurchaseOrderLineItemID, AccountID, PurchaseOrderID, GLAccountID, ObjectID, ObjectType, OrderBy, [Description], Quantity, 
				UnitPrice, Total, GLTotal, TaxRateGroupID, SalesTaxAmount, PropertyID, IsReplacementReserve)
				SELECT NEWID(), polit.AccountID, @newPurchaseOrderID, polit.GLAccountID, polit.ObjectID, polit.ObjectType, polit.OrderBy, polit.[Description], polit.Quantity,
				polit.UnitPrice, polit.Total, polit.GLTotal, polit.TaxRateGroupID, polit.SalesTaxAmount, polit.PropertyID, polit.IsReplacementReserve
					FROM PurchaseOrderLineItemTemplate polit
					WHERE PurchaseOrderLineItemTemplateID = @purchaseOrderLineItemTemplateID
				
			SET @lineItemCtr = @lineItemCtr + 1
		END
		
		-- Add a task for the user to update the needed values
		SET @newAlertTaskID = NEWID()
		INSERT INTO AlertTask (AlertTaskID, AccountID, AssignedByPersonID, ObjectID, ObjectType, [Type], Importance, DateAssigned, DateDue, DateMarkedRead, NotifiedViaEmail, [Subject], TaskStatus)
			VALUES (@newAlertTaskID, @accountID, Coalesce(@postingPersonID, @personID), @newPurchaseOrderID, 'PurchaseOrder', null, 'High', @date, @date, null, 0, 'Update Recurring PurchaseOrder: ' + @recurringItemName, 'Not Started')
		
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
		
		Set @nextPONumber = null		
	END
END

GO
