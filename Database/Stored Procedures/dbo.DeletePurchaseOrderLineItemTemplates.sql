SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Art Olsen
-- Create date: 11/14/2013
-- Description:	Delete all PurchaseOrderLineItemTemplates related to a PurchaseOrder Template
-- =============================================
CREATE PROCEDURE [dbo].[DeletePurchaseOrderLineItemTemplates] 
	@accountID bigint, 
	@purchaseOrderTemplateID uniqueidentifier
AS
BEGIN
	delete from PurchaseOrderLineItemTemplate
	where AccountID = @accountID and
	PurchaseOrderTemplateID = @purchaseOrderTemplateID
END
GO
