SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Apr 29, 2014
-- Description:	Changes the date that a check was voided
-- =============================================
CREATE PROCEDURE [dbo].[UpdateBankPaymentVoidDate] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@paymentID uniqueidentifier = null,
	@voidDate date = null,
	@notes nvarchar(500)
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	-- Get the old void date from the invoice
	DECLARE @oldVoidDate date = (SELECT ReversedDate FROM Payment WHERE PaymentID = @paymentID)

	CREATE TABLE #InvoicesAndTheirNotes (
		InvoiceID uniqueidentifier NOT NULL,
		POInvoiceNoteID uniqueidentifier NULL)
	
	-- Change the reversal date on the original payment
	UPDATE Payment SET ReversedDate = @voidDate, 
					VoidNotes = @notes
		WHERE PaymentID = @paymentID
	
	-- Update the Transactions tied to the payment so they show the new void date
	UPDATE t SET TransactionDate = @voidDate
			     
		FROM [Transaction] t
			INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID AND pt.PaymentID = @paymentID
		WHERE t.ReversesTransactionID IS NOT NULL
		
	-- Update the credits that were reversed to the new void date
	UPDATE t SET TransactionDate = @voidDate
		FROM [Transaction] t
			INNER JOIN PaymentInvoiceCreditTransaction pict ON t.TransactionID = pict.TransactionID AND pict.PaymentID = @paymentID
		WHERE t.ReversesTransactionID IS NOT NULL

	-- Get the last Approved-R and Partially Paid-R notes that were put on the old void date
	-- for all invoices paid by this payment and change their date to the new void date
	INSERT #InvoicesAndTheirNotes SELECT DISTINCT t.ObjectID, (SELECT TOP 1 POInvoiceNoteID
																  FROM POInvoiceNote
																  WHERE ObjectID = t.ObjectID
																    AND [Status] IN ('Approved-R', 'Partially Paid-R')
																	AND [Date] = @oldVoidDate
																  ORDER BY Timestamp DESC)
						  FROM [Transaction] t 
						      INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
							  INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID AND pt.PaymentID = @paymentID		
		
	-- Update the Invoice notes with the new void date
	UPDATE POInvoiceNote SET [Date] = @voidDate, Notes = @notes
		WHERE POInvoiceNoteID IN (SELECT POInvoiceNoteID FROM #InvoicesAndTheirNotes)

END
GO
