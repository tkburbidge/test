SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 13, 2011
-- Description:	Gets Invoice Detail Information to the LineItem detail.
-- =============================================
CREATE PROCEDURE [dbo].[GetInvoiceLineItemsForPayment] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection readonly,
	@vendorID uniqueidentifier = null,
	@invoiceIDs GuidCollection readonly
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PaymentDetails (
		InvoiceID			uniqueidentifier		not null,
		InvoiceLineItemID	uniqueidentifier		not null,
		Credit				bit						not null,
		Total				money					not null,
		AmountPaid			money					not null,
		UnpaidAmount		money					not null,
		TransactionID		uniqueidentifier		not null,
		InvoiceNumber		nvarchar(200)			not null,
		PropertyID			uniqueidentifier		not null,
		PropertyName		nvarchar(50)			not null
		)	

	INSERT #PaymentDetails
		SELECT DISTINCT ilt.InvoiceID, ilt.InvoiceLineItemID, i.Credit, t.Amount, 0.0, 0.0, t.TransactionID, i.Number, t.PropertyID, p.Name
			FROM Invoice i
				INNER JOIN InvoiceLineItem ilt on i.InvoiceID = ilt.InvoiceID
				INNER JOIN POInvoiceNote poin on poin.ObjectID = i.InvoiceID
				INNER JOIN [Transaction] t on ilt.TransactionID = t.TransactionID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
			WHERE (i.InvoiceID IN (SELECT Value FROM @invoiceIDs))
			  AND i.VendorID = @vendorID
			  AND t.PropertyID IN (SELECT Value FROM @propertyIDs)
			  AND ((select top 1 POInvoiceNote.[Status] from POInvoiceNote where ObjectID = i.InvoiceID order by [Timestamp] desc) 
						in ('Approved', 'Approved-R', 'Partially Paid', 'Partially Paid-R', 'Unapplied', 'Partially Applied'))

	UPDATE #PaymentDetails SET AmountPaid = ISNULL((SELECT SUM(ta.Amount) 
											  FROM [Transaction] t2
											  INNER JOIN [Transaction] ta ON ta.AppliesToTransactionID = t2.TransactionID
											  LEFT JOIN [Transaction] tra ON tra.ReversesTransactionID = ta.TransactionID
											  WHERE t2.TransactionID = #PaymentDetails.TransactionID
	  												AND tra.TransactionID IS NULL), 0)
	  												
	  												
	--UPDATE #PaymentDetails SET AmountPaid = ISNULL((SELECT AmountPaid 
	--												FROM (SELECT SUM(t1.Amount) AmountPaid
	--													  FROM [Transaction] t1
	--													  WHERE t1.AppliesToTransactionID = #PaymentDetails.TransactionID) AmountPaids), 0)
	--	FROM [Transaction] t1
	--	WHERE t1.AppliesToTransactionID = #PaymentDetails.TransactionID
	---- Exclude reversed payments
	--	  AND NOT EXISTS (SELECT * 
	--					  FROM [Transaction] t3
	--					  WHERE t3.ReversesTransactionID = t1.TransactionID) 
	--UPDATE #PaymentDetails SET AmountPaid = ISNULL((SELECT SUM(ISNULL(t2.Amount, 0.0)) 
	--											FROM #PaymentDetails #pd
	--												INNER JOIN [Transaction] t2 on #pd.TransactionID = t2.AppliesToTransactionID
	--											GROUP BY t2.TransactionID), 0.0)
												
	UPDATE #PaymentDetails SET UnpaidAmount = Total - AmountPaid
												
	SELECT * FROM #PaymentDetails
	WHERE ISNULL(UnpaidAmount, 0) <> 0

END







GO
