SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[AreInvoicesReadyForApproval] 	
	@accountID bigint,
	@invoiceIDs GuidCollection readonly
AS
BEGIN
	SELECT DISTINCT p.Abbreviation, i.InvoiceID, i.Number, i.[Description], i.Total, i.AccountingDate
	FROM Invoice i
	INNER JOIN InvoiceLineItem ili ON ili.InvoiceID = i.InvoiceID
	INNER JOIN [Transaction] t ON t.TransactionID = ili.TransactionID
	INNER JOIN Property p ON p.PropertyID = t.PropertyID AND p.InvoiceRequiresBatchBeforeApproval = 1
	LEFT JOIN InvoiceBatch ib ON ib.InvoiceID = i.InvoiceID 
								 AND ib.BatchID = (SELECT TOP 1 b.BatchID
												   FROM Batch b
													INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyAccountingPeriodID = b.PropertyAccountingPeriodID
																								AND pap.PropertyID = t.PropertyID
												   WHERE b.BatchID = ib.BatchID)												
	LEFT JOIN POInvoiceNote poin ON poin.ObjectID = i.InvoiceID												   
	WHERE i.InvoiceID IN (SELECT Value FROM @invoiceIDs)	
	AND poin.POInvoiceNoteID = (SELECT TOP 1 POInvoiceNoteID
								FROM POInvoiceNote
								WHERE ObjectID = i.InvoiceID
								ORDER BY POInvoiceNote.[Timestamp] DESC)
	AND ib.BatchID IS NULL 
	AND poin.[Status] IN ('Pending Approval')
END
GO
