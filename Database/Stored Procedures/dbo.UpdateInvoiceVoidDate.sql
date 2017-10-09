SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 29, 2014
-- Description:	Updates the voided date of an invoice
-- =============================================
CREATE PROCEDURE [dbo].[UpdateInvoiceVoidDate] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@invoiceID uniqueidentifier = null,
	@voidDate date = null,
	@notes nvarchar(500)
AS

DECLARE @poInvoiceNoteID uniqueidentifier

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	UPDATE t SET TransactionDate = @voidDate
		FROM [Transaction] t
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Charge', 'Credit') AND tt.[Group] = 'Invoice'
		WHERE ObjectID = @invoiceID
		  AND ReversesTransactionID IS NOT NULL
	
	SET @poInvoiceNoteID = (SELECT TOP 1 POInvoiceNoteID 
								FROM POInvoiceNote
								WHERE ObjectID = @invoiceID
								  AND [Status]  = 'Void'
								ORDER BY Timestamp DESC)
		  
	UPDATE POInvoiceNote SET [Date] = @voidDate, Notes = Notes + @notes
		WHERE POInvoiceNoteID = @poInvoiceNoteID
END
GO
