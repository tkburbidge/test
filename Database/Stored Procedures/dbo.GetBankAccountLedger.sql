SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 15, 2012
-- Description:	Gets the Bank Account Ledger
-- =============================================
CREATE PROCEDURE [dbo].[GetBankAccountLedger] 
	-- Add the parameters for the stored procedure here
	@bankAccountID uniqueidentifier = null, 
	@startDate datetime = null,
	@endDate datetime = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	t.TransactionDate AS 'Date',
			t.TransactionID AS 'ID', 
			'Transaction' AS 'TransactionType',
			null AS 'Reference',
			CAST(0 AS bit) AS 'Void',
			t.[Description] AS 'Description',
			t.Amount AS 'Amount'
		FROM [Transaction] t
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN BankTransaction bt ON bt.ObjectID = t.TransactionID
		WHERE t.ObjectID = @bankAccountID
		  AND t.TransactionDate <= @endDate
		  AND t.TransactionDate >= @startDate
		  AND tt.[Group] = 'Bank'
		  AND tt.Name <> 'Check'
			
	UNION
	
	SELECT	py.Date AS 'Date',
			py.PaymentID AS 'ID',
			'Payment' AS 'TransactionType',
			bt.ReferenceNumber AS 'Reference',
			CASE 
				WHEN (py.Reversed = 1) THEN CAST(1 AS BIT)
				ELSE CAST(0 AS BIT)
				END AS 'Void',
			py.[Description] AS 'Description',
			py.Amount AS 'Amount'
		FROM Payment py
			INNER JOIN BankTransaction bt ON bt.ObjectID = py.PaymentID
			INNER JOIN PaymentTransaction pt ON pt.PaymentID = py.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
		WHERE t.ObjectID = @bankAccountID
		  AND py.Date >= @startDate
		  AND py.Date <= @endDate
		  AND tt.[Group] = 'Bank'
		  AND tt.Name = 'Check'
			
			
END
GO
