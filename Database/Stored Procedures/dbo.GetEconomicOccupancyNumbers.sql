SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[GetEconomicOccupancyNumbers]
	@accountID bigint,
	@startMonth nvarchar(20),
	@endMonth nvarchar(20),
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	

	CREATE TABLE #EOPropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #EOPropertyIDs SELECT Value FROM @propertyIDs
	
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier null,
		StartDate date null,
		EndDate date null)
		
	INSERT #PropertiesAndDates
		SELECT #eop.PropertyID, Spap.StartDate, Epap.EndDate
			FROM #EOPropertyIDs #eop
				INNER JOIN PropertyAccountingPeriod Spap ON #eop.PropertyID = Spap.PropertyID 
				INNER JOIN AccountingPeriod Sap ON Spap.AccountingPeriodID = Sap.AccountingPeriodID AND Sap.Name = @startMonth
				INNER JOIN PropertyAccountingPeriod Epap ON #eop.PropertyID = Epap.PropertyID
				INNER JOIN AccountingPeriod Eap ON Epap.AccountingPeriodID = Eap.AccountingPeriodID AND Eap.Name = @endMonth
			WHERE Spap.AccountID = @accountID
				AND Sap.AccountID = @accountID
				AND Epap.AccountID = @accountID
				AND Eap.AccountID = @accountID
			
		

	SELECT Abbreviation AS 'Property',
				-- Using APEndDate here because we need to get a common date as we show this by month on the front end
				ap.EndDate AS 'APEndDate',
			   SUM(Amount) AS 'Amount', 
			   Statistic AS 'StatisticGroup'
		FROM (SELECT p.PropertyID, p.Abbreviation, t.TransactionDate, gl.Statistic, SUM(je.Amount) AS Amount
			  FROM JournalEntry je
			  INNER JOIN GLAccount gl on gl.GLAccountID = je.GLAccountID
			  INNER JOIN [Transaction] t on t.TransactionID = je.TransactionID
			  INNER JOIN Property p on p.PropertyID = t.PropertyID	 
			  INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
			   WHERE gl.AccountID = @accountID 
					 AND t.TransactionDate >= #pad.StartDate
					 AND t.TransactionDate <= #pad.EndDate
					 AND je.AccountingBasis = 'Accrual'
					 AND je.AccountingBookID IS NULL
					 AND gl.Statistic IN ('C', 'G', 'L')
					 AND t.Origin NOT IN ('Y', 'E')
			   GROUP BY p.PropertyID, p.Abbreviation, t.TransactionDate, gl.Statistic) GroupedTransactions	
		INNER JOIN #PropertiesAndDates #pad2 ON GroupedTransactions.PropertyID = #pad2.PropertyID AND GroupedTransactions.TransactionDate >= #pad2.StartDate AND GroupedTransactions.TransactionDate <= #pad2.EndDate	
		INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyID = #pad2.PropertyID AND pap.StartDate <= GroupedTransactions.TransactionDate AND pap.EndDate >= GroupedTransactions.TransactionDate
		INNER JOIN AccountingPeriod ap on ap.AccountingPeriodID = pap.AccountingPeriodID
		GROUP BY Abbreviation, ap.EndDate, Statistic
		ORDER BY Property, APEndDate, StatisticGroup
END





GO
