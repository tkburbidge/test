SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Joshua Grigg
-- Create date: May 4, 2015
-- Description:	Gets all incomplete purchase orders for a collection of properties, as of a given date.
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PO_GetOpenPurchaseOrders] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@statusDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier not null
	)

	CREATE TABLE #PurchaseOrders (
		PurchaseOrderID uniqueidentifier not null,
		Number nvarchar(50) not null,
		VendorID uniqueidentifier not null,
		VendorName nvarchar(200) not null,
		[Date] date null,
		[Description] nvarchar(500) null,
		[Status] nvarchar(50) not null,
		Shipping money not null,
		Discount money not null,
		Total money not null)
	
	CREATE TABLE #PurchaseOrderLineItems (
		PurchaseOrderID uniqueidentifier not null,
		PropertyAbbreviation nvarchar(50) not null,
		GLAccountNumber nvarchar(50) not null,
		GLAccountID uniqueidentifier not null,
		[Description] nvarchar(500) null,
		Total money not null,
		OrderBy int not null)
	
	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs
		
	INSERT #PurchaseOrders
		SELECT	DISTINCT
				po.PurchaseOrderID,
				po.Number,
				po.VendorID,
				v.CompanyName AS 'VendorName',
				po.[Date] AS 'Date',
				po.[Description] AS 'Description',
				pos.InvoiceStatus AS 'Status',
				po.Shipping,
				po.Discount,
				po.Total
		FROM PurchaseOrder po
			INNER JOIN Vendor v on po.VendorID = v.VendorID
			INNER JOIN POInvoiceNote poin on po.PurchaseOrderID = poin.ObjectID
			INNER JOIN PurchaseOrderLineItem poli on po.PurchaseOrderID = poli.PurchaseOrderID
			INNER JOIN #PropertyIDs #p ON #p.PropertyID = poli.PropertyID
			CROSS APPLY GetInvoiceStatusByInvoiceID(po.PurchaseOrderID, @statusDate) pos
		WHERE pos.InvoiceStatus NOT IN ('Void', 'Completed', 'Denied')		  
			AND po.[Date] <= @statusDate
	
	INSERT #PurchaseOrderLineItems
		SELECT	DISTINCT
				#po.PurchaseOrderID,
				p.Abbreviation AS 'PropertyAbbreviation',
				gla.Number AS 'GLAccountNumber',
				gla.GLAccountID AS 'GLAccountID',
				poli.[Description] AS 'Description',
				poli.Total,
				poli.OrderBy
		FROM #PurchaseOrders #po
			INNER JOIN PurchaseOrderLineItem poli ON #po.PurchaseOrderID = poli.PurchaseOrderID
			INNER JOIN Property p ON poli.PropertyID = p.PropertyID
			INNER JOIN GLAccount gla ON poli.GLAccountID = gla.GLAccountID
	
	SELECT * FROM #PurchaseOrders
	SELECT * FROM #PurchaseOrderLineItems
END
GO
