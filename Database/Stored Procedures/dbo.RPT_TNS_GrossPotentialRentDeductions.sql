SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Nick Olsen
-- Create date: August 11, 2012
-- Description:	Gets the data for the GPR deductions report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_GrossPotentialRentDeductions] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection readonly,
	@accountingPeriodID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @lossToLeaseLedgerItemTypeID uniqueidentifier	
	DECLARE @gainToLeaseLedgerItemTypeID uniqueidentifier	

	SELECT @lossToLeaseLedgerItemTypeID = LossToLeaseLedgerItemTypeID, @gainToLeaseLedgerItemTypeID = GainToLeaseLedgerItemTypeID FROM Settings WHERE AccountID = @accountID
	
	CREATE TABLE #PropertiesAndDates (
		Sequence int identity not null,
		PropertyID uniqueidentifier not null,
		StartDate date not null,
		EndDate date not null)
	
	INSERT #PropertiesAndDates SELECT pIDs.Value, pap.StartDate, pap.EndDate
		FROM @propertyIDs pIDs
			INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			
			
	-- Get credits that were applied to rent											
	SELECT p.Name AS 'PropertyName', gl.GLAccountID, gl.Number AS 'GLNumber', gl.Name AS 'GLName', SUM(t.Amount) AS 'Amount'
	FROM [Transaction] t
	-- Join in applied to rent transactions
	INNER JOIN [Transaction] ta ON t.AppliesToTransactionID = ta.TransactionID
	--INNER JOIN JournalEntry je ON t.TransactionID = je.TransactionID	
	INNER JOIN Property p on p.PropertyID = t.PropertyID
	LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
	INNER JOIN GLAccount gl ON gl.GLAccountID = lit.GLAccountID
	INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
	LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
	LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID																						
	INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = t.PropertyID
	WHERE 
		-- Transaction is in the given month
		 t.TransactionDate >= #pad.StartDate--@startDate
		AND t.TransactionDate <= #pad.EndDate--@endDate
		-- Applied to a transaction in the given month
		AND ta.TransactionDate >= #pad.StartDate--@startDate
		AND ta.TransactionDate <= #pad.EndDate--@endDate
		-- Credit transaction
		AND (lit.IsCredit = 1 OR lit.LedgerItemTypeID IS NULL)
		-- Applied to rent
		AND (alit.IsRent = 1 OR alit.LedgerItemTypeID = @gainToLeaseLedgerItemTypeID)
		-- Transaction isn't reversed								
		AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
		AND t.ReversesTransactionID IS NULL
		AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
	GROUP BY p.Name, gl.GLAccountID, gl.Number, gl.Name	
END	

GO
