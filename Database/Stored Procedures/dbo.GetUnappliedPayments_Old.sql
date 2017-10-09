SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 14, 2012
-- Description:	Gets Unapplied Payments
-- =============================================
CREATE PROCEDURE [dbo].[GetUnappliedPayments_Old] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null, 
	@propertyID uniqueidentifier = null,
	@objectID uniqueidentifier = null,
	@ttGroup nvarchar(25),
	@postingBatchID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT  t.ObjectID AS 'ObjectID', t.TransactionID AS 'TransactionID', py.PaymentID AS 'PaymentID', tt.Name AS 'TTName', t.TransactionTypeID AS 'TransactionTypeID',
			t.Amount AS 'Amount', py.ReferenceNumber AS 'Reference', t.LedgerItemTypeID AS 'LedgerItemTypeID', t.[Description] AS 'Description',
			t.Origin AS 'Origin', py.[Date] AS 'PaymentDate', py.PostingBatchID AS 'PostingBatchID', CAST(0 AS bit) AS 'Allocated'
		FROM [Transaction] t
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Payment', 'Credit')
			INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
			INNER JOIN Payment py ON pt.PaymentID = py.PaymentID
			LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
			LEFT JOIN PostingBatch pb ON py.PostingBatchID = pb.PostingBatchID
		WHERE t.ObjectID = @objectID
		  AND t.AppliesToTransactionID IS NULL
		  AND t.ReversesTransactionID IS NULL
		  AND tr.TransactionID IS NULL
		  AND t.Amount > 0
		  AND (((@postingBatchID IS NULL) AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))) OR (((py.PostingBatchID = @postingBatchID) AND (pb.IsPosted = 1))))
		ORDER BY tt.Name, py.[Date]		

END
GO
