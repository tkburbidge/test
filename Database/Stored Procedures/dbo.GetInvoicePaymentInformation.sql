SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 17, 2013
-- Description:	Gets payment information for a given invoice
-- =============================================
CREATE PROCEDURE [dbo].[GetInvoicePaymentInformation] 
	-- Add the parameters for the stored procedure here
	@invoiceID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	SELECT DISTINCT 
			pay.PaymentID AS 'ObjectID', 
			'Payment' AS 'ObjectType',			
			pay.Amount AS 'Amount', 
			pay.ReferenceNumber AS 'ReferenceNumber',
			t.PropertyID AS 'PropertyID',
			prop.Abbreviation AS 'PropertyAbbreviation',
			pay.[Date] AS 'Date',
			pay.[Type] as PaymentType,
			ba.AccountName + ' - ' + ba.AccountNumberDisplay AS 'BankAccount'
		FROM Invoice i
			INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
			INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID			
			CROSS APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, null) AS [InvStat]
			INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
			INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID
			LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
			INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID
			INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
			INNER JOIN Property prop ON prop.PropertyID = ta.PropertyID
			INNER JOIN BankAccount ba ON ta.ObjectID = ba.BankAccountID
		WHERE InvStat.InvoiceStatus IN ('Paid', 'Partially Paid', 'Partially Paid-R')
		  AND ((@invoiceID IS NULL) OR (i.InvoiceID = @invoiceID))
		  AND tar.TransactionID IS NULL
		  
	UNION

	SELECT DISTINCT 
			ic.InvoiceID AS 'ObjectID', 
			'Credit' AS 'ObjectType',			
			ta.Amount AS 'Amount', 
			ic.Number AS 'ReferenceNumber',
			ta.PropertyID AS 'PropertyID',
			prop.Abbreviation AS 'PropertyAbbreviation',
			ta.TransactionDate AS 'Date', 
			tta.Name as PaymentType,
			ba.AccountName + ' - ' + ba.AccountNumberDisplay AS 'BankAccount'
		FROM Invoice i
			INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
			INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
			CROSS APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, null) AS [InvStat]
			INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
			INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID
			LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
			INNER JOIN Invoice ic ON ta.ObjectID = ic.InvoiceID
			INNER JOIN Property prop ON prop.PropertyID = ta.PropertyID
			INNER JOIN BankAccount ba ON ta.ObjectID = ba.BankAccountID
		WHERE InvStat.InvoiceStatus IN ('Paid', 'Partially Paid', 'Partially Paid-R')
		  AND ((@invoiceID IS NULL) OR (i.InvoiceID = @invoiceID))
		  AND tta.Name IN ('Credit')
		  AND tar.TransactionID IS NULL



END


GO
