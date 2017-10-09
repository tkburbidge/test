SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[GetObjectBalance] 
(	
	-- Add the parameters for the function here
	@startDate datetime, 
	@endDate datetime,
	@objectID uniqueidentifier,
	@lateFee bit,
	@propertyIDs GuidCollection READONLY
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT @objectID AS 'ObjectID', 
	 ISNULL(((SELECT ISNULL(SUM(ISNULL((CASE WHEN tt.Name IN ('Charge', 'Tax Charge') THEN t.Amount ELSE -t.Amount END), 0)), 0)
		FROM [Transaction] t
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID	
			LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID		
		WHERE
		  ((tt.Name IN ('Charge', 'Tax Charge', 'Deposit Applied to Balance', 'Balance Transfer Payment', 'Payment Refund'))
			OR ((tt.Name IN ('Prepayment', 'Over Credit', 'Payment', 'Credit') AND t.Origin = 'T')))
		  AND t.ObjectID = @objectID
		  AND ((@lateFee = 0) OR (lit.IsLateFeeAssessable = 1))
		  AND ((@startDate IS NULL) OR (t.TransactionDate >= @startDate))
		  AND t.TransactionDate <= @endDate
		  AND ((t.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
		  AND t.PropertyID IN (SELECT Value FROM @propertyIDs)) -
		((SELECT ISNULL(SUM(DistinctPayments.Amount), 0)
		  FROM		 
		 ((SELECT distinct p.PaymentID, p.Amount
		  FROM Payment p
			INNER JOIN [PaymentTransaction] pt ON pt.PaymentID = p.PaymentID
			INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
			INNER JOIN TransactionType tt ON tt.TransactionTypeID = t.TransactionTypeID	
			INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
			LEFT JOIN PostingBatch pb ON p.PostingBatchID = pb.PostingBatchID		
		  WHERE  ((tt.Name IN ('Payment', 'Credit')) AND (t.ObjectID = p.ObjectID))
			--AND ((@lateFee = 0) OR (lit.IsLateFeeAssessable = 1))
		    AND t.LedgerItemTypeID IS NOT NULL
		    AND t.ObjectID = @objectID
		    --AND t.ObjectID = p.ObjectID
		    AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))	   
		    AND t.PropertyID IN (SELECT Value FROM @propertyIDs)
		    AND ((@startDate IS NULL) OR (p.[Date] >= @startDate))		    
		    AND p.[Date] <= @endDate
		    ) UNION
		    ((SELECT distinct t.TransactionID, t.Amount
				FROM [Transaction] t
				  INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				WHERE 
				  tt.Name IN ('Tax Credit')
				  AND t.ObjectID = @objectID
				  AND t.PropertyID IN (SELECT Value FROM @propertyIDs)
				  AND ((@startDate IS NULL) OR (t.TransactionDate >= @startDate))
			      AND t.TransactionDate <= @endDate)))				  
		     DistinctPayments))), 0) AS 'Balance'		
)
GO
