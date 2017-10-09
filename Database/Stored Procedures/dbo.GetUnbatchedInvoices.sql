SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan 29, 2013
-- Description:	Gets Invoices that are not batched into a batch for that property
-- =============================================
CREATE PROCEDURE [dbo].[GetUnbatchedInvoices] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #InvoiceIDs (
		InvoiceID uniqueidentifier
	)

	-- Get all the invoices for the property during the period
	INSERT #InvoiceIDs
		SELECT DISTINCT 		
				i.InvoiceID AS 'InvoiceID'		
			FROM Invoice i			
				INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
				INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID AND  t.PropertyID = @propertyID
				CROSS APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, null)	 poinStatus		
			WHERE poinStatus.[InvoiceStatus] NOT IN ('Void')
			  AND i.AccountingDate >= @startDate
			  AND i.AccountingDate <= @endDate

	-- Delete the batched ones
	DELETE #InvoiceIDs 
		WHERE InvoiceID IN (SELECT InvoiceID
								FROM InvoiceBatch ib
									INNER JOIN Batch b ON ib.BatchID = b.BatchID
									INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
								WHERE pap.PropertyID = @propertyID)

	CREATE TABLE #UnbatchedInvoices (
		EnteringPersonID uniqueidentifier not null,
		EnteringPersonName nvarchar(200) not null,
		AccountingDate date not null,
		Credit bit not null,
		[Description] nvarchar(2000) null,
		DueDate date null,
		InvoiceID uniqueidentifier not null,
		InvoiceNumber nvarchar(100) not null,
		Total money null,
		Vendor nvarchar(200) null)
		
	INSERT #UnbatchedInvoices 
	SELECT distinct 
			per.PersonID AS 'EnteringPersonID',
			per.PreferredName + ' ' + per.LastName AS 'EnteringPersonName',
			i.AccountingDate AS 'AccountingDate',
			i.Credit AS 'Credit',
			i.[Description] AS 'Description',
			i.DueDate AS 'DueDate',
			i.InvoiceID AS 'InvoiceID',
			i.Number AS 'InvoiceNumber',
			(SELECT SUM(t.Amount)) AS 'Total',
			CASE 
				WHEN (i.SummaryVendorID IS NOT NULL) THEN sv.Name
				ELSE v.CompanyName END AS 'Vendor'
		FROM Invoice i
			INNER JOIN #InvoiceIDs #i ON #i.InvoiceID = i.InvoiceID
			INNER JOIN Vendor v ON i.VendorID = v.VendorID
			LEFT JOIN SummaryVendor sv ON v.VendorID = sv.SummaryVendorID
			INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
			INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
			INNER JOIN Property p ON t.PropertyID = p.PropertyID		
			INNER JOIN POInvoiceNote poinEntered ON i.InvoiceID = poinEntered.ObjectID AND poinEntered.POInvoiceNoteID = (SELECT TOP 1 POInvoiceNoteID
																										FROM POInvoiceNote
																										WHERE ObjectID = i.InvoiceID
																										ORDER BY [Timestamp])																										
			INNER JOIN Person per ON poinEntered.PersonID = per.PersonID			
		WHERE t.PropertyID = @propertyID		
		GROUP BY i.InvoiceID, per.PersonID, per.PreferredName, per.LastName, i.AccountingDate, i.Credit, i.[Description], i.DueDate, 
				 i.Number, v.CompanyName, sv.Name, i.SummaryVendorID, t.propertyID
		ORDER BY 'Vendor', i.AccountingDate
									
		SELECT * FROM #UnbatchedInvoices
END




GO
