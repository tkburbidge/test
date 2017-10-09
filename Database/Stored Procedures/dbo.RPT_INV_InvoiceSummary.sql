SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 14, 2012
-- Description:	Generates the data for the InvoiceSummary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_INV_InvoiceSummary] 
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
	
	IF (@invoiceFilterDate IS NULL)
	BEGIN
		SET @invoiceFilterDate = 'AccountingDate'
	END

	IF (@accountingPeriodID IS NOT NULL)
	BEGIN
		SET @startDate = (SELECT TOP 1 StartDate FROM PropertyAccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
		SET @endDate = (SELECT TOP 1 EndDate FROM PropertyAccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
	END

	SELECT	--p.Name AS 'PropertyName',
			CASE WHEN i.SummaryVendorID IS NULL THEN v.CompanyName
				 ELSE sv.Name
			END AS 'Vendor',
			i.InvoiceID AS 'InvoiceID',
			i.Number AS 'InvoiceNumber',
			i.InvoiceDate AS 'InvoiceDate',
			i.AccountingDate AS 'AccountingDate',
			i.DueDate AS 'DueDate',
			i.ReceivedDate AS 'ReceivedDate',
			(SELECT MAX(ta.TransactionDate)
				FROM [Transaction] t
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					LEFT JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
					LEFT JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name = 'Payment' AND tta.[Group] = 'Invoice'
					LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
				WHERE t.ObjectID = i.InvoiceID
					AND t.PropertyID = @propertyID) AS 'LastPayment', 
			-- Sum line items for this invoice and property
			(SELECT ISNULL(SUM(t1.Amount), 0)
				FROM [Transaction] t1
				WHERE t1.ObjectID = i.InvoiceID
					AND t1.PropertyID = @propertyID
					-- Don't include applied credit transactions
					AND t1.AppliesToTransactionID IS NULL) AS 'Amount',
			--i.Total AS 'Amount',
			i.Credit AS 'Credit',
			i.[Description] AS 'Description',		
			CASE
					-- Sum of property line items less sum of payments on those line items is 0
				WHEN (0 = ((SELECT SUM(t.Amount) 
						    FROM InvoiceLineItem ili
						    INNER JOIN [Transaction] t ON t.TransactionID = ili.TransactionID
						    WHERE t.PropertyID = @propertyID
								AND ili.InvoiceID = i.InvoiceID) - 
							(SELECT SUM(ISNULL(ta.Amount, 0))
							 FROM [Transaction] ta
								LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
								INNER JOIN [Transaction] t ON t.TransactionID = ta.AppliesToTransactionID
								INNER JOIN InvoiceLineItem ili ON ili.TransactionID = t.TransactionID
								WHERE t.PropertyID = @propertyID
									AND ili.InvoiceID = i.InvoiceID
									AND tar.TransactionID IS NULL)))				
				THEN CAST(1 AS Bit)
				ELSE CAST(0 AS Bit)
				END AS 'PaidInFull'
		FROM Invoice i		
			INNER JOIN Vendor v ON i.VendorID = v.VendorID
			LEFT JOIN SummaryVendor sv ON i.SummaryVendorID = sv.SummaryVendorID			
			OUTER APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, @endDate) AS IVS
		WHERE 
		  -- There is a line item associated witht the properties passed in
		  ((SELECT COUNT(*) FROM InvoiceLineItem ili
				  INNER JOIN [Transaction] t ON t.TransactionID = ili.TransactionID
				  WHERE t.PropertyID = @propertyID
					AND ili.InvoiceID = i.InvoiceID) > 0)
		  AND (IVS.InvoiceStatus IS NULL OR IVS.InvoiceStatus NOT IN ('Void', 'Voided'))
		  -- Either they specify a BatchID and the InvoiceBatch entry for this invoice and batch exists
		  -- or the invoice was posted during the date range
		  AND (((@invoiceBatchID IS NOT NULL) AND (EXISTS (SELECT * FROM InvoiceBatch ib WHERE ib.BatchID = @invoiceBatchID AND ib.InvoiceID = i.InvoiceID)))
				OR
			   ((@startDate IS NOT NULL AND @endDate IS NOT NULL)
				  AND (((@invoiceFilterDate = 'AccountingDate' AND i.AccountingDate >= @startDate AND i.AccountingDate <= @endDate)) 
					OR ((@invoiceFilterDate = 'InvoiceDate' AND i.InvoiceDate >= @startDate AND i.InvoiceDate <= @endDate)) 
					OR ((@invoiceFilterDate = 'DueDate' AND i.DueDate >= @startDate AND i.DueDate <= @endDate))
					OR ((@invoiceFilterDate = 'ReceivedDate' AND i.ReceivedDate >= @startDate AND i.ReceivedDate <= @endDate)))))
			    
		ORDER BY 'Vendor', RIGHT('000000000000000000000000000000' + i.Number, 30), i.AccountingDate
    
END
GO
