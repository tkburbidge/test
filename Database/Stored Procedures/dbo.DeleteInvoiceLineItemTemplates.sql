SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Art Olsen
-- Create date: 2/6/2013
-- Description:	Delete all InvoiceLineItemTemplates related to an InvoiceTemplate
-- =============================================
CREATE PROCEDURE [dbo].[DeleteInvoiceLineItemTemplates] 
	@accountID bigint, 
	@invoiceTemplateID uniqueidentifier
AS
BEGIN
	delete from InvoiceLineItemTemplate
	where AccountID = @accountID and
	InvoiceTemplateID = @invoiceTemplateID
END
GO
