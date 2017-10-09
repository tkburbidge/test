SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE PROCEDURE [dbo].[GetNotCompletedPurchaseOrders] 
	@accountID bigint,
	@propertyID uniqueidentifier,
	@accountingPeriodID uniqueidentifier 
AS
BEGIN
	SELECT distinct po.Number, v.CompanyName as Vendor, po.Total, po.PurchaseOrderID
	FROM PurchaseOrder po
		--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
		INNER JOIN Vendor v ON v.VendorID = po.VendorID
		INNER JOIN PurchaseOrderLineItem poli on po.PurchaseOrderID = poli.PurchaseOrderID
		INNER JOIN PropertyAccountingPeriod pap ON poli.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, null) AS POStatus
	WHERE po.AccountID = @accountID
	AND poli.PropertyID = @propertyID
	AND po.[Date] >= pap.StartDate
	AND po.[Date] <= pap.EndDate
	AND POStatus.InvoiceStatus NOT IN ('Completed', 'Void', 'Denied')

END



GO
