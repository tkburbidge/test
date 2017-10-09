SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetTransactionsReversedInMoveOut] 
	-- Add the parameters for the stored procedure here
	@objectID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	SELECT	DISTINCT t.TransactionTypeID, tt.Name, tt.[Group] AS 'Group', t.TransactionDate, t.LedgerItemTypeID, t.Origin,
			t.Amount, t.[Description], null AS 'PaymentID', tt.GLAccountID AS 'TTGLAccountID',
			lit.GLAccountID AS 'LITGLAccountID', null AS 'ReceivedFromPaidTo'	
		FROM [Transaction] t
			INNER JOIN [TransactionGroup] tg ON t.TransactionID = tg.TransactionID AND tg.TransactionGroupID = @objectID
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
			LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID			

	UNION
	
	SELECT	DISTINCT t.TransactionTypeID, tt.Name, tt.[Group] AS 'Group', py.[Date], t.LedgerItemTypeID, t.Origin,
			py.Amount, py.[Description], py.PaymentID AS 'PaymentID', tt.GLAccountID AS 'TTGLAccountID',
			lit.GLAccountID AS 'LITGLAccountID', py.ReceivedFromPaidTo	
		FROM Payment py
			INNER JOIN TransactionGroup tg ON py.PaymentID = tg.TransactionID AND tg.TransactionGroupID = @objectID
			INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
			LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID			
		WHERE tt.Name = 'Credit'
			
	DELETE TransactionGroup WHERE TransactionGroupID = @objectID
	
END
GO
