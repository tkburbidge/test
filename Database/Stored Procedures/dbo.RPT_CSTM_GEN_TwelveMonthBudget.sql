SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_CSTM_GEN_TwelveMonthBudget] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 1,
	@propertyIDs GuidCollection READONLY, 	
	@accountingBasis nvarchar(10) = null,
	@budgetAccountingPeriodID uniqueidentifier = null,
	@actualAccountingPeriodID uniqueidentifier = null,
	@budgetsOnly bit = 0,	
	@byProperty bit = 0,
	@glAccountIDs GuidCollection READONLY, -- NEW, if empty pull in all GL Account IDs
	@includeDefaultAccountingBook bit = 1,
	@accountingBookIDs GuidCollection READONLY,
	@alternateBudgetIDs GuidCollection READONLY
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
		CashAlternateBudgetID uniqueidentifier NULL,
		AccrualAlternateBudgetID uniqueidentifier NULL)
		
	CREATE TABLE #MonthSequencers (
		Sequence int identity,
		AccountingPeriodID uniqueidentifier not null)
		
	CREATE TABLE #MonthSequencers2 (
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
		
	CREATE TABLE #AccountingBooks (
		AccountingBookID uniqueidentifier not null)
		
	CREATE TABLE #GLAccounts (
		GLAccountID uniqueidentifier not null)
	
	INSERT #MonthSequencers			-- Need ot take into account the logic from the other 12 month to make sure we don't pull back more than we should
		SELECT [MyAP].AccountingPeriodID 
			FROM (SELECT TOP 12 AccountingPeriodID, EndDate
					  FROM AccountingPeriod
					  WHERE EndDate <= (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @budgetAccountingPeriodID)
					    AND AccountID = @accountID
					  ORDER BY EndDate DESC) AS [MyAP]
			ORDER BY [MyAP].EndDate 
					  
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
				
--select * from #PropertiesAndDates order by PropertyID, MonthSequence

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

			
	DELETE FROM #MonthSequencers
	DELETE FROM #PropertiesAndDates
	
	
	INSERT #MonthSequencers2			-- Need ot take into account the logic from the other 12 month to make sure we don't pull back more than we should
		SELECT [MyAP].AccountingPeriodID 
			FROM (SELECT TOP 12 AccountingPeriodID, EndDate
					  FROM AccountingPeriod
					  WHERE EndDate <= (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @actualAccountingPeriodID)
					    AND AccountID = @accountID
					  ORDER BY EndDate DESC) AS [MyAP]
			ORDER BY [MyAP].EndDate 
					  
	INSERT #PropertiesAndDates 
		SELECT	pap.PropertyID,
				#ms.AccountingPeriodID,
				pap.PropertyAccountingPeriodID,
				pap.StartDate,
				pap.EndDate,
				#ms.Sequence
			FROM @propertyIDs pIDs
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID
				INNER JOIN #MonthSequencers2 #ms ON pap.AccountingPeriodID = #ms.AccountingPeriodID		

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
		Month2Actual money					null,
		Month2Budget money					null,
		Month3Actual money					null,
		Month3Budget money					null,
		Month4Actual money					null,
		Month4Budget money					null,
		Month5Actual money					null,
		Month5Budget money					null,
		Month6Actual money					null,
		Month6Budget money					null,
		Month7Actual money					null,
		Month7Budget money					null,
		Month8Actual money					null,
		Month8Budget money					null,
		Month9Actual money					null,
		Month9Budget money					null,
		Month10Actual money					null,
		Month10Budget money					null,
		Month11Actual money					null,
		Month11Budget money					null,
		Month12Actual money					null,
		Month12Budget money					null,
		TotalActual money					null,
		TotalBudget money					null)	
		
	INSERT #ConsolodatedReturnNumbers
		SELECT	DISTINCT
				#pad.PropertyID,
				gla.GLAccountID,
				gla.Number,
				gla.Name,
				gla.GLAccountType,
				null, null, null, null, null, null, null, null, null, null, null, null, 
				null, null, null, null, null, null, null, null, null, null, null, null,
				null, null
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

	UPDATE #ConsolodatedReturnNumbers SET Month4Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 4), 0)
					
	UPDATE #ConsolodatedReturnNumbers SET Month5Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 5), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month6Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 6), 0)
				
	UPDATE #ConsolodatedReturnNumbers SET Month7Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 7), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month8Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 8), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month9Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 9), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month10Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 10), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month11Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 11), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month12Actual = ISNULL((SELECT CASE WHEN #ConsolodatedReturnNumbers.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income') THEN -Actual ELSE Actual END
																FROM #Actuals #a
																WHERE #a.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #a.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #a.MonthSequence = 12), 0)





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

	UPDATE #ConsolodatedReturnNumbers SET Month4Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 4), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month5Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 5), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month6Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 6), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month7Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 7), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month8Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 8), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month9Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 9), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month10Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 10), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month11Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 11), 0)

	UPDATE #ConsolodatedReturnNumbers SET Month12Budget = ISNULL((SELECT Budget
																FROM #Budgets #b
																WHERE #b.PropertyID = #ConsolodatedReturnNumbers.PropertyID
																	AND #b.GLAccountID = #ConsolodatedReturnNumbers.GLAccountID
																	AND #b.MonthSequence = 12), 0)
	
	

	UPDATE #ConsolodatedReturnNumbers SET TotalBudget = Month1Budget + Month2Budget + Month3Budget + Month4Budget +
														Month5Budget + Month6Budget + Month7Budget + Month8Budget +
														Month9Budget + Month10Budget + Month11Budget + Month12Budget
	
	UPDATE #ConsolodatedReturnNumbers SET TotalActual = Month1Actual + Month2Actual + Month3Actual + Month4Actual +
														Month5Actual + Month6Actual + Month7Actual + Month8Actual +
														Month9Actual + Month10Actual + Month11Actual + Month12Actual
	

	IF (@byProperty = 1)
	BEGIN													    
		
		SELECT * FROM #ConsolodatedReturnNumbers
	END
	ELSE
	BEGIN
		SELECT
				#crn.GLAccountNumber AS 'GLNumber',
				#crn.GLAccountName 'GLName',
				#crn.GLAccountID,
				SUM(#crn.Month1Actual) AS 'Month1Actual',
				SUM(#crn.Month1Budget) AS 'Month1Budget',
				SUM(#crn.Month2Actual) AS 'Month2Actual',
				SUM(#crn.Month2Budget) AS 'Month2Budget',
				SUM(#crn.Month3Actual) AS 'Month3Actual',
				SUM(#crn.Month3Budget) AS 'Month3Budget',
				SUM(#crn.Month4Actual) AS 'Month4Actual',
				SUM(#crn.Month4Budget) AS 'Month4Budget',
				SUM(#crn.Month5Actual) AS 'Month5Actual',
				SUM(#crn.Month5Budget) AS 'Month5Budget',
				SUM(#crn.Month6Actual) AS 'Month6Actual',
				SUM(#crn.Month6Budget) AS 'Month6Budget',
				SUM(#crn.Month7Actual) AS 'Month7Actual',
				SUM(#crn.Month7Budget) AS 'Month7Budget',
				SUM(#crn.Month8Actual) AS 'Month8Actual',
				SUM(#crn.Month8Budget) AS 'Month8Budget',
				SUM(#crn.Month9Actual) AS 'Month9Actual',
				SUM(#crn.Month9Budget) AS 'Month9Budget',
				SUM(#crn.Month10Actual) AS 'Month10Actual',
				SUM(#crn.Month10Budget) AS 'Month10Budget',
				SUM(#crn.Month11Actual) AS 'Month11Actual',
				SUM(#crn.Month11Budget) AS 'Month11Budget',
				SUM(#crn.Month12Actual) AS 'Month12Actual',
				SUM(#crn.Month12Budget) AS 'Month12Budget',
				SUM(#crn.TotalActual) AS 'TotalActual',
				SUM(#crn.TotalBudget) AS 'TotalBudget'
				--#ybn.YearBudget AS 'AnnualBudget'
			FROM #ConsolodatedReturnNumbers #crn				
			GROUP BY #crn.GLAccountID, #crn.GLAccountName, #crn.GLAccountNumber
			ORDER BY #crn.GLAccountNumber
	END
						
END
GO
