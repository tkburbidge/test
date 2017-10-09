SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Joshua Grigg (based on RPT_CSTM_GEN_TwelveMonthBudgetVariance)
-- Create date: Nov 23, 2015
-- Description:	Generates data set for YearOverYear custom report writer
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_GEN_YearOverYear] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 1,
	@propertyIDs GuidCollection READONLY, 	
	@accountingBasis nvarchar(10) = null,
	@accountingPeriodID uniqueidentifier = null,	
	@budgetsOnly bit = 0,	
	@byProperty bit = 0,
	@glAccountIDs GuidCollection READONLY, -- NEW, if empty pull in all GL Account IDs
	@includeDefaultAccountingBook bit = 1,
	@accountingBookIDs GuidCollection READONLY,
	@alternateBudgetIDs GuidCollection READONLY,
	@tags StringCollection READONLY
AS

DECLARE @allGLAccountTypes StringCollection

BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier not null,
		PropertyAccountingPeriodID uniqueidentifier not null,
		StartDate date null,
		EndDate date null,
		MonthSequence int null,
		CashAlternateBudgetID uniqueidentifier null,
		AccrualAlternateBudgetID uniqueidentifier null)
		
	CREATE TABLE #MonthSequencers (
		Sequence int identity,
		AccountingPeriodID uniqueidentifier not null)
	
 
	CREATE TABLE #Budgets (
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		MonthSequence int not null,		
		Budget money null,
		EndDate date null)

	CREATE TABLE #Actuals (
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		MonthSequence int not null,		
		Actual money null,
		EndDate date null)
		
  
	CREATE TABLE #MyTempBalanceTable (
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		MonthSequence int null,
		Balance money null)
		
  
	CREATE TABLE #PropertiesAndDatesIncomeExpense (
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier not null,
		MonthSequence int null,
		StartDate date null,
		EndDate date null)
		
	CREATE TABLE #AccountingBooks (
		AccountingBookID uniqueidentifier not null)
		
	CREATE TABLE #GLAccounts (
		GLAccountID uniqueidentifier not null)

	CREATE TABLE #AlternateBudgetIDs (
		AlternateBudgetID uniqueidentifier not null) 

	CREATE TABLE #YTDPeriods (
		YearSequence int identity,
		YearPart int null,
		EndAccountingPeriodID uniqueidentifier null,
		FiscalYearStartDate date null,
		YTDEndDate date null)

	CREATE TABLE #PropertiesAndStartDates (
		PropertyID uniqueidentifier not null,
		YearPart int null,
		YearSequence int null,
		EndAccountingPeriodID uniqueidentifier null,
		FiscalYearStartDate date null,
		YTDEndDate date null)

	CREATE TABLE #Tags (
		TagMe nvarchar(50) null)

	INSERT #Tags
		SELECT Value FROM @tags
		
	INSERT #AlternateBudgetIDs
		SELECT Value FROM @alternateBudgetIDs
		
	--DECLARE @yrs_back INT = 0;
	--DECLARE @total_yrs_back INT = -5;
	--DECLARE @per_end_date DATE = (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID);
	--DECLARE @yr_per_end_date DATE;
				 
	--WHILE @yrs_back > @total_yrs_back --we need the equivalent end dates for the @accountingPeriodID for previous 5 years
	--BEGIN
	--	SET @yr_per_end_date = DATEADD(Year, @yrs_back, @per_end_date) --get end date for equivalent period for given year
	--   	INSERT #MonthSequencers	
	--		SELECT [MyAP].AccountingPeriodID 
	--			FROM (SELECT TOP 1 AccountingPeriodID, EndDate			 
	--					  FROM AccountingPeriod
	--					  WHERE EndDate <= @yr_per_end_date
	--						AND AccountID = @accountID
	--					  ORDER BY EndDate DESC) AS [MyAP]
	--			ORDER BY [MyAP].EndDate 

	--	SET @yrs_back = @yrs_back - 1;
	--END;	
					   
		
	DECLARE @endDate date = (SELECT EndDate 
								FROM AccountingPeriod
								WHERE AccountingPeriodID = @accountingPeriodID)
								 

	INSERT #MonthSequencers
			SELECT	TOP 5 
					AccountingPeriodID
				FROM AccountingPeriod
				WHERE DATEPART(MONTH, EndDate) = DATEPART(MONTH, @endDate)
				  AND EndDate <= @endDate
				  AND EndDate > DATEADD(MONTH, -65, @endDate)
				  AND AccountID = @accountID
				ORDER BY EndDate DESC
					  
	INSERT #PropertiesAndDates 
		SELECT	pap.PropertyID,
				#ms.AccountingPeriodID,
				pap.PropertyAccountingPeriodID,
				pap.StartDate,
				pap.EndDate,
				#ms.Sequence, 
				null, 
				null
			FROM @propertyIDs pIDs
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID
				INNER JOIN #MonthSequencers #ms ON pap.AccountingPeriodID = #ms.AccountingPeriodID

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

	INSERT #AccountingBooks 
		SELECT Value FROM @accountingBookIDs

	IF ('55555555-5555-5555-5555-555555555555' IN (SELECT AccountingBookID FROM #AccountingBooks))
	BEGIN
		SET @includeDefaultAccountingBook = 1
	END
	
	IF ((SELECT COUNT(*) FROM @glAccountIDs) = 0)
	BEGIN
		INSERT #GLAccounts
			SELECT DISTINCT GLAccountID FROM GLAccount WHERE AccountID = @accountID
	END
	ELSE
	BEGIN
		INSERT #GLAccounts
			SELECT Value FROM @glAccountIDs
	END
	
	IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe IN ('Year1Budget', 'Year2Budget', 'Year3Budget', 'Year4Budget', 'Year5Budget')))
	BEGIN
		IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
		BEGIN
			INSERT INTO #Budgets
				SELECT 
					b.GLAccountID,
					#pads.PropertyID,
					#pads.MonthSequence,
					CASE WHEN @accountingBasis = 'Accrual' THEN b.AccrualBudget
						 ELSE b.CashBudget
					END,
					#pads.EndDate
				FROM Budget b
					INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = b.GLAccountID
					INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyAccountingPeriodID = b.PropertyAccountingPeriodID	
		END
		ELSE
		BEGIN
			INSERT INTO #Budgets
				SELECT 
					ab.GLAccountID,
					#pads.PropertyID,
					#pads.MonthSequence,
					ab.Amount,
					#pads.EndDate
				FROM AlternateBudget ab
					INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = ab.GLAccountID
					INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyAccountingPeriodID = ab.PropertyAccountingPeriodID
								AND (#pads.AccrualAlternateBudgetID = ab.YearBudgetID OR #pads.CashAlternateBudgetID = ab.YearBudgetID)
		END




		--UPDATE #PropertiesAndDates SET CashAlternateBudgetID = (SELECT YearBudgetID
		--															FROM YearBudget
		--															WHERE PropertyID = #PropertiesAndDates.PropertyID
		--															  AND AccountingBasis = 'Cash'
		--															  AND YearBudgetID IN (SELECT Value FROM @alternateBudgetIDs))
		--UPDATE #PropertiesAndDates SET AccrualAlternateBudgetID = (SELECT YearBudgetID
		--															   FROM YearBudget
		--															   WHERE PropertyID = #PropertiesAndDates.PropertyID
		--																 AND AccountingBasis = 'Accrual'
		--																 AND YearBudgetID IN (SELECT Value FROM @alternateBudgetIDs))
	
		--INSERT INTO #Budgets
		--	SELECT 
		--		ab.GLAccountID,
		--		#pads.PropertyID,
		--		#pads.MonthSequence,
		--		ab.Amount,
		--		#pads.EndDate
		--	FROM AlternateBudget ab
		--		INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = ab.GLAccountID
		--		INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyAccountingPeriodID = ab.PropertyAccountingPeriodID	
		--						AND (ab.YearBudgetID = #pads.AccrualAlternateBudgetID OR ab.YearBudgetID = #pads.CashAlternateBudgetID)
	END

	IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe IN ('Year1Amount', 'Year2Amount', 'Year3Amount', 'Year4Amount', 'Year5Amount')))
	BEGIN
		INSERT INTO #Actuals
			SELECT 
				je.GLAccountID,
				t.PropertyID,
				#pads.MonthSequence,
				SUM(je.Amount),			
				#pads.EndDate
			FROM JournalEntry je
				INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
				INNER JOIN #PropertiesAndDates #pads ON t.PropertyID = #pads.PropertyID AND t.TransactionDate >= #pads.StartDate AND t.TransactionDate <= #pads.EndDate
				INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = je.GLAccountID
				LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 			
			WHERE t.Origin NOT IN ('Y', 'E')
				AND je.AccountID = @accountID
				AND je.AccountingBasis = @accountingBasis
				AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
			GROUP BY je.GLAccountID, t.PropertyID, #pads.MonthSequence, #pads.EndDate
	END
	
	CREATE TABLE #ConsolodatedReturnNumbers (
		PropertyID uniqueidentifier			not null,
		GLAccountID uniqueidentifier		not null,
		GLAccountNumber nvarchar(50)		not null,
		GLAccountName nvarchar(100)			not null,
		GLAccountType nvarchar(100)			not null,
		Year1Actual money					null,
		Year1Budget money					null,
		Year1Balance money					null,
		Year1YTDAmount money				null,
		Year1YTDBudget money				null,
		Year2Actual money					null,
		Year2Budget money					null,
		Year2Balance money					null,
		Year2YTDAmount money				null,
		Year2YTDBudget money				null,
		Year3Actual money					null,
		Year3Budget money					null,
		Year3Balance money					null,
		Year3YTDAmount money				null,
		Year3YTDBudget money				null,
		Year4Actual money					null,
		Year4Budget money					null,
		Year4Balance money					null,
		Year4YTDAmount money				null,
		Year4YTDBudget money				null,
		Year5Actual money					null,
		Year5Budget money					null,
		Year5Balance money					null,
		Year5YTDAmount money				null,
		Year5YTDBudget money				null,
		TotalActual money					null,
		TotalBudget money					null)	
		
	INSERT #ConsolodatedReturnNumbers
		SELECT	DISTINCT
				#pad.PropertyID,
				gla.GLAccountID,
				gla.Number,
				gla.Name,
				gla.GLAccountType,
				null, null, null, null, null, null, null, null, null, null,							-- 10 nulls added to original statement to account for 10 new columns, 5 of YTDxAmount & 5 of YTDxBudget
				null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null
			FROM #GLAccounts #gla
				INNER JOIN GLAccount gla ON gla.GLAccountID = #gla.GLAccountID
				INNER JOIN #PropertiesAndDates #pad ON 1 = 1
				
	

 
	UPDATE #ConsolodatedReturnNumbers SET Year1Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 1), 0)

	UPDATE #ConsolodatedReturnNumbers SET Year2Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 2), 0)

	UPDATE #ConsolodatedReturnNumbers SET Year3Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 3), 0)
	
	UPDATE #ConsolodatedReturnNumbers SET Year4Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 4), 0)
	
	UPDATE #ConsolodatedReturnNumbers SET Year5Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 5), 0)




	UPDATE #ConsolodatedReturnNumbers SET Year1Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 1), 0)

	UPDATE #ConsolodatedReturnNumbers SET Year2Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 2), 0)

	UPDATE #ConsolodatedReturnNumbers SET Year3Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 3), 0)
																	
	UPDATE #ConsolodatedReturnNumbers SET Year4Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 4), 0)
	
	UPDATE #ConsolodatedReturnNumbers SET Year5Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 5), 0)																
	
	

	UPDATE #ConsolodatedReturnNumbers SET TotalBudget = Year1Budget + Year2Budget + Year3Budget + Year4Budget + Year5Budget
	
	UPDATE #ConsolodatedReturnNumbers SET TotalActual = Year1Actual + Year2Actual + Year3Actual + Year4Actual + Year5Actual
	
-- Do some math for Income & Expense Accounts, year to date numbers!

	INSERT #PropertiesAndDatesIncomeExpense 
		SELECT PropertyID, AccountingPeriodID, MonthSequence, null, EndDate
			FROM #PropertiesAndDates

	UPDATE #PropertiesAndDatesIncomeExpense SET StartDate = dbo.GetFiscalYearStartDate(@accountID, #PropertiesAndDatesIncomeExpense.AccountingPeriodID, #PropertiesAndDatesIncomeExpense.PropertyID)
	IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe IN ('Year1Balance', 'Year2Balance', 'Year3Balance', 'Year4Balance', 'Year5Balance')))
	BEGIN
		INSERT INTO #MyTempBalanceTable
			SELECT je.GLAccountID, #padie.PropertyID, #padie.MonthSequence, SUM(CASE WHEN gl.GLAccountType IN ('Income', 'Other Income') THEN -je.Amount ELSE je.Amount END)
					FROM JournalEntry je
						INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
						INNER JOIN GLAccount gl ON gl.GLAccountID = je.GLAccountID			
						INNER JOIN #PropertiesAndDatesIncomeExpense #padie ON t.PropertyID = #padie.PropertyID
						INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = je.GLAccountID
						LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
					WHERE je.AccountingBasis = @accountingBasis
						AND t.TransactionDate >= #padie.StartDate
						AND t.Origin NOT IN ('Y', 'E')
						AND t.TransactionDate <= #padie.EndDate
						AND gl.GLAccountType IN ('Income', 'Expense', 'Other Expense', 'Other Income', 'Non-Operating Expense')					
						AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
			GROUP BY je.GLAccountID, #padie.MonthSequence, #padie.PropertyID
		OPTION (RECOMPILE)

		-- Add 3 new balance columns for each GLAccount passed in of this flavor.
		INSERT INTO #MyTempBalanceTable
			SELECT je.GLAccountID, #pad.PropertyID, #pad.MonthSequence, SUM(CASE WHEN gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity') THEN -je.Amount ELSE  je.Amount END)
					FROM JournalEntry je
						INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
						INNER JOIN GLAccount gl ON gl.GLAccountID = je.GLAccountID			
						INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
						INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = je.GLAccountID
						LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
					WHERE
						t.TransactionDate <= #pad.EndDate
						AND je.AccountingBasis = @accountingBasis
						AND gl.GLAccountType IN ('Bank', 'Accounts Receivable', 'Other Current Asset', 'Fixed Asset', 'Other Asset', 'Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity')					
						AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
			GROUP BY je.GLAccountID, #pad.MonthSequence, #pad.PropertyID
		OPTION (RECOMPILE)
	END
	--select * from #MyTempBalanceTable
	--select * from #PropertiesAndDatesIncomeExpense

	UPDATE #ConsolodatedReturnNumbers SET Year1Balance = ISNULL((SELECT Balance
																	  FROM #MyTempBalanceTable
																		  WHERE MonthSequence = 1
																			AND GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																			AND PropertyID = #ConsolodatedReturnNumbers.PropertyID), 0)

	UPDATE #ConsolodatedReturnNumbers SET Year2Balance = ISNULL((SELECT Balance
																	  FROM #MyTempBalanceTable
																		  WHERE MonthSequence = 2
																			AND GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																			AND PropertyID = #ConsolodatedReturnNumbers.PropertyID), 0)

	UPDATE #ConsolodatedReturnNumbers SET Year3Balance = ISNULL((SELECT Balance
																	  FROM #MyTempBalanceTable
																		  WHERE MonthSequence = 3
																			AND GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																			AND PropertyID = #ConsolodatedReturnNumbers.PropertyID), 0)

	UPDATE #ConsolodatedReturnNumbers SET Year4Balance = ISNULL((SELECT Balance
																	  FROM #MyTempBalanceTable
																		  WHERE MonthSequence = 4
																			AND GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																			AND PropertyID = #ConsolodatedReturnNumbers.PropertyID), 0)

	UPDATE #ConsolodatedReturnNumbers SET Year5Balance = ISNULL((SELECT Balance
																	  FROM #MyTempBalanceTable
																		  WHERE MonthSequence = 5
																			AND GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																			AND PropertyID = #ConsolodatedReturnNumbers.PropertyID), 0)


	IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe LIKE '%YTD%'))
	BEGIN
		
		SET @endDate = (SELECT EndDate 
							FROM AccountingPeriod
							WHERE AccountingPeriodID = @accountingPeriodID)

		INSERT #YTDPeriods
			SELECT	TOP 5 
					CAST(DATEPART(YEAR, EndDate) AS int),
					AccountingPeriodID,
					null,
					EndDate
				FROM AccountingPeriod
				WHERE DATEPART(MONTH, EndDate) = DATEPART(MONTH, @endDate)
				  AND EndDate <= @endDate
				  AND EndDate > DATEADD(MONTH, -65, @endDate)
				  AND AccountID = @accountID
				ORDER BY EndDate DESC

		INSERT #PropertiesAndStartDates
			SELECT	DISTINCT
					pIDs.Value,
					#YTDP.YearPart,
					#YTDP.YearSequence,
					#YTDP.EndAccountingPeriodID,
					null,
					pap.EndDate
				FROM @propertyIDs pIDs
					INNER JOIN #YTDPeriods #YTDP ON 1 = 1
					INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND #YTDP.EndAccountingPeriodID = pap.AccountingPeriodID

					
		UPDATE #PropertiesAndStartDates SET FiscalYearStartDate = dbo.GetFiscalYearStartDate(@accountID, #PropertiesAndStartDates.EndAccountingPeriodID, #PropertiesAndStartDates.PropertyID)



		IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe = 'Year1YTDAmount'))
		BEGIN
			TRUNCATE TABLE #Actuals

			INSERT INTO #Actuals
				SELECT 
					je.GLAccountID,
					t.PropertyID,
					#pads.YearSequence,
					SUM(je.Amount),			
					#pads.YTDEndDate
				FROM JournalEntry je
					INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
					INNER JOIN #PropertiesAndStartDates #pads ON t.TransactionDate >= #pads.FiscalYearStartDate AND t.TransactionDate <= #pads.YTDEndDate AND #pads.YearSequence = 1
					INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = je.GLAccountID
					LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 			
				WHERE t.Origin NOT IN ('Y', 'E')
					AND je.AccountID = @accountID
					AND je.AccountingBasis = @accountingBasis
					AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
				GROUP BY je.GLAccountID, t.PropertyID, #pads.YearSequence, #pads.YTDEndDate
	
			UPDATE #ConsolodatedReturnNumbers SET Year1YTDAmount = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																			   FROM #Actuals #a
																				   INNER JOIN #YTDPeriods #YTDP ON #a.MonthSequence = #YTDP.YearSequence
																			   WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																				 AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																				 AND #a.MonthSequence = 1), 0)
		END


		IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe = 'Year2YTDAmount'))
		BEGIN
			TRUNCATE TABLE #Actuals

			INSERT INTO #Actuals
				SELECT 
					je.GLAccountID,
					t.PropertyID,
					#pads.YearSequence,
					SUM(je.Amount),			
					#pads.YTDEndDate
				FROM JournalEntry je
					INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
					INNER JOIN #PropertiesAndStartDates #pads ON t.TransactionDate >= #pads.FiscalYearStartDate AND t.TransactionDate <= #pads.YTDEndDate AND #pads.YearSequence = 2
					INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = je.GLAccountID
					LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 			
				WHERE t.Origin NOT IN ('Y', 'E')
					AND je.AccountID = @accountID
					AND je.AccountingBasis = @accountingBasis
					AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
				GROUP BY je.GLAccountID, t.PropertyID, #pads.YearSequence, #pads.YTDEndDate
	
			UPDATE #ConsolodatedReturnNumbers SET Year2YTDAmount = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																			   FROM #Actuals #a
																				   INNER JOIN #YTDPeriods #YTDP ON #a.MonthSequence = #YTDP.YearSequence
																			   WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																				 AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																				 AND #a.MonthSequence = 2), 0)
		END


		IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe = 'Year3YTDAmount'))
		BEGIN
			TRUNCATE TABLE #Actuals

			INSERT INTO #Actuals
				SELECT 
					je.GLAccountID,
					t.PropertyID,
					#pads.YearSequence,
					SUM(je.Amount),			
					#pads.YTDEndDate
				FROM JournalEntry je
					INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
					INNER JOIN #PropertiesAndStartDates #pads ON t.TransactionDate >= #pads.FiscalYearStartDate AND t.TransactionDate <= #pads.YTDEndDate AND #pads.YearSequence = 3
					INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = je.GLAccountID
					LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 			
				WHERE t.Origin NOT IN ('Y', 'E')
					AND je.AccountID = @accountID
					AND je.AccountingBasis = @accountingBasis
					AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
				GROUP BY je.GLAccountID, t.PropertyID, #pads.YearSequence, #pads.YTDEndDate
	
			UPDATE #ConsolodatedReturnNumbers SET Year3YTDAmount = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																			   FROM #Actuals #a
																				   INNER JOIN #YTDPeriods #YTDP ON #a.MonthSequence = #YTDP.YearSequence
																			   WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																				 AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																				 AND #a.MonthSequence = 3), 0)
		END


		IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe = 'Year4YTDAmount'))
		BEGIN
			TRUNCATE TABLE #Actuals

			INSERT INTO #Actuals
				SELECT 
					je.GLAccountID,
					t.PropertyID,
					#pads.YearSequence,
					SUM(je.Amount),			
					#pads.YTDEndDate
				FROM JournalEntry je
					INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
					INNER JOIN #PropertiesAndStartDates #pads ON t.TransactionDate >= #pads.FiscalYearStartDate AND t.TransactionDate <= #pads.YTDEndDate AND #pads.YearSequence = 4
					INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = je.GLAccountID
					LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 			
				WHERE t.Origin NOT IN ('Y', 'E')
					AND je.AccountID = @accountID
					AND je.AccountingBasis = @accountingBasis
					AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
				GROUP BY je.GLAccountID, t.PropertyID, #pads.YearSequence, #pads.YTDEndDate
	
			UPDATE #ConsolodatedReturnNumbers SET Year4YTDAmount = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																			   FROM #Actuals #a
																				   INNER JOIN #YTDPeriods #YTDP ON #a.MonthSequence = #YTDP.YearSequence
																			   WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																				 AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																				 AND #a.MonthSequence = 4), 0)
		END


		IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe = 'Year5YTDAmount'))
		BEGIN
			TRUNCATE TABLE #Actuals

			INSERT INTO #Actuals
				SELECT 
					je.GLAccountID,
					t.PropertyID,
					#pads.YearSequence,
					SUM(je.Amount),			
					#pads.YTDEndDate
				FROM JournalEntry je
					INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
					INNER JOIN #PropertiesAndStartDates #pads ON t.TransactionDate >= #pads.FiscalYearStartDate AND t.TransactionDate <= #pads.YTDEndDate AND #pads.YearSequence = 5
					INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = je.GLAccountID
					LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 			
				WHERE t.Origin NOT IN ('Y', 'E')
					AND je.AccountID = @accountID
					AND je.AccountingBasis = @accountingBasis
					AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
				GROUP BY je.GLAccountID, t.PropertyID, #pads.YearSequence, #pads.YTDEndDate

			UPDATE #ConsolodatedReturnNumbers SET Year5YTDAmount = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																			   FROM #Actuals #a
																				   INNER JOIN #YTDPeriods #YTDP ON #a.MonthSequence = #YTDP.YearSequence
																			   WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																				 AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																				 AND #a.MonthSequence = 5), 0)
		END

		IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe = 'Year1YTDBudget'))
		BEGIN
			TRUNCATE TABLE #Budgets

			IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
			BEGIN
				INSERT INTO #Budgets
					SELECT 
						b.GLAccountID,
						#pads.PropertyID,
						#pads.YearSequence,
						CASE WHEN @accountingBasis = 'Accrual' THEN b.AccrualBudget
							 ELSE b.CashBudget
						END,
						pap.EndDate
					FROM Budget b
						INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = b.GLAccountID
						INNER JOIN #PropertiesAndStartDates #pads ON #pads.YearSequence = 1
						INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate >= #pads.FiscalYearStartDate AND pap.EndDate <= #pads.YTDEndDate
																	AND b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND #pads.PropertyID = pap.PropertyID
			END
			ELSE
			BEGIN
				INSERT INTO #Budgets
					SELECT 
						ab.GLAccountID,
						#pads.PropertyID,
						#pads.YearSequence,
						ab.Amount,
						pap.EndDate
					FROM AlternateBudget ab
						INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = ab.GLAccountID
						INNER JOIN #PropertiesAndStartDates #pads ON #pads.YearSequence = 1
						INNER JOIN #PropertiesAndDates #pad ON #pads.PropertyID = #pad.PropertyID
									AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
						INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate >= #pads.FiscalYearStartDate AND pap.EndDate <= #pads.YTDEndDate
																	AND ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND #pads.PropertyID = pap.PropertyID
			END
	
			UPDATE #ConsolodatedReturnNumbers SET Year1YTDBudget = ISNULL((SELECT SUM(Budget)
																			   FROM #Budgets #b
																			   WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																				 AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																				 AND #b.MonthSequence = 1), 0)
		END

		IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe = 'Year2YTDBudget'))
		BEGIN
			TRUNCATE TABLE #Budgets

			IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
			BEGIN
				INSERT INTO #Budgets
					SELECT 
						b.GLAccountID,
						#pads.PropertyID,
						#pads.YearSequence,
						CASE WHEN @accountingBasis = 'Accrual' THEN b.AccrualBudget
							 ELSE b.CashBudget
						END,
						pap.EndDate
					FROM Budget b
						INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = b.GLAccountID
						INNER JOIN #PropertiesAndStartDates #pads ON #pads.YearSequence = 2
						INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate >= #pads.FiscalYearStartDate AND pap.EndDate <= #pads.YTDEndDate
																AND b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND #pads.PropertyID = pap.PropertyID
			END
			ELSE
			BEGIN
				INSERT INTO #Budgets
					SELECT 
						ab.GLAccountID,
						#pads.PropertyID,
						#pads.YearSequence,
						ab.Amount,
						pap.EndDate
					FROM AlternateBudget ab
						INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = ab.GLAccountID
						INNER JOIN #PropertiesAndStartDates #pads ON #pads.YearSequence = 2
						INNER JOIN #PropertiesAndDates #pad ON #pads.PropertyID = #pad.PropertyID
									AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
						INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate >= #pads.FiscalYearStartDate AND pap.EndDate <= #pads.YTDEndDate
																	AND ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND #pads.PropertyID = pap.PropertyID
			END




			UPDATE #ConsolodatedReturnNumbers SET Year2YTDBudget = ISNULL((SELECT SUM(Budget)
																			   FROM #Budgets #b
																			   WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																				 AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																				 AND #b.MonthSequence = 2), 0)
		END

		IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe = 'Year3YTDBudget'))
		BEGIN
			TRUNCATE TABLE #Budgets

			IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
			BEGIN
				INSERT INTO #Budgets
					SELECT 
						b.GLAccountID,
						#pads.PropertyID,
						#pads.YearSequence,
						CASE WHEN @accountingBasis = 'Accrual' THEN b.AccrualBudget
							 ELSE b.CashBudget
						END,
						pap.EndDate
					FROM Budget b
						INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = b.GLAccountID
						INNER JOIN #PropertiesAndStartDates #pads ON #pads.YearSequence = 3
						INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate >= #pads.FiscalYearStartDate AND pap.EndDate <= #pads.YTDEndDate
																	AND b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND #pads.PropertyID = pap.PropertyID
			END
			ELSE
			BEGIN
				INSERT INTO #Budgets
					SELECT 
						ab.GLAccountID,
						#pads.PropertyID,
						#pads.YearSequence,
						ab.Amount,
						pap.EndDate
					FROM AlternateBudget ab
						INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = ab.GLAccountID
						INNER JOIN #PropertiesAndStartDates #pads ON #pads.YearSequence = 3
						INNER JOIN #PropertiesAndDates #pad ON #pads.PropertyID = #pad.PropertyID
									AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
						INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate >= #pads.FiscalYearStartDate AND pap.EndDate <= #pads.YTDEndDate
																	AND ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND #pads.PropertyID = pap.PropertyID
			END

			UPDATE #ConsolodatedReturnNumbers SET Year3YTDBudget = ISNULL((SELECT SUM(Budget)
																			   FROM #Budgets #b
																			   WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																				 AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																				 AND #b.MonthSequence = 3), 0)

		END

		IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe = 'Year4YTDBudget'))
		BEGIN
			TRUNCATE TABLE #Budgets

			IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
			BEGIN
				INSERT INTO #Budgets
					SELECT 
						b.GLAccountID,
						#pads.PropertyID,
						#pads.YearSequence,
						CASE WHEN @accountingBasis = 'Accrual' THEN b.AccrualBudget
							 ELSE b.CashBudget
						END,
						pap.EndDate
					FROM Budget b
						INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = b.GLAccountID
						INNER JOIN #PropertiesAndStartDates #pads ON #pads.YearSequence = 4
						INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate >= #pads.FiscalYearStartDate AND pap.EndDate <= #pads.YTDEndDate
																	AND b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND #pads.PropertyID = pap.PropertyID
			END
			ELSE
			BEGIN
				INSERT INTO #Budgets
					SELECT 
						ab.GLAccountID,
						#pads.PropertyID,
						#pads.YearSequence,
						ab.Amount,
						pap.EndDate
					FROM AlternateBudget ab
						INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = ab.GLAccountID
						INNER JOIN #PropertiesAndStartDates #pads ON #pads.YearSequence = 4
						INNER JOIN #PropertiesAndDates #pad ON #pads.PropertyID = #pad.PropertyID
									AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
						INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate >= #pads.FiscalYearStartDate AND pap.EndDate <= #pads.YTDEndDate
																	AND ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND #pads.PropertyID = pap.PropertyID
			END

			UPDATE #ConsolodatedReturnNumbers SET Year4YTDBudget = ISNULL((SELECT SUM(Budget)
																			   FROM #Budgets #b
																			   WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																				 AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																				 AND #b.MonthSequence = 4), 0)
		END

		IF (0 < (SELECT COUNT(*) FROM #Tags WHERE TagMe = 'Year5YTDBudget'))
		BEGIN
			TRUNCATE TABLE #Budgets

			IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
			BEGIN
				INSERT INTO #Budgets
					SELECT 
						b.GLAccountID,
						#pads.PropertyID,
						#pads.YearSequence,
						CASE WHEN @accountingBasis = 'Accrual' THEN b.AccrualBudget
							 ELSE b.CashBudget
						END,
						pap.EndDate
					FROM Budget b
						INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = b.GLAccountID
						INNER JOIN #PropertiesAndStartDates #pads ON #pads.YearSequence = 5
						INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate >= #pads.FiscalYearStartDate AND pap.EndDate <= #pads.YTDEndDate
																	AND b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND #pads.PropertyID = pap.PropertyID
			END
			ELSE
			BEGIN
				INSERT INTO #Budgets
					SELECT 
						ab.GLAccountID,
						#pads.PropertyID,
						#pads.YearSequence,
						ab.Amount,
						pap.EndDate
					FROM AlternateBudget ab
						INNER JOIN #GLAccounts #gl ON #gl.GLAccountID = ab.GLAccountID
						INNER JOIN #PropertiesAndStartDates #pads ON #pads.YearSequence = 5
						INNER JOIN #PropertiesAndDates #pad ON #pads.PropertyID = #pad.PropertyID
									AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
						INNER JOIN PropertyAccountingPeriod pap ON pap.StartDate >= #pads.FiscalYearStartDate AND pap.EndDate <= #pads.YTDEndDate
																	AND ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND #pads.PropertyID = pap.PropertyID
			END

			UPDATE #ConsolodatedReturnNumbers SET Year5YTDBudget = ISNULL((SELECT SUM(Budget)
																			   FROM #Budgets #b
																			   WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																				 AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																				 AND #b.MonthSequence = 5), 0)
		END
	END



	IF (@byProperty = 1)
	BEGIN													    
		
		SELECT * FROM #ConsolodatedReturnNumbers
	END
	ELSE
	BEGIN
		SELECT
				#crn.GLAccountNumber AS 'GLNumber',
				#crn.GLAccountName AS 'GLName',
				#crn.GLAccountID,
				SUM(#crn.Year1Actual) AS 'Year1Amount',
				SUM(#crn.Year1Budget) AS 'Year1Budget',
				SUM(#crn.Year1Balance) AS 'Year1Balance',
				SUM(#crn.Year1YTDAmount) AS 'Year1YTDAmount',
				SUM(#crn.Year1YTDBudget) AS 'Year1YTDBudget',
				SUM(#crn.Year2Actual) AS 'Year2Amount',
				SUM(#crn.Year2Budget) AS 'Year2Budget',
				SUM(#crn.Year2Balance) AS 'Year2Balance',
				SUM(#crn.Year2YTDAmount) AS 'Year2YTDAmount',
				SUM(#crn.Year2YTDBudget) AS 'Year2YTDBudget',
				SUM(#crn.Year3Actual) AS 'Year3Amount',
				SUM(#crn.Year3Budget) AS 'Year3Budget',
				SUM(#crn.Year3Balance) AS 'Year3Balance',
				SUM(#crn.Year3YTDAmount) AS 'Year3YTDAmount',
				SUM(#crn.Year3YTDBudget) AS 'Year3YTDBudget',
				SUM(#crn.Year4Actual) AS 'Year4Amount',
				SUM(#crn.Year4Budget) AS 'Year4Budget',
				SUM(#crn.Year4Balance) AS 'Year4Balance',
				SUM(#crn.Year4YTDAmount) AS 'Year4YTDAmount',
				SUM(#crn.Year4YTDBudget) AS 'Year4YTDBudget',
				SUM(#crn.Year5Actual) AS 'Year5Amount',
				SUM(#crn.Year5Budget) AS 'Year5Budget',
				SUM(#crn.Year5Balance) AS 'Year5Balance',
				SUM(#crn.Year5YTDAmount) AS 'Year5YTDAmount',
				SUM(#crn.Year5YTDBudget) AS 'Year5YTDBudget',
				SUM(#crn.TotalActual) AS 'TotalAmount',
				SUM(#crn.TotalBudget) AS 'TotalBudget'
			FROM #ConsolodatedReturnNumbers #crn				
			GROUP BY #crn.GLAccountID, #crn.GLAccountName, #crn.GLAccountNumber
			ORDER BY #crn.GLAccountNumber
	END
						
END
GO
