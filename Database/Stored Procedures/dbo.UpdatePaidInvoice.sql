SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: May 23, 2012
-- Description:	Updates a Paid or Partial-Paid Invoice, and more importantly, the line items on selected columns.
-- =============================================
CREATE PROCEDURE [dbo].[UpdatePaidInvoice] 
	-- Add the parameters for the stored procedure here
	@invoiceID uniqueidentifier = null, 
	@number nvarchar(20) = null,
	@invoiceDate date = null,
	@receivedDate date = null,
	@dueDate date = null,
	@accountingDate date = null,
	@holdDate date = null,
	@description nvarchar(500) = null,
	@notes nvarchar(1000) = null,
	@total money = null,
	@lineItems PaidInvoiceUpdateCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	UPDATE Invoice
		SET Number = @number, InvoiceDate = @invoiceDate, ReceivedDate = @receivedDate, DueDate = @dueDate, AccountingDate = @accountingDate,
			HoldDate = @holdDate, [Description] = @description, Notes = @notes, Total = @total
		WHERE InvoiceID = @invoiceID
		
	UPDATE ili
		SET GLAccountID = li.GLAccountID, ObjectID = li.ObjectID, ObjectType = li.ObjectType, OrderBy = li.OrderBy, Report1099 = li.Report1099, IsReplacementReserve =  li.IsReplacementReserve
		FROM InvoiceLineItem ili
			CROSS APPLY @lineItems AS li
		WHERE ili.InvoiceLineItemID = li.InvoiceLineItemID
		
	UPDATE t
		SET [Description] = li.[Description], TransactionDate = @accountingDate
		FROM [Transaction] t
			INNER JOIN InvoiceLineItem ili ON t.TransactionID = ili.TransactionID
			CROSS APPLY @lineItems AS li
		WHERE ili.InvoiceLineItemID = li.InvoiceLineItemID

		
	UPDATE je
		SET GLAccountID = ili.GLAccountID
		FROM JournalEntry je
			INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
			INNER JOIN InvoiceLineItem ili ON t.TransactionID = ili.TransactionID
			INNER JOIN Invoice i ON i.InvoiceID = ili.InvoiceID
			CROSS APPLY @lineItems AS li
		WHERE ili.InvoiceLineItemID = li.InvoiceLineItemID
		  AND je.AccountingBasis = 'Accrual'
		  -- If it is a bill, and the line item is positive, we want to update the debit entry
		  -- If it is a bill, and the line item is negative, we want to update the credit entry
		  -- If it is a credit, we want to update the credit entry
		  AND ((i.Credit = 0 AND ((t.Amount > 0 AND je.Amount > 0) OR (t.Amount < 0 AND je.Amount < 0))) OR (i.Credit = 1 AND je.Amount < 0))


	

	UPDATE je
		SET GLAccountID = ili.GLAccountID		
		FROM JournalEntry je
			INNER JOIN [Transaction] ta ON je.TransactionID = ta.TransactionID
			INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
			LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = ta.TransactionID
			INNER JOIN InvoiceLineItem ili ON t.TransactionID = ili.TransactionID
			INNER JOIN Invoice i ON i.InvoiceID = ili.InvoiceID
			CROSS APPLY @lineItems AS li
		WHERE ili.InvoiceLineItemID = li.InvoiceLineItemID
		-- If it is a bill, and the line item is positive, we want to update the debit entry
		-- If it is a bill, and the line item is negative, we want to update the credit
		-- If it is a credit, we want to update the credit entry
		  AND ((i.Credit = 0 AND ((t.Amount > 0 AND je.Amount > 0) OR (t.Amount < 0 AND je.Amount < 0))) OR (i.Credit = 1 AND je.Amount < 0))
		  AND je.AccountingBasis = 'Cash'
		  AND tr.TransactionID IS NULL
 		  --AND je.GLAccountID <> ili.GLAccountID

	UPDATE ta
		SET ta.[Description] = li.[Description]
		FROM [Transaction] ta
			INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
			LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = ta.TransactionID
			INNER JOIN InvoiceLineItem ili ON t.TransactionID = ili.TransactionID
			CROSS APPLY @lineItems AS li
		WHERE ili.InvoiceLineItemID = li.InvoiceLineItemID		  	  
			AND tr.TransactionID IS NULL

	-- If we are updating the accounting date, we need to make sure the first POInvoiceNote date
	-- is at least on or before the new accounting date
	DECLARE @firstNoteID uniqueidentifier
	DECLARE @firstNoteDate date
	SELECT TOP 1 @firstNoteID = poin.POInvoiceNoteID, @firstNoteDate = [Date]
	FROM POInvoiceNote poin
	WHERE poin.ObjectID = @invoiceID
	ORDER BY Timestamp, [Date]

	IF (@accountingDate < @firstNoteDate)
	BEGIN
		UPDATE POInvoiceNote SET [Date] = @accountingDate WHERE POInvoiceNoteID = @firstNoteID
	END
	
END
GO
