SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO















-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 14, 2012
-- Description:	Gets Unapplied Payments
-- =============================================
CREATE PROCEDURE [dbo].[GetUnappliedPayments] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null, 
	@propertyID uniqueidentifier = null,
	@objectID uniqueidentifier = null,
	@ttGroup nvarchar(25),
	@postingBatchID uniqueidentifier = null,
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT  t.ObjectID AS 'ObjectID', t.TransactionID AS 'TransactionID', py.PaymentID AS 'PaymentID', tt.Name AS 'TTName', t.TransactionTypeID AS 'TransactionTypeID',
			t.Amount AS 'Amount', py.ReferenceNumber AS 'Reference', t.LedgerItemTypeID AS 'LedgerItemTypeID', t.[Description] AS 'Description',
			t.Origin AS 'Origin', py.[Date] AS 'PaymentDate', py.PostingBatchID AS 'PostingBatchID', CAST(0 AS bit) AS 'Allocated', 
			--lit.AppliesToLedgerItemTypeID AS 'AppliesToLedgerItemTypeID', 
			(SELECT TOP 1 LedgerItemTypeID FROM LedgerItemTypeApplication WHERE LedgerItemTypeID = lit.LedgerItemTypeID) AS 'AppliesToLedgerItemTypeID',
			lit.Abbreviation AS 'LedgerItemTypeAbbreviation', COALESCE(gl.Number, taxrateGL.Number) AS 'GLNumber',  COALESCE(gl.GLAccountID, taxrateGL.GLAccountID) AS 'GLAccountID',  py.TaxRateID
		FROM [Transaction] t
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Payment', 'Credit')
			INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
			INNER JOIN Payment py ON pt.PaymentID = py.PaymentID
			LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
			LEFT JOIN GLAccount gl ON gl.GLAccountID = lit.GLAccountID			
			LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
			LEFT JOIN PostingBatch pb ON py.PostingBatchID = pb.PostingBatchID
			LEFT JOIN TaxRate taxrate ON taxrate.TaxRateID = py.TaxRateID
			LEFT JOIN GLAccount taxrateGL ON taxrateGL.GLAccountID = taxrate.GLAccountID
			--LEFT JOIN LedgerItemTypeApplication lita ON lit.LedgerItemTypeID = lita.LedgerItemTypeID
		WHERE ((@objectID IS NULL) OR (t.ObjectID = @objectID))
		  AND t.AppliesToTransactionID IS NULL
		  AND t.ReversesTransactionID IS NULL
		  AND t.PropertyID = @propertyID
		  AND tr.TransactionID IS NULL
		  AND t.Amount > 0
		  AND (((@postingBatchID IS NULL) AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))) OR (((py.PostingBatchID = @postingBatchID) AND (pb.IsPosted = 1))))
		  AND ((@date IS NULL) 
			OR (@postingBatchID IS NOT NULL) -- If we are getting the unapplied payment for a posting batch, get it regardless of the date
		    OR (((lit.LedgerItemTypeID IS NULL) AND (t.TransactionDate <= @date)) OR ((lit.LedgerItemTypeID IS NOT NULL) AND (py.[Date] <= @date))))
		ORDER BY  

			lit.IsSalesTaxCredit desc,
			CASE WHEN ((SELECT COUNT(*) FROM LedgerItemTypeApplication WHERE LedgerItemTypeID = lit.LedgerItemTypeID) > 0) THEN 0
			ELSE 1 END,  -- Restricted LIT first
			tt.Name,			
			lit.OrderBy,
			py.[Date]		

END

GO
