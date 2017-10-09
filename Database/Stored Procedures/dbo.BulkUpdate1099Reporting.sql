SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Sam Bryan, Rick
-- Create date: 06/29/2015
-- Description:	bult Updates 1099 Reporting for Invoices, Purchases
-- =============================================
CREATE PROCEDURE [dbo].[BulkUpdate1099Reporting]
	-- Add the parameters for the stored procedure here
	@accountID BIGINT
AS
BEGIN
	UPDATE ili
	SET report1099 = v.gets1099
	FROM invoice i
	INNER JOIN invoicelineitem ili ON ili.invoiceid = i.invoiceid
	INNER JOIN vendor v ON i.vendorid = v.vendorid
	WHERE i.accountid = @accountID


	UPDATE vpje
	SET reporton1099 = v.gets1099
	FROM vendorpaymentjournalentry vpje
	INNER JOIN [transaction] t ON t.transactionid = vpje.transactionid
	INNER JOIN paymenttransaction pt ON pt.transactionid = t.transactionid
	INNER JOIN payment p ON p.paymentid = pt.paymentid
	INNER JOIN vendor v ON v.vendorid =p.objectid
	WHERE vpje.accountid = @accountID

	UPDATE dt 
	SET Report1099 = v.Gets1099
	FROM InvoiceLineItemTemplate dt				
		INNER JOIN InvoiceTemplate it ON dt.InvoiceTemplateID = it.InvoiceTemplateID
		INNER JOIN Vendor v ON it.VendorID = v.VendorID
	WHERE dt.AccountID = @accountID


	UPDATE dt 
	SET ReportOn1099 = v.Gets1099
	FROM VendorPaymentJournalEntryTemplate dt	
		INNER JOIN VendorPaymentTemplate it ON dt.VendorPaymentTemplateID = it.VendorPaymentTemplateID
		INNER JOIN Vendor v ON it.VendorID = v.VendorID
	WHERE dt.AccountID = @accountID
END
GO
