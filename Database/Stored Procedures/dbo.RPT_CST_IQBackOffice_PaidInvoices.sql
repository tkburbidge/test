SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Nov. 19, 2015
-- Description:	Custom report that shows all invoices paid in a date range
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_IQBackOffice_PaidInvoices] 
	-- Add the parameters for the stored procedure here
	@propertyID uniqueidentifier = null, 
	@startDate date = null,
	@endDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	CREATE TABLE #IQPaidInvoices (
		VendorID uniqueidentifier null,
		InvoiceID uniqueidentifier null,
		Abbreviation nvarchar(50) null,									--Vendor.Abbreviation
		Company nvarchar(500) null,										--Vendor.Company
		PaymentDate date null,											--Payment.Date
		Reference nvarchar(50) null,									--Payment.Reference
		Amount money null,												--Payment.Amount
		Number nvarchar(50) null,										--Invoice.Number
		InvoiceDate date null,											--Invoice.Date
		InvoiceDueDate date null,										--Invoice.DueDate
		[Description] nvarchar(500) null,								--Invoice.Description
		InvoicePaidAmount money null,									--Invoice Paid Amount
		CreditsApplied money null
		)
	INSERT #IQPaidInvoices
		SELECT	vend.VendorID,
				inv.InvoiceID,
				vend.Abbreviation,
				vend.CompanyName,
				null, 
				null,
				null,
				inv.Number,
				inv.InvoiceDate,
				inv.DueDate,
				inv.[Description],
				null,
				null
			FROM Payment pay
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID AND t.PropertyID = @propertyID
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Payment') AND tt.[Group] IN ('Invoice')
				INNER JOIN [Transaction] tInv ON t.AppliesToTransactionID = tInv.TransactionID
				INNER JOIN Invoice inv ON tInv.ObjectID = inv.InvoiceID
				INNER JOIN Vendor vend ON inv.VendorID = vend.VendorID
				LEFT JOIN SummaryVendor sv ON inv.SummaryVendorID = sv.SummaryVendorID
				LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
			WHERE pay.PaidOut = 1
			  AND pay.[Date] >= @startDate
			  AND pay.[Date] <= @endDate
			  AND (tr.TransactionID IS NULL OR tr.TransactionDate > @endDate)
	
	UPDATE #IQPaidInvoices SET InvoicePaidAmount = (SELECT ISNULL(SUM(ISNULL(t.Amount, 0)), 0)
														FROM [Transaction] t
															INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
																			AND tt.Name IN ('Payment') AND tt.[Group] IN ('Invoice')
															LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
															WHERE tr.TransactionID IS NULL
															  AND t.AppliesToTransactionID IN (SELECT ili.TransactionID
																								  FROM InvoiceLineItem ili
																									  INNER JOIN [Transaction] t1 ON t1.TransactionID = ili.TransactionID
																								  WHERE ili.InvoiceID = #IQPaidInvoices.InvoiceID))
	UPDATE #IQPaidInvoices SET CreditsApplied = (SELECT ISNULL(SUM(ISNULL(t.Amount, 0)), 0)
													FROM [Transaction] t
														INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
																		AND tt.Name IN ('Credit') AND tt.[Group] IN ('Invoice')
														LEFT JOIN [Transaction] rt ON t.TransactionID = rt.ReversesTransactionID
													WHERE rt.TransactionID IS NULL
													  AND t.AppliesToTransactionID IN (SELECT ili.TransactionID
																						  FROM InvoiceLineItem ili
																							  INNER JOIN [Transaction] t1 ON t1.TransactionID = ili.TransactionID
																						  WHERE ili.InvoiceID = #IQPaidInvoices.InvoiceID))
	UPDATE #IQPaidInvoices SET InvoicePaidAmount = ISNULL(InvoicePaidAmount, 0.00) + ISNULL(CreditsApplied, 0.00)
	UPDATE #IQPaidInvoices SET Reference = PaymentInfo.ReferenceNumber, PaymentDate = PaymentInfo.[Date], Amount = PaymentInfo.Amount
		FROM #IQPaidInvoices iqPaid
			OUTER APPLY
				(SELECT TOP 1 at.ObjectID AS 'InvoiceID', pay.ReferenceNumber, pay.[Date], pay.Amount
					FROM [Transaction] t
						INNER JOIN PaymentTransaction pt ON pt.TransactionID = t.TransactionID
						INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
											AND tt.Name IN ('Payment') AND tt.[Group] IN ('Invoice')
						INNER JOIN [Transaction] at ON t.AppliesToTransactionID = at.TransactionID
						LEFT JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
					WHERE tr.TransactionID IS NULL
					  AND t.AppliesToTransactionID IN (SELECT TransactionID	
														   FROM [Transaction] 
														   WHERE ObjectID = iqPaid.InvoiceID)
					  AND (pay.[Date] >= @startDate AND pay.[Date] <= @endDate)
					ORDER BY pay.[Date] DESC, pay.[TimeStamp] DESC) AS PaymentInfo
			WHERE iqPaid.InvoiceID = PaymentInfo.InvoiceID
	SELECT	DISTINCT
			#iqInv.Abbreviation,
			#iqInv.Company,
			#iqInv.PaymentDate,
			#iqInv.Reference,
			#iqInv.Amount,
			#iqInv.Number,
			#iqInv.InvoiceDate,
			#iqInv.InvoiceDueDate,
			#iqInv.[Description],
			CASE WHEN (inv.Credit <> 1) THEN #iqInv.InvoicePaidAmount
				 ELSE -#iqInv.InvoicePaidAmount END AS 'InvoicePaidAmount'
		FROM #IQPaidInvoices #iqInv
			INNER JOIN Invoice inv ON #iqInv.InvoiceID = inv.InvoiceID
		WHERE #iqInv.Amount > 0
END
GO
