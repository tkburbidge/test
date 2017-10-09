SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Josh Grigg
-- Create date: Nov 29, 2016
-- Description:	Gets all invoices and invoice line items in a date range for vendors that receive 1099s 
-- =============================================
CREATE PROCEDURE [dbo].[RPT_VNDR_GetForm1099ReportingDetailsByDate] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Invoices (
		InvoiceID uniqueidentifier not null,
		InvoiceNumber nvarchar(50) not null,
		VendorID uniqueidentifier not null,
		Vendor nvarchar(200) not null,
		InvoiceDate date null,
		AccountingDate date null,
		DueDate date null,
		[Description] nvarchar(500) null,
		Total money null)
		
	CREATE TABLE #InvoiceLineItems (
		InvoiceID uniqueidentifier not null,
		InvoiceLineItemID uniqueidentifier not null,		
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		PropertyAbbreviation nvarchar(50) not null,
		GLAccountNumber nvarchar(50) not null,
		GLAccountName nvarchar(200) not null,
		GLAccountID uniqueidentifier not null,
		[Description] nvarchar(500) null,
		Total money null,
		AccountingDate date null,
		InvoiceNumber nvarchar(50) null,
		Report1099 bit not null)
		
	
	CREATE TABLE #PropertyAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate [Date] NOT NULL,
		EndDate [Date] NOT NULL,
		InvoiceStatusDate [Date] NULL)

	IF (@accountingPeriodID IS NOT NULL)
	BEGIN		
		INSERT #PropertyAndDates
			SELECT pids.Value, pap.StartDate, pap.EndDate, pap.EndDate
				FROM @propertyIDs pids
					INNER JOIN PropertyAccountingPeriod pap ON pids.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	END
	ELSE
	BEGIN
		INSERT #PropertyAndDates
			SELECT pids.Value, @startDate, @endDate, @endDate
				FROM @propertyIDs pids
	END

	INSERT #InvoiceLineItems 
		SELECT	
				i.InvoiceID,
				ili.InvoiceLineItemID,
				p.PropertyID,
				p.Name AS 'PropertyName',
				p.Abbreviation AS 'PropertyAbbreviation',
				gla.Number AS 'GLAccountNumber',
				gla.Name AS 'GLAccountName',
				gla.GLAccountID,
				t.[Description] AS 'Description',
				ta.Amount AS 'Total',
				i.AccountingDate,
				i.Number AS 'InvoiceNumber',
				ili.Report1099
		FROM Invoice i 
			INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
			INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
			INNER JOIN Property p ON t.PropertyID = p.PropertyID
			INNER JOIN GLAccount gla ON ili.GLAccountID = gla.GLAccountID
			INNER JOIN #PropertyAndDates #p ON #p.PropertyID = t.PropertyID
			INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
			INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID
			INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
								AND pay.[Date] >= #p.StartDate AND pay.[Date] <= #p.EndDate
			INNER JOIN Vendor v ON v.VendorID = i.VendorID		
			CROSS APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, #p.InvoiceStatusDate) AS INVSTAT
			LEFT JOIN [Transaction] tr ON ta.TransactionID = tr.ReversesTransactionID AND tr.TransactionDate <= #p.EndDate
		WHERE INVSTAT.InvoiceStatus <> 'Void'
		  AND v.Gets1099 = 1
		  AND ili.Report1099 = 1
		  AND tr.TransactionID IS NULL

	INSERT #InvoiceLineItems 
		SELECT	
				i.InvoiceID,
				ili.InvoiceLineItemID,
				p.PropertyID,
				p.Name AS 'PropertyName',
				p.Abbreviation AS 'PropertyAbbreviation',
				gla.Number AS 'GLAccountNumber',
				gla.Name AS 'GLAccountName',
				gla.GLAccountID,
				t.[Description] AS 'Description',
				ta.Amount AS 'Total',
				i.AccountingDate,
				i.Number AS 'InvoiceNumber',
				ili.Report1099
		FROM Invoice i 
			INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
			INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
			INNER JOIN Property p ON t.PropertyID = p.PropertyID
			INNER JOIN GLAccount gla ON ili.GLAccountID = gla.GLAccountID
			INNER JOIN #PropertyAndDates #p ON #p.PropertyID = t.PropertyID
			INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
			INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.[Group] IN ('Bank') AND tta.Name IN ('Check', 'Vendor Credit')
			INNER JOIN JournalEntry je ON ta.TransactionID = je.TransactionID AND je.AccountingBasis = 'Cash'
			INNER JOIN VendorPaymentJournalEntry vpje ON ta.TransactionID = vpje.TransactionID AND vpje.ReportOn1099 = 1 AND vpje.JournalEntryID = je.JournalEntryID
			INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID
			INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
								AND pay.[Date] >= #p.StartDate AND pay.[Date] <= #p.EndDate
			INNER JOIN Vendor v ON v.VendorID = i.VendorID		
			CROSS APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, #p.InvoiceStatusDate) AS INVSTAT
			LEFT JOIN [Transaction] tr ON ta.TransactionID = tr.ReversesTransactionID AND tr.TransactionDate <= #p.EndDate
		WHERE INVSTAT.InvoiceStatus <> 'Void'
		  AND v.Gets1099 = 1
		  AND tr.TransactionID IS NULL
		
	INSERT #Invoices
		SELECT	
				i.InvoiceID,
				i.Number AS 'InvoiceNumber',
				v.VendorID,
				v.CompanyName AS 'Vendor',
				i.InvoiceDate,
				i.AccountingDate,
				i.DueDate,
				i.[Description],
				SUM(#ili.Total) AS 'Total'
			FROM #InvoiceLineItems #ili
				INNER JOIN Invoice i ON #ili.InvoiceID = i.InvoiceID
				INNER JOIN Vendor v ON i.VendorID = v.VendorID
				INNER JOIN Person p on i.CreatedByPersonID = p.PersonID
			GROUP BY i.InvoiceID, i.Number, v.CompanyName, v.VendorID, i.InvoiceDate, i.AccountingDate, i.DueDate, i.[Description]																			
			
	SELECT * FROM #Invoices
		ORDER BY Vendor, AccountingDate, InvoiceNumber, InvoiceID
		
	SELECT	InvoiceID,
			PropertyID,
			PropertyName,
			PropertyAbbreviation,
			GLAccountNumber,
			GLAccountName,
			GLAccountID,
			[Description],
			Total,
			Report1099
		FROM #InvoiceLineItems	
		ORDER BY PropertyAbbreviation, InvoiceNumber, AccountingDate		

END
GO
