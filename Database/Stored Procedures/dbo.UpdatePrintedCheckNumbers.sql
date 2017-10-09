SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: July 11, 2012
-- Description:	Updates the printed check numbers where
--				it needs to be updated
-- =============================================
CREATE PROCEDURE [dbo].[UpdatePrintedCheckNumbers]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@checkNumberPlaceholder nvarchar(50),
	@printedCheckNumber PrintedCheckNumber READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Update Payment.ReferenceNumber
    UPDATE p
		SET p.ReferenceNumber = n.CheckNumber
		FROM Payment p
		INNER JOIN @printedCheckNumber n ON p.PaymentID = n.PaymentID
		WHERE p.AccountID = @accountID
		
	-- Update BankTransaction.ReferenceNumber
	UPDATE bt
		SET bt.ReferenceNumber = n.CheckNumber
		FROM BankTransaction bt
		INNER JOIN @printedCheckNumber n ON bt.ObjectID = n.PaymentID
		WHERE bt.AccountID = @accountID		
	
	-- Update the POInvoiceNote that indicates which check paid off the invoice	
	UPDATE note
		SET note.Notes = REPLACE(note.Notes, '>' + @checkNumberPlaceholder + '<', '>' + n.CheckNumber + '<')
		FROM POInvoiceNote note
		INNER JOIN @printedCheckNumber n ON note.AltObjectID = n.PaymentID
		WHERE note.AccountID = @accountID
    
END
GO
