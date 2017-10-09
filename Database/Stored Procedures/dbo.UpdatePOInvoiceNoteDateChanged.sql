SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 4, 2014
-- Description:	Updates the POInvoiceNote when we change a payment date
-- =============================================
CREATE PROCEDURE [dbo].[UpdatePOInvoiceNoteDateChanged] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null, 
	@paymentID uniqueidentifier = null
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #InvoicesPaid (
		InvoiceID uniqueidentifier not null,
		MaxPaymentDate date null)

	INSERT #InvoicesPaid 
		SELECT DISTINCT t.ObjectID, null
			FROM Payment p
				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] ta ON pt.TransactionID = ta.TransactionID
				INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID			
			WHERE p.PaymentID = @paymentID
				AND p.AccountID = @accountID
				
	UPDATE #InvoicesPaid SET MaxPaymentDate = (SELECT MAX(p.[Date])
													FROM Payment p
														INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
														INNER JOIN [Transaction] ta ON pt.TransactionID = ta.TransactionID
														INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
													WHERE t.ObjectID = #InvoicesPaid.InvoiceID
														AND p.Amount > 0
														AND p.Reversed = 0)
														
	UPDATE poin SET [Date] = #ip.MaxPaymentDate
		FROM POInvoiceNote poin
			INNER JOIN #InvoicesPaid #ip ON poin.ObjectID = #ip.InvoiceID
		WHERE poin.POInvoiceNoteID = (SELECT TOP 1 POInvoiceNoteID 
										  FROM POInvoiceNote
										  WHERE ObjectID = #ip.InvoiceID
										    AND [Status] = 'Paid'
										  ORDER BY [Timestamp] DESC)
END
GO
