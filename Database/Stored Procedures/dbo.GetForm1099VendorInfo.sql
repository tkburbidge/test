SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oc.t 20, 2012
-- Description:	Gets Vendor 1099 Information
-- =============================================
CREATE PROCEDURE [dbo].[GetForm1099VendorInfo] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null, 
	@year int = 0,
	@formType nvarchar(20) = null,
	@allVendors bit = 0,
	@overLimit bit = 0,
	@propertyIDs GuidCollection READONLY,
	@vendorIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs

	CREATE TABLE #VendorIDs ( VendorID uniqueidentifier )
	INSERT INTO #VendorIDs SELECT Value FROM @vendorIDs

	DECLARE @vendorCount int
	SET @vendorCount = (SELECT COUNT(*) FROM #VendorIDs)

	CREATE TABLE #Vendors1099 (
		VendorID uniqueidentifier not null,
		RecipientIDNumber nvarchar(100) null,
		RecipientsName nvarchar(200) null,
		StreetAddress nvarchar(200) null,
		City nvarchar(50) null,
		[State] nvarchar(50) null,
		Zip nvarchar(15) null,
		SecondTINNotice bit null,
		Amount money null,
		SumOfInvoices money null,
		SumOfVendorPayments money null,
		BeginningBalance money null,
		Form1099Type nvarchar(10) null,
		GrossProceedsPaidToAttorney bit null,
		Country nvarchar(50) null)	
		
	INSERT #Vendors1099
		SELECT	DISTINCT 
				v.VendorID,
				v.Form1099RecipientsID, 
				ISNULL(NULLIF(v.Form1099RecipientsName,''),v.CompanyName), 
				null, null, null, null, 
				v.SecondTINNotice,
				0, 0, 0, 0,				
				v.Form1099Type, 
				v.GrossProceedsPaidToAttorney,
				null
			FROM VendorProperty vp
				INNER JOIN Vendor v ON vp.VendorID = v.VendorID 
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = vp.PropertyID
				LEFT JOIN #VendorIDs #vids ON #vids.VendorID = vp.VendorID
			WHERE ((v.Gets1099 = 1) OR (@allVendors = 1))
				AND ((v.Form1099Type = @formType) OR (@formType IS NULL))
				AND ((@vendorCount > 0 AND #vids.VendorID IS NOT NULL) OR (@vendorCount = 0))
		
	UPDATE #Vendors1099 SET BeginningBalance = (SELECT SUM(ISNULL(vp.BeginningBalance, 0))
												FROM VendorProperty vp
												INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = vp.PropertyID
												WHERE vp.BeginningBalanceYear = @year
													AND vp.VendorID = #Vendors1099.VendorID)

	UPDATE #Vendors1099 SET SumOfInvoices = 
		(SELECT SUM(CASE 
						WHEN (tt.Name = 'Charge') THEN ta.Amount
						WHEN (tt.Name = 'Credit') THEN -ta.Amount END)
			FROM [Transaction] t
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
				INNER JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN InvoiceLineItem ili ON t.TransactionID = ili.TransactionID AND ili.Report1099 = 1
				INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID
				INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID AND DATEPART(year, pay.[Date]) = @year
				INNER JOIN Invoice i ON ili.InvoiceID = i.InvoiceID AND i.VendorID = #Vendors1099.VendorID
				LEFT JOIN [Transaction] tr ON ta.TransactionID = tr.ReversesTransactionID
			WHERE tr.TransactionID IS NULL
				AND t.ReversesTransactionID IS NULL)
				
	UPDATE #Vendors1099 SET SumOfVendorPayments =
		(SELECT SUM(je.Amount)
			FROM Payment pay
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID AND DATEPART(year, pay.[Date]) = @year
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] IN ('Bank') AND tt.Name IN ('Check', 'Vendor Credit')
				INNER JOIN JournalEntry je ON t.TransactionID = je.TransactionID AND je.AccountingBasis = 'Cash' 
				INNER JOIN VendorPaymentJournalEntry vpje ON t.TransactionID = vpje.TransactionID AND vpje.ReportOn1099 = 1 AND je.JournalEntryID = vpje.JournalEntryID
				LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
			WHERE pay.ObjectID = #Vendors1099.VendorID
				AND tr.TransactionID IS NULL
				AND je.AccountingBookID IS NULL
				AND t.ReversesTransactionID IS NULL)

	SELECT	DISTINCT
			#vendrs.VendorID,
			#vendrs.RecipientIDNumber AS 'RecipientsIDNumber',
			#vendrs.RecipientsName,
			a.StreetAddress,
			a.City,
			a.[State],
			a.Zip,
			ISNULL(#vendrs.BeginningBalance, 0) + ISNULL(#vendrs.SumOfInvoices, 0) + ISNULL(#vendrs.SumOfVendorPayments, 0) AS 'Amount',
			ISNULL(#vendrs.SumOfInvoices, 0) AS 'SumOfInvoices',
			ISNULL(#vendrs.SumOfVendorPayments, 0) AS 'SumOfVendorPayments',
			ISNULL(#vendrs.BeginningBalance, 0) AS 'BeginningBalance',
			#vendrs.Form1099Type,
			ISNULL(#vendrs.GrossProceedsPaidToAttorney, 0) AS 'GrossProceedsPaidToAttorney',
			COALESCE(a.Country, '') AS 'Country'
		FROM #Vendors1099 #vendrs
			INNER JOIN VendorPerson vp ON #vendrs.VendorID = vp.VendorID
			INNER JOIN Person per ON vp.PersonID = per.PersonID
			INNER JOIN PersonType pert ON per.PersonID = pert.PersonID AND pert.[Type] = 'VendorGeneral'
			LEFT JOIN [Address] a ON per.PersonID = a.ObjectID
		WHERE ((@overLimit = 0) OR (ISNULL(#vendrs.BeginningBalance, 0) + ISNULL(#vendrs.SumOfInvoices, 0) + ISNULL(#vendrs.SumOfVendorPayments, 0)) >= 600)
		ORDER BY RecipientsName
END
GO
