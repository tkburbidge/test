SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_CSTM_GEN_QuarterBudgetVariance] 
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
	
		
	CREATE TABLE #MyTempBalanceTable (
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		MonthSequence int null,
		Balance money null)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier not null,
		PropertyAccountingPeriodID uniqueidentifier not null,
		StartDate date null,
		EndDate date null,
		MonthSequence int null,
		CashAlternateBudgetID uniqueidentifier NULL,
		AccrualAlternateBudgetID uniqueidentifier NULL)
		

	CREATE TABLE #PropertiesAndDatesIncomeExpense (
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier not null,
		MonthSequence int null,
		StartDate date null,
		EndDate date null)
		
	CREATE TABLE #MonthSequencers (
		[Sequence] int identity,
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
		
	CREATE TABLE #MyTempYTDTable (
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		YTDAmount money null,
		YTDBudget money null,
		YTDBudgetNote nvarchar(MAX))

	CREATE TABLE #PropertiesAndDatesYTD (
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier null,
		StartDate date null,
		EndDate date null,
		YearStartMonth int null,
		FiscalYearStartDate date null,
		FiscalYearEndDate date null)

	INSERT #PropertiesAndDatesYTD
		SELECT	pIDs.Value, 
				@accountingPeriodID,
				pap.StartDate,
				pap.EndDate,
				prop.FiscalYearStartMonth,
				null,
				null
			FROM @propertyIDs pIDs
				INNER JOIN Property prop ON pIDs.Value = prop.PropertyID 
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	
	UPDATE #PropertiesAndAlternateBudgets SET CashAlternateBudgetID = (SELECT YearBudgetID
																			FROM YearBudget
																			WHERE PropertyID = #PropertiesAndAlternateBudgets.PropertyID
																			  AND AccountingBasis = 'Cash'
																			  AND @accountingBasis = 'Cash'
																			  AND YearBudgetID IN (SELECT Value FROM @alternateBudgetIDs))

	UPDATE #PropertiesAndAlternateBudgets SET AccrualAlternateBudgetID = (SELECT YearBudgetID
																			   FROM YearBudget
																			   WHERE PropertyID = #PropertiesAndAlternateBudgets.PropertyID
																				 AND AccountingBasis = 'Accrual'
																				 AND @accountingBasis = 'Accrual'
																				 AND YearBudgetID IN (SELECT Value FROM @alternateBudgetIDs))
	
	-- Set the fiscal year start date to be the start date for the calculated accounting period
	UPDATE #PropertiesAndDatesYTD 
		SET FiscalYearStartDate = (SELECT dbo.GetFiscalYearStartDate(@accountID, #PropertiesAndDatesYTD.AccountingPeriodID, #PropertiesAndDatesYTD.PropertyID))

	CREATE TABLE #AccountingBooks (
		AccountingBookID uniqueidentifier not null)
		
	CREATE TABLE #GLAccounts (
		GLAccountID uniqueidentifier not null)
	



	INSERT #MonthSequencers			-- Need ot take into account the logic from the other 12 month to make sure we don't pull back more than we should
		SELECT [MyAP].AccountingPeriodID 
			FROM (SELECT TOP 3 AccountingPeriodID, EndDate
					  FROM AccountingPeriod
					  WHERE EndDate <= (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
					    AND AccountID = @accountID
					  ORDER BY EndDate DESC) AS [MyAP]
			ORDER BY [MyAP].EndDate 
		  
	INSERT #PropertiesAndDates 
		SELECT	pap.PropertyID,
				#ms.AccountingPeriodID,
				pap.PropertyAccountingPeriodID,
				pap.StartDate,
				pap.EndDate,
				#ms.[Sequence],
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
		
	--INSERT @allGLAccountTypes
	--	SELECT DISTINCT GLAccountType FROM GLAccount
	
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

	
	CREATE TABLE #ConsolodatedReturnNumbers (
		PropertyID uniqueidentifier			not null,
		GLAccountID uniqueidentifier		not null,
		GLAccountNumber nvarchar(50)		not null,
		GLAccountName nvarchar(100)			not null,
		GLAccountType nvarchar(100)			not null,
		Month1Actual money					null,
		Month1Budget money					null,
		Month1Balance money					null,				-- Balance
		Month2Actual money					null,
		Month2Budget money					null,
		Month2Balance money					null,				-- Balance
		Month3Actual money					null,
		Month3Budget money					null,
		Month3Balance money					null,				-- Balance
		TotalActual money					null,
		TotalBudget money					null,
		YTDActual money						null,
		YTDBudget money						null)	
		
	INSERT #ConsolodatedReturnNumbers
		SELECT	DISTINCT
				#pad.PropertyID,
				gla.GLAccountID,
				gla.Number,
				gla.Name,
				gla.GLAccountType,
				null, null, null, null, null, null, null, null, null, null, null, null, null
			FROM #GLAccounts #gla
				INNER JOIN GLAccount gla ON gla.GLAccountID = #gla.GLAccountID
				INNER JOIN #PropertiesAndDates #pad ON 1 = 1

				

	
	UPDATE #ConsolodatedReturnNumbers SET Month1Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 1), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month2Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 2), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month3Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 3), 0)





	UPDATE #ConsolodatedReturnNumbers SET Month1Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 1), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month2Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 2), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month3Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 3), 0)
	
	

	UPDATE #ConsolodatedReturnNumbers SET TotalBudget = Month1Budget + Month2Budget + Month3Budget
	
	UPDATE #ConsolodatedReturnNumbers SET TotalActual = Month1Actual + Month2Actual + Month3Actual




-- Do some math for Income & Expense Accounts, year to date numbers!

	INSERT #PropertiesAndDatesIncomeExpense 
		SELECT PropertyID, AccountingPeriodID, MonthSequence, null, EndDate
			FROM #PropertiesAndDates

	UPDATE #PropertiesAndDatesIncomeExpense SET StartDate = dbo.GetFiscalYearStartDate(@accountID, #PropertiesAndDatesIncomeExpense.AccountingPeriodID, #PropertiesAndDatesIncomeExpense.PropertyID)

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

	UPDATE #ConsolodatedReturnNumbers SET Month1Balance = ISNULL((SELECT Balance
																	  FROM #MyTempBalanceTable
																		  WHERE MonthSequence = 1
																			AND GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																			AND PropertyID = #ConsolodatedReturnNumbers.PropertyID), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month2Balance = ISNULL((SELECT Balance
																	  FROM #MyTempBalanceTable
																		  WHERE MonthSequence = 2
																			AND GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																			AND PropertyID = #ConsolodatedReturnNumbers.PropertyID), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month3Balance = ISNULL((SELECT Balance
																	  FROM #MyTempBalanceTable
																		  WHERE MonthSequence = 3
																			AND GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																			AND PropertyID = #ConsolodatedReturnNumbers.PropertyID), 0)



	
	
		-- Calculate YTD values
		INSERT INTO #MyTempYTDTable
			SELECT je.GLAccountID, #pad.PropertyID, SUM(je.Amount), null, null
					FROM JournalEntry je
						INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID						
						INNER JOIN #PropertiesAndDatesYTD #pad ON t.PropertyID = #pad.PropertyID
						INNER JOIN #GLAccounts #gl ON #gl.GLAccountID =je.GLAccountID
						LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
					WHERE
						t.TransactionDate <= #pad.EndDate
						AND t.TransactionDate >= #pad.FiscalYearStartDate						
						AND je.AccountingBasis = @accountingBasis						
						-- Don't include closing the year entries
						AND t.Origin NOT IN ('Y', 'E')
						AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
			GROUP BY je.GLAccountID, #pad.PropertyID	
		OPTION (RECOMPILE)

		INSERT INTO #MyTempYTDTable
			SELECT #gl.GLAccountID, #pad.PropertyID, 0, null, null
			FROM #GLAccounts #gl
				INNER JOIN #PropertiesAndDatesYTD #pad ON 1 = 1
				LEFT JOIN #MyTempYTDTable #y ON #y.GLAccountID = #gl.GLAccountID AND #y.PropertyID = #pad.PropertyID
			WHERE #y.GLAccountID IS NULL

		-- Calculate YTD budget including all budget amounts
		-- for all periods greater than the fiscal year start date
		-- and less than the end date
		IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
		BEGIN
			UPDATE #MyTempYTDTable SET YTDBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											FROM Budget b
											INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyAccountingPeriodID = b.PropertyAccountingPeriodID
											WHERE b.GLAccountID = #MyTempYTDTable.GLAccountID
												AND #MyTempYTDTable.PropertyID = pap.PropertyID
												AND b.PropertyAccountingPeriodID IN (SELECT DISTINCT pap.PropertyAccountingPeriodID
																						FROM PropertyAccountingPeriod pap
																						INNER JOIN #PropertiesAndDatesYTD #pads ON #pads.PropertyID = pap.PropertyID
																						WHERE
																							pap.StartDate >= #pads.FiscalYearStartDate
																							AND pap.EndDate <= #pads.EndDate))	
		END	
		ELSE
		BEGIN
			UPDATE #MyTempYTDTable SET YTDBudget = (SELECT ab.Amount
														FROM AlternateBudget ab
															INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyAccountingPeriodID = ab.PropertyAccountingPeriodID
															INNER JOIN #PropertiesAndDates #pads ON pap.PropertyID = #pads.PropertyID
																		AND (#pads.AccrualAlternateBudgetID = ab.YearBudgetID OR #pads.CashAlternateBudgetID = ab.YearBudgetID)
														WHERE ab.GLAccountID = #MyTempYTDTable.GLAccountID
														  AND #MyTempYTDTable.PropertyID = pap.PropertyID
														  AND ab.PropertyAccountingPeriodID IN (SELECT DISTINCT pap.PropertyAccountingPeriodID
																									FROM PropertyAccountingPeriod pap
																										INNER JOIN #PropertiesAndDatesYTD #pads ON #pads.PropertyID = pap.PropertyID
																									WHERE
																										pap.StartDate >= #pads.FiscalYearStartDate
																										AND pap.EndDate <= #pads.EndDate))	
		END

	UPDATE #ConsolodatedReturnNumbers SET YTDActual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -YTDAmount ELSE YTDAmount END
																  FROM #MyTempYTDTable #b
																  WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID), 0)

	UPDATE #ConsolodatedReturnNumbers SET YTDBudget = ISNULL((SELECT YTDBudget
																  FROM #MyTempYTDTable #b
																  WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID), 0)

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
				SUM(#crn.Month1Actual) AS 'Month1Amount',
				SUM(#crn.Month1Budget) AS 'Month1Budget',
				SUM(ISNULL(#crn.Month1Balance, 0)) AS 'Month1Balance',
				SUM(#crn.Month2Actual) AS 'Month2Amount',
				SUM(#crn.Month2Budget) AS 'Month2Budget',
				SUM(ISNULL(#crn.Month2Balance, 0)) AS 'Month2Balance',
				SUM(#crn.Month3Actual) AS 'Month3Amount',
				SUM(#crn.Month3Budget) AS 'Month3Budget',
				SUM(ISNULL(#crn.Month3Balance, 0)) AS 'Month3Balance',
				SUM(#crn.TotalActual) AS 'TotalAmount',
				SUM(#crn.TotalBudget) AS 'TotalBudget',
				SUM(#crn.YTDActual) AS 'YTDAmount',
				SUM(#crn.YTDBudget) AS 'YTDBudget'	

			FROM #ConsolodatedReturnNumbers #crn				
			GROUP BY #crn.GLAccountID, #crn.GLAccountName, #crn.GLAccountNumber
			ORDER BY #crn.GLAccountNumber
	END
						
END
GO
