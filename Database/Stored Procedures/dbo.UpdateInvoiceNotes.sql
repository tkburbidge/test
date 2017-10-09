SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO








-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 5, 2013
-- Description:	Gets the total amount due on an invoice and the total already paid.
-- =============================================
CREATE PROCEDURE [dbo].[UpdateInvoiceNotes] 
	-- Add the parameters for the stored procedure here
	@invoiceIDs GuidCollection READONLY,
	@personID uniqueidentifier = null,
	@date DATE = null,
	@voided bit = 0,
	@integrationPartnerID int = null
AS

DECLARE @invoiceTotal money
DECLARE @alreadyPaid money

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #NewInvoiceStatus (
		InvoiceID uniqueidentifier	not null,
		AccountID bigint not null,
		Credit bit not null,
		Total money null,
		AmountPaid money null,
		AmountReversed money null,
		NetPaid money null,
		--InvStatus nvarchar(50) null
		)
		
	INSERT #NewInvoiceStatus 
						SELECT	i.InvoiceID, i.AccountID, i.Credit, i.Total, ISNULL(SUM(ta.Amount), 0), ISNULL(SUM(tar.Amount), 0), 0--,
								--[InvStat].InvoiceStatus AS 'InvStatus'
							FROM Invoice i
								INNER JOIN InvoiceLineItem ili ON i.InvoiceID = ili.InvoiceID
								INNER JOIN [Transaction] t ON ili.TransactionID = t.TransactionID
								--CROSS APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, @date) AS [InvStat]
								LEFT JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
								LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
							WHERE i.InvoiceID IN (SELECT Value FROM @invoiceIDs)
							  --AND tar.TransactionID IS NULL
							  AND i.Credit = 0
							GROUP BY i.InvoiceID, i.AccountID, i.Credit, i.Total--, [InvStat].InvoiceStatus
							
	INSERT #NewInvoiceStatus 
						SELECT i.InvoiceID, i.AccountID, i.Credit, i.Total, ISNULL(SUM(ta.Amount), 0), ISNULL(SUM(tar.Amount), 0), 0--,
								--[InvStat].InvoiceStatus AS 'InvStatus'
							FROM Invoice i
								INNER JOIN [Transaction] t ON i.InvoiceID = t.ObjectID
								--CROSS APPLY GetInvoiceStatusByInvoiceID(i.InvoiceID, @date) AS [InvStat]
								LEFT JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
								LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
							WHERE i.InvoiceID IN (SELECT Value FROM @invoiceIDs)
							  --AND tar.TransactionID IS NULL
							  AND i.Credit = 1
							GROUP BY i.InvoiceID, i.AccountID, i.Credit, i.Total--, [InvStat].InvoiceStatus
							
	UPDATE #NewInvoiceStatus SET NetPaid = (ISNULL(AmountPaid, 0) + ISNULL(AmountReversed, 0)) 	--  PLUS AmountReversed since it's a negative number
    	
	INSERT POInvoiceNote 
		SELECT NEWID(), AccountID, InvoiceID, @personID, NULL, NULL, @date, 'Paid', NULL, GETUTCDATE(), @integrationPartnerID
			FROM #NewInvoiceStatus			
			WHERE NetPaid = Total  -- Paid amount = invoice total			  
			  AND Credit = 0
			  AND @voided = 0
			  
			  --AND ISNULL(AmountReversed, 0) = 0
			  --AND InvStatus <> 'Paid'
			
	INSERT POInvoiceNote 
		SELECT NEWID(), AccountID, InvoiceID, @personID, NULL, NULL, @date, 'Partially Paid', NULL, GETUTCDATE(), @integrationPartnerID
			FROM #NewInvoiceStatus
			WHERE NetPaid > 0			-- Something has been paid
			  AND NetPaid <> Total		-- But not the entire invoice			  
			  AND Credit = 0
			  AND @voided = 0
			  
			  --AND Total <> ISNULL(AmountPaid, 0)
			  --AND ISNULL(AmountPaid, 0) <> 0
			  --AND InvStatus <> 'Partially Paid'
			
	INSERT POInvoiceNote 
		SELECT NEWID(), AccountID, InvoiceID, @personID, NULL, NULL, @date, 'Partially Paid-R', NULL, GETUTCDATE(), @integrationPartnerID
			FROM #NewInvoiceStatus
			WHERE ISNULL(AmountReversed, 0) <> 0
			  AND NetPaid > 0			-- Something has been paid
			  AND NetPaid <> Total		-- But not the entire invoice
			  AND Credit = 0	
			  AND @voided = 1	
			  
			  --AND (Total - ISNULL(AmountPaid, 0) - ISNULL(AmountReversed, 0)) <> 0			--  MINUS AmountReversed since it's a negative number
			  --AND ((-1 * AmountReversed) <> Total)
			  --AND ISNULL(AmountPaid, 0) <> 0
			  --AND InvStatus <> 'Partially Paid-R'	  
			  
	INSERT POInvoiceNote 
		SELECT NEWID(), AccountID, InvoiceID, @personID, NULL, NULL, @date, 'Approved-R', NULL, GETUTCDATE(), @integrationPartnerID
			FROM #NewInvoiceStatus
			WHERE  ISNULL(AmountReversed, 0) <> 0		-- A payment has been reversed			  
			  AND NetPaid = 0							-- And nothing has been paid
			  AND Credit = 0
			  AND @voided = 1
			  
			  --AND ((-1 * AmountReversed) = Total)
			  --AND InvStatus <> 'Approved-R'	  			  
			  
	INSERT POInvoiceNote
		SELECT NEWID(), AccountID, InvoiceID, @personID, NULL, NULL, @date, 'Applied', NULL, GETUTCDATE(), @integrationPartnerID
			FROM #NewInvoiceStatus
			WHERE Credit = 1
			  AND NetPaid = Total			-- Entire amount has been applied
			  
			  --AND InvStatus <> 'Applied'
			  
	INSERT POInvoiceNote 
		SELECT NEWID(), AccountID, InvoiceID, @personID, NULL, NULL, @date, 'Partially Applied', NULL, GETUTCDATE(), @integrationPartnerID
			FROM #NewInvoiceStatus
			WHERE Credit = 1
			  --AND Total - ISNULL(AmountPaid, 0) <> 0
			  AND NetPaid > 0				-- Something has been applied
			  AND NetPaid <> Total			-- But not the entire amount
			  
			  --AND Total <> ISNULL(AmountPaid, 0)
			  --AND ISNULL(AmountPaid, 0) <> 0	
			  --AND InvStatus <> 'Partially Applied'	  
			  
	INSERT POInvoiceNote
		SELECT NEWID(), AccountID, InvoiceID, @personID, NULL, NULL, @date, 'Approved-R', NULL, GETUTCDATE(), @integrationPartnerID
			FROM #NewInvoiceStatus
			WHERE Credit = 1
			  AND NetPaid = 0
			  AND Total <> 0
END


GO
