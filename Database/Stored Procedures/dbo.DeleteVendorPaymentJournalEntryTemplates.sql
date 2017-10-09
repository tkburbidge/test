SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Art Olsen
-- Create date: 1/28/2013
-- Description:	Delete all VendorPaymentJournalEntryTemplates related to a VendorPayemntTemplate
-- =============================================
CREATE PROCEDURE [dbo].[DeleteVendorPaymentJournalEntryTemplates] 
	@accountID bigint, 
	@vendorPaymentTemplateID uniqueidentifier
AS
BEGIN
	DELETE FROM VendorPaymentJournalEntryTemplate
	WHERE AccountID = @accountID 
		AND VendorPaymentTemplateID = @vendorPaymentTemplateID
END


GO
