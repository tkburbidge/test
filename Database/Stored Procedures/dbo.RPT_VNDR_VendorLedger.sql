SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: May 17, 2013
-- Description:	Gets each invoice grouped by property for a given date range and the amount paid.
-- =============================================
CREATE PROCEDURE [dbo].[RPT_VNDR_VendorLedger] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@vendorID uniqueidentifier = null,
	@dateFilter nvarchar(50) = null,
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	CREATE TABLE #VendorLedger
	(
		PropertyID uniqueidentifier not null,
		InvoiceID uniqueidentifier null,
		InvoiceNumber nvarchar(50) null,
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
	
	INSERT INTO #VendorLedger
		SELECT	DISTINCT 
				t.PropertyID,
				i.InvoiceID,
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
				1
			FROM InvoiceLineItem ili
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
			GROUP BY p.Abbreviation, t.PropertyID, i.InvoiceID, i.Number, i.InvoiceDate, i.DueDate, i.AccountingDate, i.[Description], i.Credit
			
	INSERT #VendorLedger
		SELECT	DISTINCT
				t.PropertyID,
				pay.PaymentID,
				bt.ReferenceNumber,
				pay.[Date],
				pay.[Date],
				pay.[Date],
				p.Abbreviation,
				pay.[Description],
				CASE 
					WHEN tt.Name IN ('VendorCredit') THEN -pay.Amount
					ELSE pay.Amount END,
				CASE 
					WHEN tt.Name IN ('VendorCredit') THEN -pay.Amount
					ELSE pay.Amount END,
				0,
				null,
				null,
				CAST(0 AS bit),
				0
			FROM BankTransaction bt
				INNER JOIN Payment pay ON bt.ObjectID = pay.PaymentID AND bt.ObjectType = 'Payment' AND pay.ObjectID = @vendorID
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Check', 'VendorCredit') AND tt.[Group] = 'Bank'
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE t.PropertyID IN (SELECT Value FROM @propertyIDs)
			  AND (((@accountingPeriodID IS NULL) AND (pay.[Date] >= @startDate) AND (pay.[Date] <= @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (pay.[Date] >= pap.StartDate) AND (pay.[Date] <= pap.EndDate)))
			  AND tr.TransactionID IS NULL
			
	UPDATE #VendorLedger SET AmountPaid = (SELECT ISNULL(SUM(ta.Amount), 0)
			FROM #VendorLedger #vl
				INNER JOIN Invoice i ON #vl.InvoiceID = i.InvoiceID AND #vl.InvoiceID = #VendorLedger.InvoiceID
				INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
				INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID AND #vl.PropertyID = t.PropertyID AND #VendorLedger.PropertyID = t.PropertyID
				INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
				INNER JOIN TransactionType tt ON ta.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Payment'			
				LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
				LEFT JOIN PropertyAccountingPeriod pap ON #vl.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE (tar.TransactionID IS NULL 
			   OR (((@accountingPeriodID IS NULL) AND (tar.TransactionDate > @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (tar.TransactionDate > pap.EndDate))))
			  AND #vl.IsInvoice = 1)
		WHERE IsInvoice = 1
		
	UPDATE #VendorLedger SET CreditsApplied = (SELECT ISNULL(SUM(ta.Amount), 0)
		FROM #VendorLedger #vl
			INNER JOIN Invoice i ON #vl.InvoiceID = i.InvoiceID AND #vl.InvoiceID = #VendorLedger.InvoiceID
			INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
			INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID AND #vl.PropertyID = t.PropertyID AND #VendorLedger.PropertyID = t.PropertyID
			INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
			INNER JOIN TransactionType tt ON ta.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Credit'			
			LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
			LEFT JOIN PropertyAccountingPeriod pap ON #vl.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE (tar.TransactionID IS NULL 
			   OR (((@accountingPeriodID IS NULL) AND (tar.TransactionDate > @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (tar.TransactionDate > pap.EndDate))))
		  AND #vl.IsInvoice = 1)
		
	UPDATE #VendorLedger SET LastReference = (SELECT TOP 1 pay.ReferenceNumber
		FROM #VendorLedger #vl
			INNER JOIN Invoice i ON #vl.InvoiceID = i.InvoiceID AND #vl.InvoiceID = #VendorLedger.InvoiceID
			INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
			INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID AND #vl.PropertyID = t.PropertyID AND #VendorLedger.PropertyID = t.PropertyID
			INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
			INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID
			INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
			LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
			LEFT JOIN PropertyAccountingPeriod pap ON #vl.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE (tar.TransactionID IS NULL 
			   OR (((@accountingPeriodID IS NULL) AND (tar.TransactionDate > @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (tar.TransactionDate > pap.EndDate))))
		  AND #vl.IsInvoice = 1
		ORDER BY pay.[Date] DESC, pay.[Timestamp] DESC)		
		
	UPDATE #VendorLedger SET LastReferenceDate = (SELECT TOP 1 pay.[Date]
		FROM #VendorLedger #vl
			INNER JOIN Invoice i ON #vl.InvoiceID = i.InvoiceID AND #vl.InvoiceID = #VendorLedger.InvoiceID
			INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
			INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID AND #vl.PropertyID = t.PropertyID AND #VendorLedger.PropertyID = t.PropertyID
			INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID 
			INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID
			INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
			LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
			LEFT JOIN PropertyAccountingPeriod pap ON #vl.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE (tar.TransactionID IS NULL 
			   OR (((@accountingPeriodID IS NULL) AND (tar.TransactionDate > @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (tar.TransactionDate > pap.EndDate))))
		  AND #vl.IsInvoice = 1
		ORDER BY pay.[Date] DESC, pay.[Timestamp] DESC)		
	
	SELECT * FROM #VendorLedger 
	ORDER BY
		PropertyAbbreviation, 
		IsInvoice DESC,
		CASE WHEN @dateFilter = 'Accounting' THEN AccountingDate ELSE '' END ASC,
		CASE WHEN @dateFilter = 'Invoice' THEN InvoiceDate ELSE '' END ASC,
		RIGHT('0000000000000000000000000' + InvoiceNumber, 25)
END




GO
