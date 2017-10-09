SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Phillip Lundquist
-- Create date: May 22, 2012
-- Description:	Retrieves all the invoices that were paid
-- or partially paid on the given date range
-- =============================================
CREATE PROCEDURE [dbo].[RPT_INV_PaidInvoices]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@startDate date,
	@endDate date,
	@accountingPeriodID uniqueidentifier,
	@paymentTypes StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	CREATE TABLE #PaymentTypes ( PaymentType nvarchar(500) )

	INSERT #PropertyIDs SELECT Value FROM @propertyIDs 
	INSERT #PaymentTypes SELECT Value FROM @paymentTypes 
				
   
	CREATE TABLE #PaidInvoices(
		PropertyID uniqueidentifier,
		PropertyAbbreviation nvarchar(200),
		InvoiceID uniqueidentifier,
		InvoiceNumber nvarchar(50),
		Vendor nvarchar(500),
		[Description] nvarchar(500),
		IsCredit bit,
		InvoiceDate date,
		InvoiceAmount money,
		AmountPaid money null,
		AmountDue money null,
		CreditsApplied money null,
		LastReference nvarchar(50),
		LastReferenceDate date,
		LastBank nvarchar(200))
	
	INSERT INTO #PaidInvoices
		SELECT DISTINCT	
			prop.PropertyID,	
			prop.Abbreviation,
			i.InvoiceID AS 'InvoiceID', 
			i.Number AS 'InvoiceNumber', 
			(CASE WHEN i.SummaryVendorID IS NOT NULL THEN sv.Name
				  ELSE v.CompanyName
			 END) AS 'Vendor',
			i.[Description] AS 'Description',
			i.Credit,
			i.InvoiceDate AS 'InvoiceDate', 
			(SELECT ISNULL(SUM(t1.Amount), 0)
				FROM InvoiceLineItem ili
					INNER JOIN [Transaction] t1 ON t1.TransactionID = ili.TransactionID					
				WHERE t1.PropertyID = prop.PropertyID 
					AND ili.InvoiceID = i.InvoiceID) AS 'InvoiceAmount',
			--i.Total AS 'InvoiceAmount',
			null,
			null,
			null,
			null,
			null,
			null
			FROM Payment p
			INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
			INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
			LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
			INNER JOIN TransactionType tt ON tt.TransactionTypeID = t.TransactionTypeID
			INNER JOIN [Transaction] t2 ON t2.TransactionID = t.AppliesToTransactionID
			INNER JOIN Invoice i ON i.InvoiceID = t2.ObjectID
			INNER JOIN Vendor v ON v.VendorID = i.VendorID
			LEFT JOIN SummaryVendor sv ON sv.SummaryVendorID = i.SummaryVendorID
			INNER JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID
			INNER JOIN Property prop ON t2.PropertyID = prop.PropertyID
			LEFT JOIN PropertyAccountingPeriod pap ON prop.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			--INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
			--INNER JOIN [Transaction] ti ON ili.TransactionID = ti.TransactionID AND prop.PropertyID = ti.PropertyID
			INNER JOIN #PropertyIDs pid ON t.PropertyID = pid.PropertyID
			INNER JOIN #PaymentTypes ptype ON p.[Type] = ptype.PaymentType
			WHERE
			tt.Name = 'Payment'
			AND tt.[Group] = 'Invoice'
			AND p.PaidOut = 1
			--AND p.[Date] >= @startDate 
			--AND p.[Date] <= @endDate
			AND (((@accountingPeriodID IS NULL) AND (p.[Date] >= @startDate) AND (p.[Date] <= @endDate))
			  OR ((@accountingPeriodID IS NOT NULL) AND (p.[Date] >= pap.StartDate) AND (p.[Date] <= pap.EndDate)))
			AND (tr.TransactionID IS NULL OR tr.TransactionDate > @endDate)
		
	INSERT INTO #PaidInvoices
		SELECT DISTINCT
			prop.PropertyID,
			prop.Abbreviation,
			i.InvoiceID AS 'InvoiceID', 
			i.Number AS 'InvoiceNumber', 
			(CASE WHEN i.SummaryVendorID IS NOT NULL THEN sv.Name
				  ELSE v.CompanyName
			 END) AS 'Vendor',
			i.[Description] AS 'Description',			
			i.Credit,
			i.InvoiceDate AS 'InvoiceDate', 
			(SELECT ISNULL(SUM(t1.Amount), 0)
				FROM InvoiceLineItem ili
					INNER JOIN [Transaction] t1 ON t1.TransactionID = ili.TransactionID					
				WHERE t1.PropertyID = prop.PropertyID 
					AND ili.InvoiceID = i.InvoiceID) AS 'InvoiceAmount',
			--i.Total AS 'InvoiceAmount',
			null,
			null,
			null,
			null,
			null,
			null
			FROM [Transaction] t
			LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
			INNER JOIN TransactionType tt ON tt.TransactionTypeID = t.TransactionTypeID
			INNER JOIN [Transaction] t2 ON t2.TransactionID = t.AppliesToTransactionID
			INNER JOIN Invoice i ON i.InvoiceID = t2.ObjectID	
			INNER JOIN Property prop ON t2.PropertyID = prop.PropertyID
			INNER JOIN Vendor v ON v.VendorID = i.VendorID
			LEFT JOIN SummaryVendor sv ON sv.SummaryVendorID = i.SummaryVendorID	
			LEFT JOIN PropertyAccountingPeriod pap ON prop.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			--INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
			--INNER JOIN [Transaction] ti ON ili.TransactionID = ti.TransactionID AND prop.PropertyID = ti.PropertyID	
			INNER JOIN #PropertyIDs pid ON t.PropertyID = pid.PropertyID		
			WHERE
			tt.Name = 'Credit'
			AND tt.[Group] = 'Invoice'
			AND t.AppliesToTransactionID IS NOT NULL		
			--AND t.[TransactionDate] >= @startDate 
			--AND t.[TransactionDate] <= @endDate 
			AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate >= @startDate) AND (t.TransactionDate <= @endDate))
			  OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate >= pap.StartDate) AND (t.TransactionDate <= pap.EndDate)))
			AND (tr.TransactionID IS NULL OR tr.TransactionDate > @endDate)
			AND i.InvoiceID NOT IN (SELECT InvoiceID FROM #PaidInvoices)

	UPDATE #PaidInvoices SET AmountPaid = (SELECT ISNULL(SUM(ISNULL(t.Amount, 0)), 0)
										   FROM [Transaction] t
										   INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
										   LEFT JOIN [Transaction] rpt ON rpt.ReversesTransactionID = t.TransactionID
										   LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
										   WHERE t.AppliesToTransactionID IN (SELECT ili.TransactionID
																			   FROM InvoiceLineItem ili
																					INNER JOIN [Transaction] t1 ON t1.TransactionID = ili.TransactionID
																			   WHERE ili.InvoiceID = #PaidInvoices.InvoiceID 
																					AND t1.PropertyID = #PaidInvoices.PropertyID)
										   AND tt.Name = 'Payment'
										   AND tt.[Group] = 'Invoice'
										   --AND t.[TransactionDate] >=@startDate 
										   --AND t.[TransactionDate] <= @endDate
										   AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate >= @startDate) AND (t.TransactionDate <= @endDate))
										     OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate >= pap.StartDate) AND (t.TransactionDate <= pap.EndDate)))
										   AND (rpt.TransactionID IS NULL OR rpt.TransactionDate > @endDate))

	UPDATE #PaidInvoices SET CreditsApplied = (SELECT ISNULL(SUM(ISNULL(t.Amount, 0)), 0)
											   FROM [Transaction] t
											   INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
											   LEFT JOIN [Transaction] rpt ON rpt.ReversesTransactionID = t.TransactionID
											   LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
											   WHERE t.AppliesToTransactionID IN (SELECT ili.TransactionID
																				   FROM InvoiceLineItem ili
																						INNER JOIN [Transaction] t1 ON t1.TransactionID = ili.TransactionID
																				   WHERE ili.InvoiceID = #PaidInvoices.InvoiceID 
																						AND t1.PropertyID = #PaidInvoices.PropertyID)																		   
											   AND tt.Name = 'Credit'
											   AND tt.[Group] = 'Invoice'
											   --AND t.[TransactionDate] >=@startDate 
											   --AND t.[TransactionDate] <= @endDate
											   AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate >= @startDate) AND (t.TransactionDate <= @endDate))
											     OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate >= pap.StartDate) AND (t.TransactionDate <= pap.EndDate)))
											   AND (rpt.TransactionID IS NULL OR rpt.TransactionDate > @endDate))
											   
	UPDATE #PaidInvoices SET AmountDue = InvoiceAmount - AmountPaid - CreditsApplied

	UPDATE paid SET LastReference = PaymentInfo.ReferenceNumber, LastReferenceDate = PaymentInfo.[Date], LastBank = PaymentInfo.AccountName
	FROM #PaidInvoices paid
	OUTER APPLY
	  (SELECT TOP 1 at.ObjectID AS 'InvoiceID', p.ReferenceNumber, ba.AccountName, p.[Date]
	   FROM [Transaction] t
	   INNER JOIN PaymentTransaction pt ON pt.TransactionID = t.TransactionID
	   INNER JOIN Payment p on pt.PaymentID = p.PaymentID
	   INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
	   INNER JOIN BankAccount ba on ba.BankAccountID = t.ObjectID
	   LEFT JOIN [Transaction] rpt ON rpt.ReversesTransactionID = t.TransactionID
	   INNER JOIN [Transaction] at ON at.TransactionID = t.AppliesToTransactionID
	   LEFT JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	   WHERE t.AppliesToTransactionID IN (SELECT TransactionID
										   FROM [Transaction] t
										   WHERE t.ObjectID = paid.InvoiceID)
	   AND tt.Name = 'Payment'
	   AND tt.[Group] = 'Invoice'
	   --AND t.[TransactionDate] >=@startDate 
	   --AND t.[TransactionDate] <= @endDate
	   AND (((@accountingPeriodID IS NULL) AND (t.[TransactionDate] >= @startDate) AND (t.TransactionDate <= @endDate))
	     OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate >= pap.StartDate) AND (t.[TransactionDate] <= pap.EndDate)))
	   AND rpt.TransactionID IS NULL
	   AND t.PropertyID = paid.PropertyID
	   ORDER BY p.[Date] DESC, p.[TimeStamp] DESC) AS PaymentInfo 
	   WHERE PaymentInfo.InvoiceID = paid.InvoiceID

	SELECT * FROM #PaidInvoices	
END

GO
