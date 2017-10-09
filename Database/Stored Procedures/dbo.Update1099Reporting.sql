SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Craig Perkins
-- Create date: 01/21/2014
-- Description:	Updates 1099 Reporting for Invoices AND Purchases
-- =============================================
CREATE PROCEDURE [dbo].[Update1099Reporting]
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@vendorID uniqueidentifier,
	@paramGets1099 bit
AS
BEGIN
	UPDATE ili
		SET Report1099 = @paramGets1099
		FROM Invoice i
			INNER JOIN InvoiceLineItem ili ON ili.InvoiceID = i.InvoiceID
			INNER JOIN Vendor v ON i.VendorID = v.VendorID
		WHERE i.AccountID = @accountID
			AND v.Gets1099 = @paramGets1099
			AND ili.Report1099 = 1-@paramGets1099
			AND v.VendorID = @vendorID

	UPDATE vpje
		SET ReportOn1099 = @paramGets1099
		FROM VendorPaymentJournalEntry vpje
			Inner JOIN [Transaction] t ON t.TransactionID = vpje.TransactionID
			INNER JOIN PaymentTransaction pt ON pt.TransactionID = t.TransactionID
			INNER JOIN Payment p ON p.PaymentID = pt.PaymentID
			INNER JOIN Vendor v ON v.VendorID = p.ObjectID
		WHERE vpje.AccountID = @accountID
			AND v.Gets1099 = @paramGets1099
			AND vpje.ReportOn1099 = 1-@paramGets1099
			AND v.VendorID = @vendorID
END
GO
