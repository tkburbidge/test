SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 21, 2012
-- Description:	Generates the data for the Income Statement
-- =============================================
CREATE PROCEDURE [dbo].[RPT_ACTG_IncomeStatementTotals] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@reportName nvarchar(50) = null,
	@accountingBasis nvarchar(10) = null,
	@reportDate datetime = null,
	@byPropertyID bit = 0,
	@alternateChartOfAccountsID uniqueidentifier = null,
	@accountingBookIDs GuidCollection READONLY,
	@alternateBudgetIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null
AS
--DECLARE @accountingPeriodID uniqueidentifier
DECLARE @fiscalYearBegin tinyint
DECLARE @fiscalYearStartDate datetime
DECLARE @lastFiscalYearStartDate datetime
DECLARE @lastFiscalYearEndDate datetime
DECLARE @accountID bigint
DECLARE @glAccountTypes StringCollection

BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #NetIncomeTotals (	
		PropertyID uniqueidentifier NULL,	
		GLAccountID uniqueidentifier NOT NULL,
		Number nvarchar(15) NOT NULL,
		Name nvarchar(200) NOT NULL, 
		[Description] nvarchar(500) NULL,
		GLAccountType nvarchar(50) NOT NULL,
		ParentGLAccountID uniqueidentifier NULL,
		Depth int NOT NULL,
		IsLeaf bit NOT NULL,
		SummaryParent bit NOT NULL,
		[OrderByPath] nvarchar(max) NOT NULL,
		[Path]  nvarchar(max) NOT NULL,
		SummaryParentPath nvarchar(max) NOT NULL,
		CurrentAPAmount money null,
		CurrentAPAmountOtherBooks money null,
		YTDAmount money null,
		LastYearAmount money null,
		CurrentAPBudget money null,
		YTDBudget money null)
		
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		AccountingPeriodID uniqueidentifier NOT NULL,
		StartDate [Date] NOT NULL,
		EndDate [Date] NOT NULL,
		FiscalYearStartDate [Date] NULL,
		CashAlternateBudgetID uniqueidentifier NULL,
		AccrualAlternateBudgetID uniqueidentifier NULL)
		

	CREATE TABLE #AccountingBookIDs (
		AccountingBookID uniqueidentifier NOT NULL)

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))
		
	--SELECT @accountingPeriodID = AccountingPeriodID,
	--	   @accountID = AccountID
	--	FROM AccountingPeriod 
	--	WHERE StartDate <= @reportDate
	--	  AND EndDate >= @reportDate
	--	  AND AccountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))
	
	INSERT #PropertiesAndDates 
		SELECT DISTINCT pids.Value, pap.AccountingPeriodID, pap.StartDate, pap.EndDate, null, null, null
			FROM @propertyIDs pids
				LEFT JOIN PropertyAccountingPeriod pap ON pids.Value = pap.PropertyID 
				LEFT JOIN PropertyAccountingPeriod papAP ON pids.Value = papAP.PropertyID
			WHERE (((@accountingPeriodID IS NULL) AND (pap.StartDate <= @reportDate AND pap.EndDate >= @reportDate AND pap.AccountID = @accountID))
			   OR  ((@accountingPeriodID IS NOT NULL) AND (papAP.AccountingPeriodID = @accountingPeriodID AND pap.AccountingPeriodID = @accountingPeriodID)))

	UPDATE #PropertiesAndDates SET FiscalYearStartDate = (SELECT dbo.GetFiscalYearStartDate(@accountID, #PropertiesAndDates.AccountingPeriodID, #PropertiesAndDates.PropertyID))

	UPDATE #PropertiesAndDates SET CashAlternateBudgetID = (SELECT YearBudgetID
														FROM YearBudget
														WHERE PropertyID = #PropertiesAndDates.PropertyID
														  AND AccountingBasis = 'Cash'
														  AND @accountingBasis = 'Cash'
														  AND YearBudgetID IN (SELECT Value FROM @alternateBudgetIDs))

	UPDATE #PropertiesAndDates SET AccrualAlternateBudgetID = (SELECT YearBudgetID
														   FROM YearBudget
														   WHERE PropertyID = #PropertiesAndDates.PropertyID
														     AND AccountingBasis = 'Accrual'
															 AND @accountingBasis = 'Accrual'
														     AND YearBudgetID IN (SELECT Value FROM @alternateBudgetIDs))

	INSERT #AccountingBookIDs
		SELECT Value
			FROM @accountingBookIDs

	INSERT @glAccountTypes VALUES ('Income')
	INSERT @glAccountTypes VALUES ('Expense')
	INSERT @glAccountTypes VALUES ('Other Income')				
	INSERT @glAccountTypes VALUES ('Other Expense')
	INSERT @glAccountTypes VALUES ('Non-Operating Expense')				



	IF (@alternateChartOfAccountsID IS NULL)
	BEGIN			
		INSERT #NetIncomeTotals SELECT 
							#p.PropertyID,
							GLAccountID,
							Number,
							Name,
							[Description],
							GLAccountType,
							ParentGLAccountID,
							Depth,
							IsLeaf,
							SummaryParent,
							OrderByPath,
							[Path],
							SummaryParentPath,
							0,
							0,
							0,
							0,
							0,
							0
						FROM GetChartOfAccounts(@accountID, @glAccountTypes)	
							LEFT JOIN #PropertiesAndDates #p ON @byPropertyID = 1		  		  	

	END	  
	ELSE
	BEGIN
		INSERT #NetIncomeTotals SELECT 
							#p.PropertyID,
							GLAccountID,
							Number,
							Name,
							[Description],
							GLAccountType,
							ParentGLAccountID,
							Depth,
							IsLeaf,
							SummaryParent,
							OrderByPath,
							[Path],
							SummaryParentPath,
							0,
							0,
							0,
							0,
							0,
							0
							FROM GetChartOfAccountsByAlternate(@accountID, @glAccountTypes, @alternateChartOfAccountsID)		
								LEFT JOIN #PropertiesAndDates #p ON @byPropertyID = 1
	END
	
	-- If we are running on default books
	IF ('55555555-5555-5555-5555-555555555555' IN (SELECT Value FROM @accountingBookIDs))
	BEGIN		
		UPDATE #NetIncomeTotals SET CurrentAPAmount = ISNULL((SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
														INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
														--INNER JOIN #Properties p ON p.PropertyID = t.PropertyID
													WHERE t.TransactionDate >= #pad.StartDate
													  AND t.TransactionDate <= #pad.EndDate
													  --AND t.TransactionDate <= @reportDate
													  -- Don't include closing the year entries
													  AND t.Origin NOT IN ('Y', 'E')
													  AND je.GLAccountID = #NetIncomeTotals.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND je.AccountingBookID IS NULL
													  AND ((@byPropertyID = 0) OR ((@byPropertyID = 1) AND (t.PropertyID = #NetIncomeTotals.PropertyID)))
													  ), 0)
		OPTION (RECOMPILE)
	END

	-- Consider other Accounting Books																						  
	IF ((SELECT COUNT(*) FROM @accountingBookIDs WHERE Value <> '55555555-5555-5555-5555-555555555555') > 0)
	BEGIN
		UPDATE #NetIncomeTotals SET CurrentAPAmountOtherBooks = ISNULL((SELECT SUM(je.Amount)
																			FROM JournalEntry je
																				INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																				--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
																				INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
																				--INNER JOIN #Properties p ON p.PropertyID = t.PropertyID
																				INNER JOIN #AccountingBookIDs #abIDs ON je.AccountingBookID = #abIDs.AccountingBookID
																			WHERE t.TransactionDate >= #pad.StartDate
																			  AND t.TransactionDate <= #pad.EndDate
																			  --AND t.TransactionDate <= @reportDate
																			  -- Don't include closing the year entries
																			  AND t.Origin NOT IN ('Y', 'E')
																			  AND je.GLAccountID = #NetIncomeTotals.GLAccountID
																			  AND je.AccountingBasis = @accountingBasis
																			  AND ((@byPropertyID = 0) OR ((@byPropertyID = 1) AND (t.PropertyID = #NetIncomeTotals.PropertyID)))
																			  ), 0)
		OPTION (RECOMPILE)
	END

	IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
	BEGIN
		UPDATE #NetIncomeTotals SET CurrentAPBudget = (SELECT CASE
														WHEN (@accountingBasis = 'Accrual') THEN SUM(b.AccrualBudget)
														WHEN (@accountingBasis = 'Cash') THEN SUM(b.CashBudget)
														END 
													FROM Budget b
													WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																								FROM PropertyAccountingPeriod pap
																								--INNER JOIN #Properties p ON p.PropertyID = pap.PropertyID
																									INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
																								WHERE 
																								  pap.AccountingPeriodID = #pad.AccountingPeriodID  --@accountingPeriodID
																								  AND ((@byPropertyID = 0) OR ((@byPropertyID = 1) AND (pap.PropertyID = #NetIncomeTotals.PropertyID))))
													  AND b.GLAccountID = #NetIncomeTotals.GLAccountID)
		OPTION (RECOMPILE)
	
		/*
		SELECT @fiscalYearBegin = ISNULL(s.FiscalYearStartMonth, 1), @accountID = ap.AccountID 
			FROM Settings s		
				INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID AND ap.AccountID = s.AccountID
			
		SET @fiscalYearStartDate = (SELECT dbo.GetFiscalYearStartDate(@accountID, @accountingPeriodID, (SELECT TOP 1 PropertyID FROM #Properties)))													  	
				
		SET @lastFiscalYearEndDate = DATEADD(day, -1, @fiscalYearStartDate)
		SET @lastFiscalYearStartDate = DATEADD(YEAR, -1, @fiscalYearStartDate)

		SET @lastFiscalYearStartDate = ISNULL((SELECT StartDate 
											  FROM AccountingPeriod
											  WHERE AccountID = @accountID 
													AND DATEPART(month, EndDate) = @fiscalYearBegin
													AND DATEPART(year, @lastFiscalYearEndDate) = DATEPART(year, EndDate))
						
		, @lastFiscalYearStartDate)	
		*/
	
		UPDATE #NetIncomeTotals SET YTDBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											FROM Budget b
											WHERE b.GLAccountID = #NetIncomeTotals.GLAccountID
											  AND b.PropertyAccountingPeriodID IN (SELECT DISTINCT pap.PropertyAccountingPeriodID
																						FROM PropertyAccountingPeriod pap
																						INNER JOIN #PropertiesAndDates p ON p.PropertyID = pap.PropertyID
																						WHERE
																						 ((@byPropertyID = 0) OR ((@byPropertyID = 1) AND (pap.PropertyID = #NetIncomeTotals.PropertyID)))
		--																				 AND pap.AccountingPeriodID IN (SELECT AccountingPeriodID 
		--																													FROM AccountingPeriod
		--																													WHERE AccountID = @accountID








		--																													  AND StartDate >= p.FiscalYearStartDate
		--																													  AND EndDate <= p.EndDate)))
		--OPTION (RECOMPILE)
																						  AND pap.PropertyAccountingPeriodID IN (SELECT PropertyAccountingPeriodID
																																	FROM PropertyAccountingPeriod 
																																	WHERE AccountID  = @accountID
																																	  AND PropertyID = p.PropertyID
																																	  AND StartDate >= p.FiscalYearStartDate
																																	  AND EndDate <= p.EndDate)))
		OPTION (RECOMPILE)
	END
	ELSE			-- We have an AlternateBudget Situation Here!
	BEGIN
		UPDATE #NetIncomeTotals SET CurrentAPBudget = (SELECT SUM(ab.Amount)
														    FROM AlternateBudget ab
															WHERE ab.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																									   FROM PropertyAccountingPeriod pap
																										   INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
																														AND (ab.YearBudgetID = #pad.AccrualAlternateBudgetID OR ab.YearBudgetID = #pad.CashAlternateBudgetID)
																									   WHERE pap.AccountingPeriodID = #pad.AccountingPeriodID  --@accountingPeriodID
																										 AND ((@byPropertyID = 0) OR ((@byPropertyID = 1) AND (pap.PropertyID = #NetIncomeTotals.PropertyID))))
													  AND ab.GLAccountID = #NetIncomeTotals.GLAccountID)
		OPTION (RECOMPILE)
	
		UPDATE #NetIncomeTotals SET YTDBudget = (SELECT SUM(ab.Amount)
													FROM AlternateBudget ab
													WHERE ab.GLAccountID = #NetIncomeTotals.GLAccountID
													  AND ab.PropertyAccountingPeriodID IN (SELECT DISTINCT pap.PropertyAccountingPeriodID
																								FROM PropertyAccountingPeriod pap
																									INNER JOIN #PropertiesAndDates p ON p.PropertyID = pap.PropertyID
																													AND (ab.YearBudgetID = p.CashAlternateBudgetID OR ab.YearBudgetID = p.AccrualAlternateBudgetID)
																								WHERE ((@byPropertyID = 0) OR ((@byPropertyID = 1) AND (pap.PropertyID = #NetIncomeTotals.PropertyID)))
																								  AND pap.PropertyAccountingPeriodID IN (SELECT PropertyAccountingPeriodID
																																			FROM PropertyAccountingPeriod 
																																			WHERE AccountID  = @accountID
																																			  AND PropertyID = p.PropertyID
																																			  AND StartDate >= p.FiscalYearStartDate
																																			  AND EndDate <= p.EndDate)))
		OPTION (RECOMPILE)
	END
	
	IF ('55555555-5555-5555-5555-555555555555' IN (SELECT Value FROM @accountingBookIDs))
	BEGIN	
		UPDATE  #NetIncomeTotals SET YTDAmount = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.NetMonthlyTotalAccrual), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.NetMonthlyTotalCash), 0)
													END
											 FROM Budget b
											 WHERE b.GLAccountID = #NetIncomeTotals.GLAccountID
											   AND b.PropertyAccountingPeriodID IN (SELECT DISTINCT pap.PropertyAccountingPeriodID
																					FROM PropertyAccountingPeriod pap
																						-- Get closed accounting periods that are not the current accounting period
																						-- for which the report is being run
																						--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID 
																									
																						INNER JOIN #PropertiesAndDates p ON p.PropertyID = pap.PropertyID
																					WHERE pap.StartDate >= p.FiscalYearStartDate																				
																					  --AND pap.EndDate <= @reportDate
																					  --AND pap.Closed = 1 AND (NOT(pap.StartDate <= @reportDate AND pap.EndDate >= @reportDate))
																					  AND pap.EndDate <= p.EndDate
																					  AND pap.Closed = 1 AND (NOT(pap.StartDate <= p.EndDate AND pap.EndDate >= p.EndDate))
																					  AND ((@byPropertyID = 0) OR ((@byPropertyID = 1) AND (pap.PropertyID = #NetIncomeTotals.PropertyID)))))
		OPTION (RECOMPILE)


	
		UPDATE #NetIncomeTotals SET YTDAmount =  ISNULL(YTDAmount, 0) + ISNULL((SELECT ISNULL(SUM(je.Amount), 0)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
															--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID AND ap.AccountingPeriodID <> @accountingPeriodID
															INNER JOIN #PropertiesAndDates p ON p.PropertyID = t.PropertyID															
														WHERE
															  pap.AccountingPeriodID <> p.AccountingPeriodID
														  AND t.TransactionDate >= pap.StartDate
														  AND t.TransactionDate >= p.FiscalYearStartDate
														  AND t.TransactionDate <= pap.EndDate
														  --AND t.TransactionDate <= @reportDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBasis = @accountingBasis
														  AND je.AccountingBookID IS NULL
														  AND ((@byPropertyID = 0) OR ((@byPropertyID = 1) AND (t.PropertyID = #NetIncomeTotals.PropertyID)))
														  AND je.GLAccountID = #NetIncomeTotals.GLAccountID), 0)
		OPTION (RECOMPILE)
	END

	IF ((SELECT COUNT(*) FROM @accountingBookIDs WHERE Value <> '55555555-5555-5555-5555-555555555555') > 0)
	BEGIN
		-- Now consider other Accounting Books.
		UPDATE #NetIncomeTotals SET YTDAmount = ISNULL(YTDAmount, 0) +
													ISNULL((SELECT ISNULL(SUM(je.Amount), 0)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID
															--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID AND ap.AccountingPeriodID <> @accountingPeriodID
															INNER JOIN #PropertiesAndDates p ON p.PropertyID = t.PropertyID
															INNER JOIN #AccountingBookIDs #abIDs ON je.AccountingBookID = #abIDs.AccountingBookID
														WHERE
															  pap.AccountingPeriodID <> p.AccountingPeriodID
														  AND t.TransactionDate >= pap.StartDate
														  AND t.TransactionDate >= p.FiscalYearStartDate
														  AND t.TransactionDate <= pap.EndDate
														  --AND t.TransactionDate <= @reportDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBasis = @accountingBasis
														  AND ((@byPropertyID = 0) OR ((@byPropertyID = 1) AND (t.PropertyID = #NetIncomeTotals.PropertyID)))
														  AND je.GLAccountID = #NetIncomeTotals.GLAccountID), 0)
		OPTION (RECOMPILE)

	END

	-- Not Needed Anymore
	/*
	UPDATE #NetIncomeTotals SET LastYearAmount = (SELECT CASE 
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.NetMonthlyTotalCash), 0)
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.NetMonthlyTotalAccrual), 0)
													END 
												FROM Budget b
													INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
													INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID AND pap.PropertyID = #NetIncomeTotals.PropertyID
													INNER JOIN #Properties p ON p.PropertyID = pap.PropertyID
												WHERE
												  pap.StartDate >= @lastFiscalYearStartDate
												  AND pap.EndDate <= @lastFiscalYearEndDate
												  AND b.GLAccountID = #NetIncomeTotals.GLAccountID)
	OPTION (RECOMPILE)
												  
	UPDATE #NetIncomeTotals SET LastYearAmount = LastYearAmount + (SELECT ISNULL(SUM(je.Amount), 0)
																FROM JournalEntry je
																	INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																	INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
																	INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
																	INNER JOIN #Properties p ON p.PropertyID = t.PropertyID
																WHERE je.AccountingBasis = @accountingBasis
																  AND je.GLAccountID = #NetIncomeTotals.GLAccountID
																  AND t.TransactionDate >= pap.StartDate
																  AND t.TransactionDate <= pap.EndDate
																  -- Don't include closing the year entries
																  AND t.Origin NOT IN ('Y', 'E')
																  AND t.TransactionDate >= @lastFiscalYearStartDate
																  AND t.TransactionDate <= @lastFiscalYearEndDate
																  AND ((@byPropertyID = 0) OR ((@byPropertyID = 1) AND (t.PropertyID = #NetIncomeTotals.PropertyID)))
																 )
	OPTION (RECOMPILE)


	*/
	SELECT	PropertyID,
			ISNULL(SUM(CurrentAPAmount), 0) + ISNULL(SUM(CurrentAPAmountOtherBooks), 0) + ISNULL(SUM(YTDAmount), 0) AS 'YTDIncome',
			ISNULL(SUM(CurrentAPAmount), 0) + ISNULL(SUM(CurrentAPAmountOtherBooks), 0) AS 'CurrentIncome',
			ISNULL(SUM(LastYearAmount), 0) AS 'LastYearIncome'						  
	FROM #NetIncomeTotals	
	GROUP BY PropertyID				
	--SELECT ISNULL(SUM(CASE
	--					  WHEN (GLAccountType IN ('Income', 'Expense', 'Liability')) THEN -YTDAmount
	--					  ELSE YTDAmount
	--					  END), 0) AS 'YTDIncome',
	--	   ISNULL(SUM(CASE
	--					  WHEN (GLAccountType IN ('Income', 'Expense', 'Liability')) THEN -CurrentAPAmount
	--					  ELSE CurrentAPAmount
	--					  END), 0) AS 'CurrentIncome',
	--	   ISNULL(SUM(CASE
	--					  WHEN (GLAccountType IN ('Income', 'Expense', 'Liability')) THEN -LastYearAmount
	--					  ELSE LastYearAmount
	--					  END), 0) AS 'LastYearIncome'						  
	--	FROM #NetIncomeTotals					
END






IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RPT_ACTG_BalanceSheet]') AND type in (N'P', N'PC'))
BEGIN
	EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[RPT_ACTG_BalanceSheet] AS' 
END
GO
