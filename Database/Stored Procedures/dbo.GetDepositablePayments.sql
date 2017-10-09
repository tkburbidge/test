SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 29, 2011
-- Description:	Gets all deposits associated with property that haven't been deposited.
-- =============================================
CREATE PROCEDURE [dbo].[GetDepositablePayments] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier,
	@includeBatchedPayments bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs 
		SELECT Value FROM @propertyIDs

	SELECT DISTINCT
		p.BatchID,
		p.PaymentID as [PaymentID],
		p.Date as [Date],
		p.Type as [Type],
		p.ReferenceNumber as [Reference],
		p.ReceivedFromPaidTo as [ReceivedFrom],
		p.Amount as [Amount], 
		p.Description as [Description], 
		ttp.Name as [TransactionType],
		p.TimeStamp,
		COALESCE(tp.PersonID, '22222222-2222-2222-2222-222222222222') AS 'PostingPersonID',
		per.PreferredName + ' ' + per.LastName AS 'PostingPersonName',
		tp.PropertyID,
		prop.Abbreviation AS 'PropertyAbbreviation',
		prop.Name AS 'PropertyName',
		tp.Origin AS 'Origin'		
	FROM Payment p 
		INNER JOIN PaymentTransaction pt on p.PaymentID = pt.PaymentID 
		INNER JOIN [Transaction] tp on pt.TransactionID = tp.TransactionID 
		INNER JOIN Property prop ON tp.PropertyID = prop.PropertyID
		INNER JOIN [TransactionType] ttp on tp.TransactionTypeID = ttp.TransactionTypeID AND ttp.Name in ('Payment', 'Deposit') 
																AND ttp.[Group]	in ('Lease', 'Non-Resident Account', 'Prospect', 'WOIT Account')
																AND ttp.AccountID = @accountID
		LEFT JOIN [Person] per ON tp.PersonID = per.PersonID

		LEFT JOIN PostingBatch pb ON pb.PostingBatchID = p.PostingBatchID
		LEFT JOIN PropertyAccountingPeriod pap ON prop.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID	
		INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = tp.PropertyID
	WHERE p.BatchID IS NULL 
		AND p.PaidOut = 0 
		--AND tp.PropertyID IN (SELECT Value FROM @propertyIDs)
		AND p.Reversed = 0     
		AND p.Amount > 0
		--AND tp.Origin <> 'X'
		AND ((@accountingPeriodID IS NULL) OR ((p.[Date] >= pap.StartDate) AND (p.[Date] <= pap.EndDate)))
		AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
		AND tp.TransactionID = (SELECT TOP 1 t2.TransactionID
								FROM [Transaction] t2
								INNER JOIN PaymentTransaction pt2 ON pt2.TransactionID = t2.TransactionID
								INNER JOIN TransactionType tt2 ON tt2.TransactionTypeID = t2.TransactionTypeID
								WHERE tt2.Name IN ('Payment', 'Deposit')
								AND pt2.PaymentID = p.PaymentID
								AND t2.ObjectID = tp.ObjectID
								ORDER BY t2.TimeStamp)




	UNION

	SELECT DISTINCT
		p.BatchID,
		p.PaymentID as [PaymentID],
		p.Date as [Date],
		p.Type as [Type],
		p.ReferenceNumber as [Reference],
		p.ReceivedFromPaidTo as [ReceivedFrom],
		p.Amount as [Amount], 
		p.Description as [Description], 
		ttp.Name as [TransactionType],
		p.TimeStamp,
		tp.PersonID AS 'PostingPersonID',
		b.[Description] AS 'PostingPersonName',
		tp.PropertyID,
		prop.Abbreviation AS 'PropertyAbbreviation',
		prop.Name AS 'PropertyName',
		tp.Origin AS 'Origin'		
	FROM Payment p 
		INNER JOIN PaymentTransaction pt on p.PaymentID = pt.PaymentID 
		INNER JOIN [Transaction] tp on pt.TransactionID = tp.TransactionID 
		INNER JOIN Property prop ON tp.PropertyID = prop.PropertyID
		INNER JOIN [TransactionType] ttp on tp.TransactionTypeID = ttp.TransactionTypeID AND ttp.Name in ('Payment', 'Deposit') 
																AND ttp.[Group]	in ('Lease', 'Non-Resident Account', 'Prospect', 'WOIT Account')
																AND ttp.AccountID = @accountID
		LEFT JOIN PostingBatch pb ON pb.PostingBatchID = p.PostingBatchID
		INNER JOIN Batch b ON p.BatchID = b.BatchID		
	WHERE @includeBatchedPayments = 1
		AND p.BatchID IS NOT NULL
		AND b.BankTransactionID IS NULL
		AND b.[Type] = 'Bank'
		AND b.isOpen = 0
		AND p.PaidOut = 0 
		AND p.Reversed = 0     
		AND (p.Amount > 0 OR (tp.Origin = 'H' AND p.Amount < 0))
		AND EXISTS (SELECT p2.PaymentID FROM Payment p2
					INNER JOIN PaymentTransaction pt2 ON pt2.PaymentID = p2.PaymentID
					INNER JOIN [Transaction] t2 on t2.TransactionID = pt2.TransactionID
					INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t2.PropertyID
					WHERE p2.BatchID = b.BatchID)
		AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
		AND tp.TransactionID = (SELECT TOP 1 t2.TransactionID
								FROM [Transaction] t2
								INNER JOIN PaymentTransaction pt2 ON pt2.TransactionID = t2.TransactionID
								INNER JOIN TransactionType tt2 ON tt2.TransactionTypeID = t2.TransactionTypeID
								WHERE tt2.Name IN ('Payment', 'Deposit')
								AND pt2.PaymentID = p.PaymentID
								AND t2.ObjectID = tp.ObjectID
								ORDER BY t2.TimeStamp)
	ORDER BY prop.Abbreviation, p.TimeStamp

	OPTION (RECOMPILE)
END
GO
