SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: May 28, 2012
-- Description:	Get the object names for line items on an invoice
-- =============================================
CREATE PROCEDURE [dbo].[GetInvoiceLineItemObjectNames]	
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@invoiceID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT 
	   ili.InvoiceLineItemID AS 'LineItemID',
	   CASE
			WHEN ili.ObjectID IS NULL THEN NULL
			WHEN ili.ObjectType = 'Unit' THEN u.Number
			WHEN ili.ObjectType = 'Rentable Item' THEN li.Description
			WHEN ili.ObjectType = 'Building' THEN bld.Name
			WHEN ili.ObjectType = 'WOIT Account' THEN woit.Name
	  END AS 'ObjectName'
	FROM InvoiceLineItem ili
	LEFT JOIN [Unit] u on u.UnitID = ili.ObjectID
	LEFT JOIN [Building] bld on bld.BuildingID = ili.ObjectID
	LEFT JOIN [LedgerItem] li ON li.LedgerItemID = ili.ObjectID
	LEFT JOIN [WOITAccount] woit ON woit.WOITAccountID = ili.ObjectID
	WHERE ili.AccountID = @accountID
		AND ili.InvoiceID = @invoiceID
	END
GO
