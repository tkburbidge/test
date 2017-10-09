SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO






CREATE PROCEDURE [dbo].[GetPrintableInvoices]	
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@invoiceIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT 
	   p.Name AS 'PropertyName',
	   p.Abbreviation AS 'PropertyAbbreviation',
	   i.InvoiceID,
	   i.Number,	   
	   b.Number AS 'Batch',
	   ap.Name AS 'AccountingPeriod',
	   i.InvoiceDate,
	   i.DueDate,
	   i.ReceivedDate,
	   i.AccountingDate,
	   i.Notes,
	   i.Total,
	   i.Description,
	   i.Credit,
	   sn.[Status],	  	    
	  (cp.PreferredName + ' ' + cp.LastName) AS 'User',
	   CASE	
			WHEN v.Summary = 1 THEN sv.Name
			ELSE v.CompanyName
	   END AS 'VendorName',
	   CASE	
			WHEN v.Summary = 1 THEN sva.StreetAddress
			ELSE vpa.StreetAddress
	   END AS 'VendorAddress',
	   CASE	
			WHEN v.Summary = 1 THEN sva.City
			ELSE vpa.City
	   END AS 'VendorCity',
	   CASE	
			WHEN v.Summary = 1 THEN sva.State
			ELSE vpa.State
	   END AS 'VendorState',
	   CASE	
			WHEN v.Summary = 1 THEN sva.Zip
			ELSE vpa.Zip
	   END AS 'VendorZip',
	   CASE	
			WHEN v.Summary = 1 THEN sva.Country
			ELSE vpa.Country
	   END AS 'VendorCountry',
	   CASE	
			WHEN v.Summary = 1 THEN sv.PhoneNumber
			ELSE vper.Phone1
	   END AS 'VendorPhone',
	   ili.InvoiceLineItemID,
	   v.CustomerNumber AS 'VendorCustomerNumber',
	   CASE
			WHEN ili.ObjectID IS NULL THEN NULL
			WHEN ili.ObjectType = 'Unit' THEN u.Number
			WHEN ili.ObjectType = 'Rentable Item' THEN li.Description
			WHEN ili.ObjectType = 'Building' THEN bld.Name
			WHEN ili.ObjectType = 'WOIT Account' THEN woit.Name
	  END AS 'Location',
	  je.Amount AS 'JournalEntryAmount',
	  gl.Number AS 'GLNumber',
	  gl.Name AS 'GLName',
	  t.[Description] AS 'LineItemDescription',
	  ili.UnitPrice,
	  ili.Quantity,
	  t.Amount AS 'LineItemTotal',
	  ili.Taxable,
	  ili.OrderBy,
	  ISNULL((SELECT SUM(ta.Amount) 
	  FROM [Transaction] t2
	  INNER JOIN [Transaction] ta ON ta.AppliesToTransactionID = t2.TransactionID
	  LEFT JOIN [Transaction] tra ON tra.ReversesTransactionID = ta.TransactionID
	  WHERE t2.ObjectID = i.InvoiceID
	  	    AND tra.TransactionID IS NULL), 0) AS 'AmountPaid',
	(SELECT MAX (ta.TransactionDate)
	  FROM [Transaction] t2
	  INNER JOIN [Transaction] ta ON ta.AppliesToTransactionID = t2.TransactionID
	  LEFT JOIN [Transaction] tra ON tra.ReversesTransactionID = ta.TransactionID
	  WHERE t2.ObjectID = i.InvoiceID	  
	  	    AND tra.TransactionID IS NULL) AS 'LastPayment'
	FROM [JournalEntry] je
	INNER JOIN [GLAccount] gl ON gl.GLAccountID = je.GLAccountID
	INNER JOIN [Transaction] t ON t.TransactionID = je.TransactionID
	INNER JOIN [InvoiceLineItem] ili ON ili.TransactionID = t.TransactionID
	INNER JOIN [Invoice] i ON i.InvoiceID = ili.InvoiceID
	INNER JOIN [Property] p ON p.PropertyID = t.PropertyID
	INNER JOIN PropertyAccountingPeriod pap ON i.AccountingDate >= pap.StartDate AND i.AccountingDate <= pap.EndDate AND p.PropertyID = pap.PropertyID
	INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	INNER JOIN [POInvoiceNote] sn ON sn.ObjectID = i.InvoiceID	-- Current status note
	INNER JOIN [POInvoiceNote] cn ON cn.ObjectID = i.InvoiceID	-- Created note
	INNER JOIN [Person] cp ON cp.PersonID = cn.PersonID
	INNER JOIN [Vendor] v ON v.VendorID = i.VendorID

	LEFT JOIN [SummaryVendor] sv ON sv.SummaryVendorID = i.SummaryVendorID
	LEFT JOIN [Address] sva ON sva.AddressID = sv.AddressID
	LEFT JOIN [VendorPerson] vp ON vp.VendorID = v.VendorID
	LEFT JOIN [Person] vper ON vper.PersonID = vp.PersonID
	LEFT JOIN [PersonType] vpt ON vpt.PersonID = vper.PersonID AND vpt.[Type] = 'VendorPayment'
	LEFT JOIN [Address] vpa ON vpa.ObjectID = vper.PersonID
	--LEFT JOIN [InvoiceBatch] ib ON i.InvoiceID = ib.BatchID
	--LEFT JOIN [Batch] b on ib.BatchID = b.BatchID
	LEFT JOIN 
			(SELECT [Batch].[Number], [InvoiceBatch].[InvoiceID], [PropertyAccountingPeriod].[PropertyID]
				FROM [InvoiceBatch]
					INNER JOIN [Batch] ON [InvoiceBatch].[BatchID] = [Batch].[BatchID] 
					INNER JOIN [PropertyAccountingPeriod] ON [Batch].[PropertyAccountingPeriodID] = [PropertyAccountingPeriod].[PropertyAccountingPeriodID]) AS [b]
			ON i.InvoiceID = b.InvoiceID AND p.PropertyID = b.PropertyID
	LEFT JOIN [Unit] u on u.UnitID = ili.ObjectID
	LEFT JOIN [Building] bld on bld.BuildingID = ili.ObjectID
	LEFT JOIN [LedgerItem] li ON li.LedgerItemID = ili.ObjectID
	LEFT JOIN [WOITAccount] woit ON woit.WOITAccountID = ili.ObjectID
	WHERE i.InvoiceID IN (SELECT Value FROM @invoiceIDs) 
		  -- Get the last invoice note
		  AND sn.POInvoiceNoteID = (SELECT TOP 1 POInvoiceNoteID 
									FROM POInvoiceNote
									WHERE POInvoiceNote.ObjectID = i.InvoiceID
									ORDER BY POInvoiceNote.Timestamp DESC)
		  -- Get the first invoice note
		  AND cn.POInvoiceNoteID = (SELECT TOP 1 POInvoiceNoteID 
									FROM POInvoiceNote
									WHERE POInvoiceNote.ObjectID = i.InvoiceID
									ORDER BY POInvoiceNote.Timestamp ASC)			
		 -- Ensure only the vendor general person is returned
		 AND vper.PersonID = vpt.PersonID
		 AND i.AccountID = @accountID
	ORDER BY 'VendorName', i.AccountingDate
	END








GO
