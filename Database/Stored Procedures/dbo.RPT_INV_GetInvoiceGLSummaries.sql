SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 14, 2012
-- Description:	Gets the data fro the InvoiceGLSummary report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_INV_GetInvoiceGLSummaries] 
	-- Add the parameters for the stored procedure here
	@propertyID uniqueidentifier,
	@invoiceBatchID uniqueidentifier = null,
	@startDate datetime = null,
	@endDate datetime = null,
	@invoiceFilterDate nvarchar(50) = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	IF (@accountingPeriodID IS NOT NULL)
	BEGIN
		SET @startDate = (SELECT TOP 1 StartDate FROM PropertyAccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
		SET @endDate = (SELECT TOP 1 EndDate FROM PropertyAccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
	END

	SELECT DISTINCT gla.Number AS 'GLNumber', gla.Name AS 'GLName', gla.GLAccountID AS 'GLAccountID', SUM(je.Amount) AS 'Amount'
		FROM GLAccount gla
			INNER JOIN JournalEntry je ON je.GLAccountID = gla.GLAccountID AND je.AccountingBasis = 'Accrual'
			INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
			INNER JOIN Invoice i ON t.ObjectID = i.InvoiceID
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			--LEFT JOIN InvoiceBatch ib ON i.InvoiceID = ib.InvoiceID
			LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
			OUTER APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, @endDate) AS IVS
		WHERE t.PropertyID = @propertyID
		  AND (IVS.InvoiceID IS NULL OR InvoiceStatus NOT IN ('Void', 'Voided'))
		  AND tr.TransactionID IS NULL
		  -- Either they specify a BatchID and the InvoiceBatch entry for this invoice and batch exists
		  -- or the invoice was posted during the date range
		  AND (((@invoiceBatchID IS NOT NULL) AND (EXISTS (SELECT * FROM InvoiceBatch ib WHERE ib.BatchID = @invoiceBatchID AND ib.InvoiceID = i.InvoiceID)))
				OR
			   ((@startDate IS NOT NULL) AND (@endDate IS NOT NULL) 
					AND (((@invoiceFilterDate IS NULL OR @invoiceFilterDate = 'AccountingDate') AND (i.AccountingDate >= @startDate) AND (i.AccountingDate <= @endDate))
					  OR ((@invoiceFilterDate = 'InvoiceDate') AND (i.InvoiceDate >= @startDate) AND (i.InvoiceDate <= @endDate))
					  OR ((@invoiceFilterDate = 'DueDate') AND (i.DueDate >= @startDate) AND (i.DueDate <= @endDate))
					  OR ((@invoiceFilterDate = 'ReceivedDate') AND (i.ReceivedDate >= @startDate) AND (i.ReceivedDate <= @endDate)))))
		GROUP BY gla.GLAccountID, gla.Number, gla.Name
			

END

GO
