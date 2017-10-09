SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Art Olsen
-- Create date: 3/25/2013
-- Description: Associate an invoice to a work order by purchaseorder(s)

-- UPDATE
-- Author:		Joshua Grigg
-- Date:		7/29/2015
-- Description:	fixes to work with renaming WorkOrderInvoice table to InvoiceAssociation and new ObjectType column
-- =============================================
CREATE PROCEDURE [dbo].[AssociateInvoiceToObject]
	@accountID BIGINT,
	@invoiceID UNIQUEIDENTIFIER,
	@purchaseOrderIDs GuidCollection READONLY
AS
INSERT INTO InvoiceAssociation
	SELECT DISTINCT AccountID, ObjectID, @InvoiceID, ObjectType
	FROM PurchaseOrderAssociation AS poa
	WHERE poa.AccountID = @accountID
	  AND poa.PurchaseOrderID IN (SELECT Value FROM @purchaseOrderIDs)
GO
