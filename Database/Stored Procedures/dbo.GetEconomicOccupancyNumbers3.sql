SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[GetEconomicOccupancyNumbers3]
	@accountID bigint,
	@startMonth nvarchar(20),
	@endMonth nvarchar(20),
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	DECLARE @startDate date = (SELECT StartDate FROM AccountingPeriod WHERE AccountID = @accountID AND Name = @startMonth)
	DECLARE @endDate date = (SELECT EndDate FROM AccountingPeriod WHERE AccountID = @accountID AND Name = @endMonth)
													
	DECLARE @glAccountIDs TABLE (
		GLAccountID uniqueidentifier,
		Statistic nvarchar(1)
	) 

	CREATE TABLE #EOPropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #EOPropertyIDs SELECT Value FROM @propertyIDs

	INSERT @glAccountIDs
		SELECT distinct lit.GLAccountID, 'G'
			FROM LedgerItemType lit	
			WHERE lit.AccountID = @accountID AND IsRent = 1
						
	INSERT @glAccountIDs 
		SELECT distinct lita.GLAccountID, 'C'
			FROM LedgerItemType lita				
				INNER JOIN LedgerItemType lit ON lita.AppliesToLedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1 AND lita.IsCredit = 1				
			WHERE lita.LedgerItemTypeID <> (SELECT LossToLeaseLedgerItemTypeID FROM Settings WHERE AccountID = @accountID)
				AND lita.AccountID = @accountID
				
	INSERT @glAccountIDs 
		SELECT distinct  lit.GLAccountID, 'L'
			FROM LedgerItemType lit
				INNER JOIN Settings s ON lit.LedgerItemTypeID = s.LossToLeaseLedgerItemTypeID AND s.AccountID = @accountID				

 SELECT Abbreviation AS 'Property',
		   ap.EndDate 'APEndDate', 
		   SUM(Amount) AS 'Amount', 
		   Statistic AS 'StatisticGroup'
	FROM (SELECT p.Abbreviation, t.TransactionDate, glid.Statistic, SUM(je.Amount) AS Amount
		  FROM JournalEntry je
		  INNER JOIN GLAccount gl on gl.GLAccountID = je.GLAccountID
		  INNER JOIN [Transaction] t on t.TransactionID = je.TransactionID
		  INNER JOIN Property p on p.PropertyID = t.PropertyID
		  INNER JOIN @glAccountIDs glid on glid.GLAccountID = je.GLAccountID
		  INNER JOIN #EOPropertyIDs ON #EOPropertyIDs.PropertyID = t.PropertyID
		   WHERE gl.AccountID = @accountID 
				 AND t.TransactionDate >= @startDate 
				 AND t.TransactionDate <= @endDate				 
				 --AND t.PropertyID IN (SELECT Value FROM @propertyIDs)
				 AND je.AccountingBasis = 'Accrual'
				 AND je.AccountingBookID IS NULL
		   GROUP BY p.Abbreviation, t.TransactionDate, glid.Statistic) GroupedTransactions
	INNER JOIN AccountingPeriod ap ON GroupedTransactions.TransactionDate >= ap.StartDate AND GroupedTransactions.TransactionDate <= ap.EndDate
	WHERE ap.AccountID = @accountID
	GROUP BY Abbreviation, EndDate, Statistic
	ORDER BY Property, APEndDate, StatisticGroup
END


GO
