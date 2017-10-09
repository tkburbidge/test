SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 23, 2014
-- Description:	Gets the Payment History for a given Vendor
-- =============================================
CREATE PROCEDURE [dbo].[RPT_VNDR_VendorPaymentHistory] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@vendorID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null,
	@paymentTypes StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	CREATE TABLE #PaymentTypes ( PaymentType nvarchar(500) )

	INSERT #PropertyIDs SELECT Value FROM @propertyIDs 
	INSERT #PaymentTypes SELECT Value FROM @paymentTypes 

	CREATE TABLE #VendorPayments (
		PaymentID uniqueidentifier not null,
		[Type] nvarchar(250) null,
		[Date] date null,
		Reference nvarchar(500) null,
		Amount money null,
		Memo nvarchar(1000) null,
		PropertyID uniqueidentifier null
		)

	INSERT #VendorPayments
		SELECT DISTINCT
					   pay.PaymentID, 
					   CASE 
						   WHEN (tt.[Group] = 'Invoice') THEN 'InvoicePayment'
						   WHEN (tt.[Group] = 'Bank') THEN 'VendorPayment'
						   END AS 'Type',
					   pay.[Date], 
					   pay.ReferenceNumber AS 'Reference', 
					   CASE 
						   WHEN pay.Reversed = 1 THEN 0
						   WHEN tt.Name = 'Vendor Credit' THEN -pay.Amount						   
						   --WHEN pay.PaidOut = 1 THEN pay.Amount
						   ELSE pay.Amount
					   END, 
					   pay.Notes AS 'Memo',
					   t.PropertyID AS 'PropertyID'
				   FROM Payment pay
					   INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID 
					   INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
					   INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] IN ('Invoice', 'Bank')
					   LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
					   LEFT JOIN [Transaction] t1 on t1.AppliesToTransactionID = t.TransactionID
					   INNER JOIN #PropertyIDs pid ON t.PropertyID = pid.PropertyID
					   INNER JOIN #PaymentTypes ptype ON pay.[Type] = ptype.PaymentType
				   WHERE pay.ObjectID = @vendorID 
					 AND (((@accountingPeriodID IS NULL) AND (pay.[Date] >= @startDate) AND (pay.[Date] <= @endDate))
					   OR ((@accountingPeriodID IS NOT NULL) AND (pay.[Date] >= pap.StartDate) AND (pay.[Date] <= pap.EndDate)))
					 AND t1.TransactionID IS NULL
					 AND pay.Reversed = 0

	SELECT * FROM #VendorPayments 
		ORDER BY PaymentID

	SELECT #vp.PaymentID,
			ili.InvoiceID,
			p.Abbreviation AS 'PropertyAbbreviation',
			#vp.[Type],
			i.Number AS 'Reference',
			gla.Number AS 'GLAccountNumber',
			gla.Name AS 'GLAccountName',
			t.[Description],
			CASE
				WHEN (ili.Report1099 = 1) THEN ta.Amount 
				ELSE 0
				END AS 'Form1099Amount',
			CASE 
				WHEN (ili.Report1099 = 1) THEN 0
				ELSE ta.Amount 
				END AS 'NonForm1099Amount'
		FROM #VendorPayments #vp
			INNER JOIN PaymentTransaction pt ON #vp.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] ta ON pt.TransactionID = ta.TransactionID 
			INNER JOIN TransactionType tt ON ta.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] IN ('Invoice')
			INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
			INNER JOIN InvoiceLineItem ili ON t.TransactionID = ili.TransactionID
			INNER JOIN Invoice i ON ili.InvoiceID = i.InvoiceID
			INNER JOIN Property p ON p.PropertyID = #vp.PropertyID 
			INNER JOIN JournalEntry je ON ta.TransactionID = je.TransactionID AND je.Amount > 0 AND je.AccountingBasis = 'Cash'
			INNER JOIN GLAccount gla ON je.GLAccountID = gla.GLAccountID
		WHERE je.AccountingBookID IS NULL	

	UNION ALL

	SELECT	#vp.PaymentID,
			null,
			p.Abbreviation AS 'PropertyAbbreviation',
			#vp.[Type],
			#vp.Reference AS 'Reference',
			gla.Number AS 'GLAccountNumber',
			gla.Name AS 'GLAccountName',
			t.[Description],
			CASE
				WHEN (vpje.ReportOn1099 = 1 AND tt.Name = 'Vendor Credit') THEN -t.Amount 
				WHEN (vpje.ReportOn1099 = 1) THEN t.Amount
				ELSE 0
				END AS 'Form1099Amount',
			CASE 
				WHEN (vpje.ReportOn1099 = 1) THEN 0
				WHEN (vpje.ReportOn1099 = 0 AND tt.Name = 'Vendor Credit') THEN -t.Amount
				ELSE t.Amount 
				END AS 'NonForm1099Amount'
		FROM #VendorPayments #vp
			INNER JOIN PaymentTransaction pt ON #vp.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID 
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] IN ('Bank')
			INNER JOIN Property p ON p.PropertyID = #vp.PropertyID
			INNER JOIN JournalEntry je ON t.TransactionID = je.TransactionID AND je.AccountingBasis = 'Cash'
			INNER JOIN GLAccount gla ON je.GLAccountID = gla.GLAccountID
			INNER JOIN VendorPaymentJournalEntry vpje ON je.JournalEntryID = vpje.JournalEntryID
		WHERE je.AccountingBookID IS NULL	
END

GO
