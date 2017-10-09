SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[RPT_CST_SELDIN_SECO_InvoicePayment]
	-- Add the parameters for the stored procedure here
	@bankAccountID uniqueidentifier = null,
	@startReference nvarchar(50) = null,
	@endReference nvarchar(50) = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #CheckLedgerInfo (
		PaymentID uniqueidentifier NOT NULL,
		TransactionID uniqueidentifier NULL,
		BankTransactionID uniqueidentifier NULL,
		PropertyID uniqueidentifier NULL,
		[Date] date NULL,
		InvoiceNumber nvarchar(100) NULL,
		Location nvarchar(100) NULL,
		CheckNumber nvarchar(200) NULL,
		VendorName nvarchar(500) NULL,
		VendorAbbr nvarchar(400) NULL,
		Amount money NULL,
		[Memo] nvarchar(500) NULL,
		Address1 nvarchar(500) NULL,
		Address2 nvarchar(500) NULL,
		City nvarchar(500) NULL,
		[State] nvarchar(500) NULL,
		[Zip] nvarchar(10) NULL,
		PonytailSorter int NULL)
		
	CREATE TABLE #CheckLedgerDetailItem (
		PaymentID uniqueidentifier NOT NULL,
		[Date] date NULL,
        TransactionTypeName nvarchar(50) NULL,		--TransactionTypeName - Check, Refund, Payment
		PropertyID uniqueidentifier NULL,
		Reference nvarchar(200) NULL,
        [DateTime] Date NULL,
		[Description] nvarchar(200) NULL,
        Amount money NULL)

	-- Build temp table that contains Transaction level details for each check 
	-- Takes into account @propertyIDs to only get the portions of the checks for the selected properties
	-- At the end, select out a sum either grouped by PaymentID if there are no @propertyIDs or grouped by PaymentID and PropertyID if there are
	
	-- Applications
	-- If TT.Group = Invoice and TT.Name = Payment
	--  Join in Transaction.AppliesToTransacitonID back to Invoice
	--  to get Invoice #	Invoice Date	Invoice Desc	Paid Amount (Sum of the payments for that invoice)
	-- If TT.Group = Bank and TT.Name = Check OR tt.Group = Bank AND tt.Name = Refund
	--	Return a single record with the Payment.Description as the InvoiceDescription
	--	Payment.Refercne as Invoicenumber, Payment.Date as Invoice Date, Payment.Amount as PaidAmount
	

	
	CREATE TABLE #Properties (
		PropertyID uniqueidentifier NOT NULL)
		
	INSERT #Properties
		SELECT PropertyID
			FROM BankAccountProperty
			WHERE BankAccountID = @bankAccountID

	INSERT #CheckLedgerInfo
		SELECT	DISTINCT 
				p.PaymentID AS 'PaymentID', 
				t.TransactionID,
				bt.BankTransactionID,
				t.PropertyID,
				CAST(p.[Date] AS Date) AS 'Date',
				i.Number AS 'InvoiceNumber',
				prop.Abbreviation + ' - ' + prop.Name AS 'Location', 
				p.ReferenceNumber AS 'CheckNumber',
				v.CompanyName AS 'VendorName',
				v.Abbreviation AS 'VendorAbbr',
				(CASE WHEN i.Credit = 1 THEN -t.Amount ELSE t.Amount END) AS 'Amount',
				t.[Description] AS 'Memo',
				addr.StreetAddress AS 'Address1',
				null AS 'Address2',
				addr.City AS 'City',
				addr.[State] AS 'State',
				addr.[Zip] AS 'Zip',
				CAST(RIGHT('00000000000000000000'+ISNULL(LEFT(SUBSTRING(p.ReferenceNumber, PATINDEX('%[0-9.]%', p.ReferenceNumber), 8000),
						PATINDEX('%[^0-9.]%', SUBSTRING(p.ReferenceNumber, PATINDEX('%[0-9.]%', p.ReferenceNumber), 8000) + 'X') -1), ''), 20) as int) AS 'PonytailSorter'
			FROM BankTransaction bt
				INNER JOIN Payment p ON p.PaymentID = bt.ObjectID 
				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN [Property] prop ON t.PropertyID = prop.PropertyID
				--INNER JOIN #Properties #p ON prop.PropertyID = #p.PropertyID
				INNER JOIN [Transaction] at ON at.TransactionID = t.AppliesToTransactionID
				INNER JOIN Invoice i ON at.ObjectID = i.InvoiceID
				INNER JOIN Vendor v ON i.VendorID = v.VendorID
				INNER JOIN VendorPerson vp ON v.VendorID = vp.VendorID
				INNER JOIN Person per ON vp.PersonID = per.PersonID
				INNER JOIN [Address] addr ON per.PersonID = addr.ObjectID
			WHERE t.ObjectID = @bankAccountID
				AND (RIGHT('00000000000000000000'+ISNULL(LEFT(SUBSTRING(p.ReferenceNumber, PATINDEX('%[0-9.]%', p.ReferenceNumber), 8000),
						PATINDEX('%[^0-9.]%', SUBSTRING(p.ReferenceNumber, PATINDEX('%[0-9.]%', p.ReferenceNumber), 8000) + 'X') -1), ''), 20) >=
					RIGHT('00000000000000000000'+ISNULL(LEFT(SUBSTRING(@startReference, PATINDEX('%[0-9.]%', @startReference), 8000),
						PATINDEX('%[^0-9.]%', SUBSTRING(@startReference, PATINDEX('%[0-9.]%', @startReference), 8000) + 'X') -1), ''), 20) OR @startReference IS NULL)
				AND (RIGHT('00000000000000000000'+ISNULL(LEFT(SUBSTRING(p.ReferenceNumber, PATINDEX('%[0-9.]%', p.ReferenceNumber), 8000),
						PATINDEX('%[^0-9.]%', SUBSTRING(p.ReferenceNumber, PATINDEX('%[0-9.]%', p.ReferenceNumber), 8000) + 'X') -1), ''), 20) <=
					RIGHT('00000000000000000000'+ISNULL(LEFT(SUBSTRING(@endReference, PATINDEX('%[0-9.]%', @endReference), 8000),
						PATINDEX('%[^0-9.]%', SUBSTRING(@endReference, PATINDEX('%[0-9.]%', @endReference), 8000) + 'X') -1), ''), 20) OR @endReference IS NULL)
				AND p.[Type] = 'Check'
				AND t.ReversesTransactionID IS NULL
				AND t.IsDeleted = 0
				AND (((tt.[Group] = 'Bank') AND (tt.Name = 'Check' OR tt.Name = 'Refund')) OR ((tt.[Group] = 'Invoice') AND (tt.Name = 'Payment')))
				AND addr.AddressType = 'VendorPayment'

		
	CREATE TABLE #MyIntercompanyPayments (
		PaymentID uniqueidentifier NOT NULL)
			
	INSERT #MyIntercompanyPayments
		SELECT	DISTINCT 
				p.PaymentID 
			FROM BankTransaction bt
				INNER JOIN Payment p ON p.PaymentID = bt.ObjectID 
				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN [Property] prop ON t.PropertyID = prop.PropertyID
				--INNER JOIN #Properties #p ON prop.PropertyID = #p.PropertyID
			WHERE p.[Type] = 'Check'
				AND t.ObjectID = @bankAccountID
				AND t.ReversesTransactionID IS NULL
				AND t.IsDeleted = 0
				 AND (((tt.[Group] = 'Invoice') AND (tt.Name = 'Intercompany Payment')) 
					   OR ((tt.[Group] = 'Bank') AND (tt.Name = 'Intercompany Refund')))
				AND (RIGHT('00000000000000000000'+ISNULL(LEFT(SUBSTRING(p.ReferenceNumber, PATINDEX('%[0-9.]%', p.ReferenceNumber), 8000),
						PATINDEX('%[^0-9.]%', SUBSTRING(p.ReferenceNumber, PATINDEX('%[0-9.]%', p.ReferenceNumber), 8000) + 'X') -1), ''), 20) >=
					RIGHT('00000000000000000000'+ISNULL(LEFT(SUBSTRING(@startReference, PATINDEX('%[0-9.]%', @startReference), 8000),
						PATINDEX('%[^0-9.]%', SUBSTRING(@startReference, PATINDEX('%[0-9.]%', @startReference), 8000) + 'X') -1), ''), 20) OR @startReference IS NULL)
				AND (RIGHT('00000000000000000000'+ISNULL(LEFT(SUBSTRING(p.ReferenceNumber, PATINDEX('%[0-9.]%', p.ReferenceNumber), 8000),
						PATINDEX('%[^0-9.]%', SUBSTRING(p.ReferenceNumber, PATINDEX('%[0-9.]%', p.ReferenceNumber), 8000) + 'X') -1), ''), 20) <=
					RIGHT('00000000000000000000'+ISNULL(LEFT(SUBSTRING(@endReference, PATINDEX('%[0-9.]%', @endReference), 8000),
						PATINDEX('%[^0-9.]%', SUBSTRING(@endReference, PATINDEX('%[0-9.]%', @endReference), 8000) + 'X') -1), ''), 20) OR @endReference IS NULL)	
						  
	INSERT #CheckLedgerInfo
		SELECT	DISTINCT 
				p.PaymentID AS 'PaymentID', 
				t.TransactionID,
				bt.BankTransactionID,
				t.PropertyID,
				CAST(p.[Date] AS Date) AS 'Date',
				i.Number AS 'InvoiceNumber',
				prop.Abbreviation + ' - ' + prop.Name AS 'Location', 
				p.ReferenceNumber AS 'CheckNumber',
				v.CompanyName AS 'VendorName',
				v.Abbreviation AS 'VendorAbbr',
				(CASE WHEN i.Credit = 1 THEN -t.Amount ELSE t.Amount END) AS 'Amount',
				t.[Description] AS 'Memo',
				addr.StreetAddress AS 'Address1',
				null AS 'Address2',
				addr.City AS 'City',
				addr.[State] AS 'State',
				addr.[Zip] AS 'Zip',
				CAST(RIGHT('00000000000000000000'+ISNULL(LEFT(SUBSTRING(p.ReferenceNumber, PATINDEX('%[0-9.]%', p.ReferenceNumber), 8000),
						PATINDEX('%[^0-9.]%', SUBSTRING(p.ReferenceNumber, PATINDEX('%[0-9.]%', p.ReferenceNumber), 8000) + 'X') -1), ''), 20) as int) AS 'PonytailSorter'
			FROM BankTransaction bt
				INNER JOIN Payment p ON p.PaymentID = bt.ObjectID 
				INNER JOIN PaymentTransaction pt ON p.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN [Property] prop ON t.PropertyID = prop.PropertyID
				--INNER JOIN #Properties #p ON prop.PropertyID = #p.PropertyID
				INNER JOIN [Transaction] at ON at.TransactionID = t.AppliesToTransactionID
				INNER JOIN Invoice i ON at.ObjectID = i.InvoiceID
				INNER JOIN Vendor v ON i.VendorID = v.VendorID
				INNER JOIN VendorPerson vp ON v.VendorID = vp.VendorID
				INNER JOIN Person per ON vp.PersonID = per.PersonID
				INNER JOIN [Address] addr ON per.PersonID = addr.ObjectID	
			WHERE p.PaymentID IN (SELECT PaymentID FROM #MyIntercompanyPayments)
			   AND (((tt.[Group] = 'Invoice') AND (tt.Name = 'Payment'))
			        OR ((tt.[Group] = 'Bank') AND (tt.Name = 'Refund')))
			  AND t.TransactionID NOT IN (SELECT TransactionID FROM #CheckLedgerInfo)	
			  AND addr.AddressType = 'VendorPayment'
	
		SELECT * 
			FROM #CheckLedgerInfo
			ORDER BY PonytailSorter

END
GO
