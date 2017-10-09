SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: May 17, 2013
-- Description:	Gets each invoice line item for a given date range and the amount paid along with the GL information
-- =============================================
CREATE PROCEDURE [dbo].[RPT_VNDR_VendorLedgerByGL] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@vendorID uniqueidentifier = null,
	@dateFilter nvarchar(20) = null,
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	CREATE TABLE #VendorLedgerGL
	(
		PropertyID uniqueidentifier not null,
		GLNumber nvarchar(20) null,
		GLName nvarchar(50) null,
		GLAccountID uniqueidentifier null,
		InvoiceID uniqueidentifier null,
		InvoiceLineItemID uniqueidentifier null,
		InvoiceNumber nvarchar(500) null,
		InvoiceDate date null,
		DueDate date null,
		AccountingDate date null,
		PropertyAbbreviation nvarchar(10) null,
		[Description] nvarchar(MAX) null,
		Total money null,
		AmountPaid money null,
		CreditsApplied money null,
		LastReference nvarchar(50) null,
		LastReferenceDate date null,
		IsCredit bit null,
		IsInvoice bit null
	)
	
	INSERT INTO #VendorLedgerGL
		SELECT	DISTINCT 
				t.PropertyID,
				gla.Number,
				gla.Name,
				gla.GLAccountID,
				i.InvoiceID,
				ili.InvoiceLineItemID,
				i.Number,
				i.InvoiceDate,
				i.DueDate,
				i.AccountingDate,
				p.Abbreviation AS 'PropertyAbbreviation',
				i.[Description],
				SUM(t.Amount) AS 'Total',
				null AS 'AmountPaid',
				null AS 'CreditsApplied',
				null AS 'LastReference',
				null AS 'LastReferenceDate',
				i.Credit AS 'IsCredit',
				1 AS 'IsInvoice'
			FROM InvoiceLineItem ili
				INNER JOIN GLAccount gla ON ili.GLAccountID = gla.GLAccountID
				INNER JOIN Invoice i ON ili.InvoiceID = i.InvoiceID
				INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				CROSS APPLY [GetInvoiceStatusByInvoiceID] (i.InvoiceID, @endDate) InvoiceStatus
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE i.VendorID = @vendorID
			  AND t.PropertyID IN (SELECT Value FROM @propertyIDs)
			  AND InvoiceStatus.InvoiceStatus <> 'Void'
			  AND (((@accountingPeriodID IS NULL)
				  AND ((((@dateFilter = 'Accounting') AND (@startDate <= i.AccountingDate) AND (@endDate >= i.AccountingDate))
						OR (((@dateFilter = 'Invoice') AND (@startDate <= i.InvoiceDate) AND (@endDate >= i.InvoiceDate))))))
				OR ((@accountingPeriodID IS NOT NULL)
				  AND ((((@dateFilter = 'Accounting') AND (pap.StartDate <= i.AccountingDate) AND (pap.EndDate >= i.AccountingDate))
						OR (((@dateFilter = 'Invoice') AND (pap.StartDate <= i.InvoiceDate) AND (pap.EndDate >= i.InvoiceDate)))))))
			GROUP BY t.PropertyID, p.Abbreviation, i.InvoiceID, ili.InvoiceLineItemID, i.Number, i.InvoiceDate, i.DueDate, i.AccountingDate, i.[Description], i.Credit, gla.Number, gla.Name, gla.GLAccountID
			
	INSERT #VendorLedgerGL
		SELECT	t.PropertyID,
				gla.Number,
				gla.Name,
				gla.GLAccountID,
				pay.PaymentID,
				pay.PaymentID,
				pay.[Description],
				pay.[Date],
				pay.[Date],
				pay.[Date],
				p.Abbreviation,
				pay.[Description],
				je.Amount,
				je.Amount,
				0,
				null,
				null,
				0,
				0
			FROM BankTransaction bt
				INNER JOIN Payment pay ON bt.ObjectID = pay.PaymentID AND bt.ObjectType = 'Payment' AND pay.ObjectID = @vendorID
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID
				INNER JOIN JournalEntry je ON t.TransactionID = je.TransactionID AND je.AccountingBasis = 'Cash' AND je.GLAccountID <> ba.GLAccountID
				INNER JOIN GLAccount gla ON je.GLAccountID = gla.GLAccountID
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Check', 'VendorCredit') AND tt.[Group] = 'Bank'
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE t.PropertyID IN (SELECT Value FROM @propertyIDs)
			  --AND pay.[Date] >= @startDate
			  --AND pay.[Date] <= @endDate
			  AND (((@accountingPeriodID IS NULL) AND (pay.[Date] >= @startDate) AND (pay.[Date] <= @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (pay.[Date] >= pap.StartDate) AND (pay.[Date] <= pap.EndDate)))
			  AND je.AccountingBookID IS NULL
			  AND tr.TransactionID IS NULL
			
	UPDATE #VendorLedgerGL SET AmountPaid = (SELECT ISNULL(SUM(ta.Amount), 0)
			FROM #VendorLedgerGL #vl		
				INNER JOIN InvoiceLineItem ili ON ili.InvoiceLineItemID = #vl.InvoiceLineItemID AND #vl.InvoiceLineItemID = #VendorLedgerGL.InvoiceLineItemID
				INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID AND #vl.PropertyID = t.PropertyID AND #VendorLedgerGL.PropertyID = t.PropertyID
				INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
				INNER JOIN TransactionType tt ON ta.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Payment'			
				LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
				LEFT JOIN PropertyAccountingPeriod pap ON #vl.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE (tar.TransactionID IS NULL 
			   OR (((@accountingPeriodID IS NULL) AND (tar.TransactionDate > @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (tar.TransactionDate > pap.EndDate)))))
		WHERE IsInvoice = 1
		
	UPDATE #VendorLedgerGL SET CreditsApplied = (SELECT ISNULL(SUM(ta.Amount), 0)
		FROM #VendorLedgerGL #vl			
			INNER JOIN InvoiceLineItem ili ON ili.InvoiceLineItemID = #vl.InvoiceLineItemID AND #vl.InvoiceLineItemID = #VendorLedgerGL.InvoiceLineItemID
			INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID AND #vl.PropertyID = t.PropertyID AND #VendorLedgerGL.PropertyID = t.PropertyID
			INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
			INNER JOIN TransactionType tt ON ta.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Credit'			
			LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
			LEFT JOIN PropertyAccountingPeriod pap ON #vl.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE ((tar.TransactionID IS NULL 
			   OR (((@accountingPeriodID IS NULL) AND (tar.TransactionDate > @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (tar.TransactionDate > pap.EndDate)))))
		  AND #vl.IsInvoice = 1)
		
	UPDATE #VendorLedgerGL SET LastReference = (SELECT TOP 1 pay.ReferenceNumber
		FROM #VendorLedgerGL #vl			
			INNER JOIN InvoiceLineItem ili ON ili.InvoiceLineItemID = #vl.InvoiceLineItemID AND #vl.InvoiceLineItemID = #VendorLedgerGL.InvoiceLineItemID
			INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID AND #vl.PropertyID = t.PropertyID AND #VendorLedgerGL.PropertyID = t.PropertyID
			INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
			INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID
			INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
			LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
			LEFT JOIN PropertyAccountingPeriod pap ON #vl.PropertyID = pap.PropertyID AND @accountingPeriodID = pap.AccountingPeriodID
		WHERE ((tar.TransactionID IS NULL 
			   OR (((@accountingPeriodID IS NULL) AND (tar.TransactionDate > @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (tar.TransactionDate > pap.EndDate)))))
		  AND #vl.IsInvoice = 1
		ORDER BY pay.[Date] DESC, pay.[Timestamp] DESC)		
	
	UPDATE #VendorLedgerGL SET LastReferenceDate = (SELECT TOP 1 pay.[Date]
		FROM #VendorLedgerGL #vl			
			INNER JOIN InvoiceLineItem ili ON ili.InvoiceLineItemID = #vl.InvoiceLineItemID AND #vl.InvoiceLineItemID = #VendorLedgerGL.InvoiceLineItemID
			INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID AND #vl.PropertyID = t.PropertyID AND #VendorLedgerGL.PropertyID = t.PropertyID
			INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
			INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID
			INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
			LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
			LEFT JOIN PropertyAccountingPeriod pap ON #vl.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE ((tar.TransactionID IS NULL 
			   OR (((@accountingPeriodID IS NULL) AND (tar.TransactionDate > @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (tar.TransactionDate > pap.EndDate)))))
		  AND #vl.IsInvoice = 1
		ORDER BY pay.[Date] DESC, pay.[Timestamp] DESC)				
	
	SELECT * FROM #VendorLedgerGL 
	ORDER BY 
		PropertyAbbreviation, 
		IsInvoice DESC,
		CASE WHEN @dateFilter = 'Accounting' THEN AccountingDate ELSE '' END ASC,
		CASE WHEN @dateFilter = 'Invoice' THEN InvoiceDate ELSE '' END ASC,
		RIGHT('0000000000000000000000000' + InvoiceNumber, 25)
END



GO
