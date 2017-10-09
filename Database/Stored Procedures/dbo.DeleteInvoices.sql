SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Joshua Grigg
-- Create date: 12/11/2014
-- Description:	Deletes a set of invoices based on a list of InvoiceIDs
-- =============================================
CREATE PROCEDURE [dbo].[DeleteInvoices] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@invoiceIDs GuidCollection readonly
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DELETE 
		FROM POInvoiceNote 
		WHERE POInvoiceNote.ObjectID IN (SELECT value FROM @invoiceIDs)

	DELETE JournalEntry
		FROM InvoiceLineItem ili
		  JOIN [Transaction] t
			ON ili.TransactionID = t.TransactionID JOIN JournalEntry je
			ON t.TransactionID = je.TransactionID
		WHERE ili.InvoiceID IN (SELECT value FROM @invoiceIDs)

	DELETE [Transaction]
		FROM InvoiceLineItem ili
		  JOIN [Transaction] t
			ON ili.TransactionID = t.TransactionID
		WHERE ili.InvoiceID IN (SELECT value FROM @invoiceIDs)
	
	DELETE 
		FROM InvoiceLineItem 
		WHERE InvoiceLineItem.InvoiceID IN (SELECT value FROM @invoiceIDs)
	
	DELETE 
		FROM Invoice 
		WHERE Invoice.InvoiceID IN (SELECT value FROM @invoiceIDs)

	DELETE
		FROM InvoiceAssociation
		WHERE InvoiceAssociation.InvoiceID IN (SELECT value FROM @invoiceIDs)
END
GO
