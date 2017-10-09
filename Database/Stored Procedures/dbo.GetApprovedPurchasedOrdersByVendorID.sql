SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 26, 2012
-- Description:	Gets all Approved Purchase Orders for a given Vendor and Property
-- =============================================
CREATE PROCEDURE [dbo].[GetApprovedPurchasedOrdersByVendorID] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@vendorID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT DISTINCT	po.PurchaseOrderID,
				po.[Date] as 'Date',
				po.Number,
				po.[Description],
				po.Total,
				p.Abbreviation,
				p.PropertyID					
	FROM PurchaseOrder po
		INNER JOIN PurchaseOrderLineItem poli on po.PurchaseOrderID = poli.PurchaseOrderID
		INNER JOIN Property p on poli.PropertyID = p.PropertyID
		CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, NULL) AS [Status]
	WHERE po.AccountID = @accountID
		AND po.VendorID = @vendorID
		AND [Status].InvoiceStatus IN ('Approved', 'Approved-R')
		-- The user has access to all properties associated with the PO
		AND (SELECT COUNT(*) 
				FROM ((SELECT DISTINCT PropertyID FROM PurchaseOrderLineItem poli2
					   WHERE po.PurchaseOrderID = poli2.PurchaseOrderID)				
					  EXCEPT
					  (SELECT Value FROM @propertyIDs)) t) = 0


END





GO
