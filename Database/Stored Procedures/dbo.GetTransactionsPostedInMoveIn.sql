SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 30, 2012
-- Description:	Gets the Transaction posted as part of the MoveOut process which need to be reversed
-- =============================================
CREATE PROCEDURE [dbo].[GetTransactionsPostedInMoveIn] 
	-- Add the parameters for the stored procedure here
	@objectID uniqueidentifier = null,
	@unitID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SELECT	DISTINCT			
			CASE WHEN py.PaymentID IS NULL THEN t.TransactionID
			ELSE py.PaymentID
			END AS 'ID',
		    tt.Name AS 'TransactionType' 
	FROM [Transaction] t
		INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
		LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
		LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
		LEFT JOIN LedgerItemType trlit ON tr.LedgerItemTypeID = trlit.LedgerItemTypeID
		LEFT JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
		LEFT JOIN Payment py ON pt.PaymentID = py.PaymentID
		LEFT JOIN WOITAccount wa ON @objectID = wa.BillingAccountID
	WHERE t.Origin = 'I'
	  AND tr.TransactionID IS NULL
	  AND (t.ObjectID = @objectID OR t.ObjectID = wa.WOITAccountID)
	  AND t.Amount > 0
	  AND tt.Name IN ('Credit', 'Charge')

END
GO
