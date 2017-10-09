SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Olsen
-- Create date: 3/15/2012
-- Description:	Gets the needed information to print an invoice
-- =============================================
CREATE PROCEDURE [dbo].[GetPrintablePurchaseOrders]	
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@purchaseOrderIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT 
	   p.Name AS 'PropertyName',
	   p.Abbreviation AS 'PropertyAbbreviation',
	   po.PurchaseOrderID,
	   po.Number,	   	   
	   ap.Name AS 'AccountingPeriod',
	   po.[Date],	   	   
	   po.Notes,
	   po.Total,
	   po.Discount,
	   po.Shipping,
	   po.[Description],	   
	   sn.[Status],	  	    
	  (cp.PreferredName + ' ' + cp.LastName) AS 'User',
	   v.CompanyName AS 'VendorName',
	   vpa.StreetAddress AS 'VendorAddress',
	   vpa.City AS 'VendorCity',
	   vpa.[State] AS 'VendorState',
	   vpa.Zip AS 'VendorZip',
	   vpa.Country AS 'VendorCountry',
	   vper.Phone1 AS 'VendorPhone',	   
	   poli.PurchaseOrderLineItemID,
	   CASE
			WHEN poli.ObjectID IS NULL THEN NULL
			WHEN poli.ObjectType = 'Unit' THEN u.Number
			WHEN poli.ObjectType = 'Rentable Item' THEN li.Description
			WHEN poli.ObjectType = 'Building' THEN bld.Name
			WHEN poli.ObjectType = 'WOIT Account' THEN woit.Name
	  END AS 'Location',	  	  
	  gl.Number AS 'GLNumber',
	  gl.Name AS 'GLName',
	  poli.[Description] AS 'LineItemDescription',
	  poli.UnitPrice,
	  poli.Quantity,
	  trg.Name AS 'TaxRateGroupName',
	  poli.SalesTaxAmount,
	  poli.GLTotal AS 'LineItemTotal',	  
	  poli.OrderBy	  
	FROM PurchaseOrderLineItem poli
	INNER JOIN [GLAccount] gl ON gl.GLAccountID = poli.GLAccountID		
	INNER JOIN [PurchaseOrder] po ON po.PurchaseOrderID = poli.PurchaseOrderID
	--INNER JOIN [Invoice] i ON i.InvoiceID = ili.InvoiceID
	--INNER JOIN [AccountingPeriod] ap ON po.[Date] >= ap.StartDate AND po.[Date] <= ap.EndDate AND ap.AccountID = @accountID
	INNER JOIN PropertyAccountingPeriod pap ON poli.PropertyID = pap.PropertyID AND po.[Date] <= pap.EndDate AND po.[Date] >= pap.StartDate
	INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	INNER JOIN [POInvoiceNote] sn ON sn.ObjectID = po.PurchaseOrderID	-- Current status note
	INNER JOIN [POInvoiceNote] cn ON cn.ObjectID = po.PurchaseOrderID	-- Created note
	INNER JOIN [Person] cp ON cp.PersonID = cn.PersonID
	INNER JOIN [Vendor] v ON v.VendorID = po.VendorID
	INNER JOIN [Property] p ON p.PropertyID = poli.PropertyID
	LEFT JOIN [TaxRateGroup] trg ON trg.TaxRateGroupID = poli.TaxRateGroupID
	LEFT JOIN [VendorPerson] vp ON vp.VendorID = v.VendorID
	LEFT JOIN [Person] vper ON vper.PersonID = vp.PersonID
	LEFT JOIN [PersonType] vpt ON vpt.PersonID = vper.PersonID AND vpt.[Type] = 'VendorGeneral'
	LEFT JOIN [Address] vpa ON vpa.ObjectID = vper.PersonID
	
	LEFT JOIN [Unit] u on u.UnitID = poli.ObjectID
	LEFT JOIN [Building] bld on bld.BuildingID = poli.ObjectID
	LEFT JOIN [LedgerItem] li ON li.LedgerItemID = poli.ObjectID
	LEFT JOIN [WOITAccount] woit ON woit.WOITAccountID = poli.ObjectID
	WHERE po.PurchaseOrderID IN (SELECT Value FROM @purchaseOrderIDs) 
		  -- Get the last invoice note
		  AND sn.POInvoiceNoteID = (SELECT TOP 1 POInvoiceNoteID 
									FROM POInvoiceNote
									WHERE POInvoiceNote.ObjectID = po.PurchaseOrderID
									ORDER BY POInvoiceNote.Timestamp DESC)
		  -- Get the first invoice note
		  AND cn.POInvoiceNoteID = (SELECT TOP 1 POInvoiceNoteID 
									FROM POInvoiceNote
									WHERE POInvoiceNote.ObjectID = po.PurchaseOrderID
									ORDER BY POInvoiceNote.Timestamp ASC)			
		 -- Ensure only the vendor general person is returned
		 AND vper.PersonID = vpt.PersonID
		 AND po.AccountID = @accountID
	ORDER BY 'VendorName', po.[Date]
	END


GO
