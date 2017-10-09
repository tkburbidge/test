SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 10, 2015
-- Description:	This gets a bunch of info about every GLAccount to populate the super generic custom financial report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_GEN_GLAccountBalances] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyIDs GuidCollection READONLY, 
	@accountingBasis nvarchar(15) = null,
	@accountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null,
	@includePOs bit = 0,	
	@alternateChartOfAccountsID uniqueidentifier = null,
	@byProperty bit = 0,
	--@parameterGLAccountTypes StringCollection READONLY,
	@includeDefaultAccountingBook bit = 1,
	@accountingBookIDs GuidCollection READONLY,
	@glAccountIDs GuidCollection READONLY,
	@alternateBudgetIDs GuidCollection READONLY
AS

DECLARE @glAccountTypes StringCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	CREATE TABLE #GLAccountIDs (
		GLAccountID uniqueidentifier
	)
	
	IF ((SELECT COUNT(*) FROM @glAccountIDs) = 0)
	BEGIN
		INSERT INTO #GLAccountIDs SELECT GLAccountID FROM GLAccount WHERE AccountID = @accountID
	END 
	ELSE
	BEGIN
		INSERT INTO #GLAccountIDs SELECT Value from @glAccountIDs
	END	
	
	CREATE TABLE #MyTempYTDTable (
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		YTDAmount money null,
		YTDBudget money null,
		YTDBudgetNote nvarchar(MAX))
		
	CREATE TABLE #MyTempMonthTable (
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		MonthAmount money null,
		MonthBudget money null,
		MonthBudgetNotes nvarchar(MAX))
		
	CREATE TABLE #MyTempBalanceTable (
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		Balance money null)
		
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier null,
		StartDate date null,
		EndDate date null,
		YearStartMonth int null,
		FiscalYearStartDate date null,
		FiscalYearEndDate date null,
		CashAlternateBudgetID uniqueidentifier NULL,
		AccrualAlternateBudgetID uniqueidentifier NULL
		)
		
	CREATE TABLE #AccountingBooks (
		AccountingBookID uniqueidentifier NOT NULL)

	CREATE TABLE #AnnualBudget (
		GLAccountID uniqueidentifier not null,
		Budget money null)
		
	INSERT #PropertiesAndDates
		SELECT	pIDs.Value, 
				@accountingPeriodID,
				COALESCE(pap.StartDate, @startDate),
				COALESCE(pap.EndDate, @endDate),
				prop.FiscalYearStartMonth,
				null,
				null,
				null,
				null
			FROM @propertyIDs pIDs
				INNER JOIN Property prop ON pIDs.Value = prop.PropertyID 
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	
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

	IF (@accountingPeriodID IS NULL)
	BEGIN
		-- Update the accounting period for each property to be the Accounting Period
		-- of the end date passed in
		UPDATE #pads
			SET #pads.AccountingPeriodID = pap.AccountingPeriodID
		FROM #PropertiesAndDates #pads
			INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyID = #pads.PropertyID
		WHERE pap.StartDate <= #pads.EndDate
			AND pap.EndDate >= #pads.EndDate
			AND pap.AccountID = @accountID
	END

	-- Set the fiscal year start date to be the start date for the calculated accounting period
	UPDATE #PropertiesAndDates 
		SET FiscalYearStartDate = (SELECT dbo.GetFiscalYearStartDate(@accountID, #PropertiesAndDates.AccountingPeriodID, #PropertiesAndDates.PropertyID))
	WHERE #PropertiesAndDates.AccountingPeriodID IS NOT NULL
	
	INSERT #AccountingBooks
		SELECT Value FROM @accountingBookIDs

	IF ('55555555-5555-5555-5555-555555555555' IN (SELECT AccountingBookID FROM #AccountingBooks))
	BEGIN
		SET @includeDefaultAccountingBook = 1
	END
	
	IF (@byProperty = 1)
	BEGIN
		SELECT 'Noop'
	END
	ELSE
	BEGIN

		INSERT INTO #MyTempBalanceTable
			SELECT je.GLAccountID, null, SUM(je.Amount)
					FROM JournalEntry je
						INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
						INNER JOIN GLAccount gl ON gl.GLAccountID = je.GLAccountID			
						INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
						INNER JOIN #GLAccountIDs #gl ON #gl.GLAccountID = je.GLAccountID
						LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
					WHERE
						t.TransactionDate <= #pad.EndDate
						AND je.AccountingBasis = @accountingBasis
						AND gl.GLAccountType IN ('Bank', 'Accounts Receivable', 'Other Current Asset', 'Fixed Asset', 'Other Asset', 'Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity')					
						AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
			GROUP BY je.GLAccountID	
		OPTION (RECOMPILE)

		-- Calculate YTD values
		INSERT INTO #MyTempYTDTable
			SELECT je.GLAccountID, null, SUM(je.Amount), null, null
					FROM JournalEntry je
						INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID						
						INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
						INNER JOIN #GLAccountIDs #gl ON #gl.GLAccountID =je.GLAccountID
						LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
					WHERE
						t.TransactionDate <= #pad.EndDate
						AND t.TransactionDate >= #pad.FiscalYearStartDate						
						AND je.AccountingBasis = @accountingBasis						
						-- Don't include closing the year entries
						AND t.Origin NOT IN ('Y', 'E')
						AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
			GROUP BY je.GLAccountID	
		OPTION (RECOMPILE)

		INSERT INTO #MyTempYTDTable
			SELECT #gl.GLAccountID, null, 0, null, null
			FROM #GLAccountIDs #gl
				LEFT JOIN #MyTempYTDTable #y ON #y.GLAccountID = #gl.GLAccountID
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
														WHERE b.GLAccountID = #MyTempYTDTable.GLAccountID
															AND b.PropertyAccountingPeriodID IN (SELECT DISTINCT pap.PropertyAccountingPeriodID
																									FROM PropertyAccountingPeriod pap
																									INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																									WHERE
																										pap.StartDate >= #pads.FiscalYearStartDate
																										AND pap.EndDate <= #pads.EndDate))		
		END
		ELSE
		BEGIN
			UPDATE #MyTempYTDTable SET YTDBudget = (SELECT SUM(ab.Amount)
														FROM AlternateBudget ab
															INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
															INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID 
																		AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
														WHERE ab.GLAccountID = #MyTempYTDTable.GLAccountID
														  AND ab.PropertyAccountingPeriodID IN (SELECT DISTINCT pap2.PropertyAccountingPeriodID
																									FROM PropertyAccountingPeriod pap2
																										INNER JOIN #PropertiesAndDates #pads2 ON #pads2.PropertyID = pap2.PropertyID
																									WHERE pap2.StartDate >= #pads2.FiscalYearStartDate
																									  AND pap2.EndDate <= #pads2.EndDate))		
		END

		-- Month value is really the period selected or the date range selected		
		INSERT INTO #MyTempMonthTable
			SELECT je.GLAccountID, null, SUM(je.Amount), null, null
			FROM JournalEntry je
				INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
				--INNER JOIN #Properties p ON p.PropertyID = t.PropertyID
				INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
				INNER JOIN #GLAccountIDs #gl ON #gl.GLAccountID =je.GLAccountID
				LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
			WHERE t.TransactionDate <= #pad.EndDate
				AND t.TransactionDate >= #pad.StartDate
				-- Don't include closing the year entries
				AND t.Origin NOT IN ('Y', 'E')	
				AND je.AccountingBasis = @accountingBasis		
				AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)									 			
			GROUP BY je.GLAccountID		
		OPTION (RECOMPILE)									  	

		
		INSERT INTO #MyTempMonthTable
			SELECT #gl.GLAccountID, null, 0, null, null
			FROM #GLAccountIDs #gl
				LEFT JOIN #MyTempMonthTable #m ON #m.GLAccountID = #gl.GLAccountID
			WHERE #m.GLAccountID IS NULL


		-- Set the "MonthBudget" to be the budget for all the months
		-- where the end date of the month occurs in the given date range
		IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
		BEGIN
			UPDATE #MyTempMonthTable SET MonthBudget = (SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
																END 
															FROM Budget b
															WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																									FROM PropertyAccountingPeriod pap
																									INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																									WHERE pap.EndDate >= #pads.StartDate
																										AND pap.EndDate <= #pads.EndDate)
																AND b.GLAccountID = #MyTempMonthTable.GLAccountID)
		END
		ELSE
		BEGIN
			UPDATE #MyTempMonthTable SET MonthBudget = (SELECT SUM(ab.Amount)
														FROM AlternateBudget ab
															INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
															INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID 
																		AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
														WHERE ab.GLAccountID = #MyTempMonthTable.GLAccountID
														  AND ab.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																									FROM PropertyAccountingPeriod pap2
																										INNER JOIN #PropertiesAndDates #pads2 ON #pads2.PropertyID = pap2.PropertyID
																									WHERE pap2.EndDate >= #pads2.StartDate
																										AND pap2.EndDate <= #pads2.EndDate))		
		END


		IF ((SELECT COUNT(*) FROM @propertyIDs) > 1) 
		BEGIN	
			IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))			
			BEGIN								  
				UPDATE #MyTempMonthTable SET MonthBudgetNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
														FROM Budget b
														INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
														INNER JOIN Property p ON pap.PropertyID = p.PropertyID
														WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																										FROM PropertyAccountingPeriod pap
																										INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																										WHERE pap.EndDate >= #pads.StartDate
																											AND pap.EndDate <= #pads.EndDate)
																AND b.GLAccountID = #MyTempMonthTable.GLAccountID
																AND b.Notes IS NOT NULL
																AND b.Notes <> ''
														ORDER BY p.Abbreviation
														FOR XML PATH ('')), 1, 2, ''))
					OPTION (RECOMPILE)
			END
			ELSE
			BEGIN
				UPDATE #MyTempMonthTable SET MonthBudgetNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + ab.Notes)
														FROM AlternateBudget ab
															INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
															INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
																		AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
															INNER JOIN Property p ON pap.PropertyID = p.PropertyID
														WHERE ab.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																										FROM PropertyAccountingPeriod pap
																										INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																										WHERE pap.EndDate >= #pads.StartDate
																											AND pap.EndDate <= #pads.EndDate)
																AND ab.GLAccountID = #MyTempMonthTable.GLAccountID
																AND ab.Notes IS NOT NULL
																AND ab.Notes <> ''
														ORDER BY p.Abbreviation
														FOR XML PATH ('')), 1, 2, ''))
					OPTION (RECOMPILE)
			END			
		END
		ELSE
		BEGIN
			IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
			BEGIN
				UPDATE #MyTempMonthTable SET MonthBudgetNotes = (SELECT STUFF((SELECT '; ' + b.Notes
																FROM Budget b
																INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																INNER JOIN Property p ON pap.PropertyID = p.PropertyID
																	WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																												FROM PropertyAccountingPeriod pap
																												INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																												WHERE pap.EndDate >= #pads.StartDate
																													AND pap.EndDate <= #pads.EndDate)
																		AND b.GLAccountID = #MyTempMonthTable.GLAccountID
																		FOR XML PATH ('')), 1, 2, ''))
			END
			ELSE
			BEGIN
				UPDATE #MyTempMonthTable SET MonthBudgetNotes = (SELECT STUFF((SELECT '; ' + ab.Notes
																FROM AlternateBudget ab
																	INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																	INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
																					AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
																	INNER JOIN Property p ON pap.PropertyID = p.PropertyID
																WHERE ab.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																											FROM PropertyAccountingPeriod pap
																											INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																											WHERE pap.EndDate >= #pads.StartDate
																												AND pap.EndDate <= #pads.EndDate)
																	AND ab.GLAccountID = #MyTempMonthTable.GLAccountID
																	FOR XML PATH ('')), 1, 2, ''))
			END
		END
		
		
		CREATE TABLE #YearPAPs (
			PropertyID uniqueidentifier not null,
			PropertyAccountingPeriodID uniqueidentifier not null)
		
		UPDATE #PropertiesAndDates SET FiscalYearEndDate = (SELECT dbo.GetFiscalYearEndDate(#PropertiesAndDates.PropertyID, @accountingPeriodID))
		
		INSERT #YearPAPs
			SELECT DISTINCT pap.PropertyID, pap.PropertyAccountingPeriodID
				FROM PropertyAccountingPeriod pap
					INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
				WHERE pap.EndDate > #pad.FiscalYearStartDate
				  AND pap.EndDate <= #pad.FiscalYearEndDate

		IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
		BEGIN
			INSERT #AnnualBudget
				SELECT	bud.GLAccountID, SUM(CASE WHEN (@accountingBasis = 'Accrual') THEN bud.AccrualBudget ELSE bud.CashBudget END)
					FROM #YearPAPs #ypaps
						INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyAccountingPeriodID = #ypaps.PropertyAccountingPeriodID					
						INNER JOIN Budget bud ON pap.PropertyAccountingPeriodID = bud.PropertyAccountingPeriodID
						INNER JOIN #GLAccountIDs #glIDs ON bud.GLAccountID = #glIDs.GLAccountID				
					GROUP BY bud.GLAccountID
		END
		ELSE
		BEGIN
			INSERT #AnnualBudget
				SELECT	ab.GLAccountID, SUM(ab.Amount)
					FROM #YearPAPs #ypaps
						INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyAccountingPeriodID = #ypaps.PropertyAccountingPeriodID					
						INNER JOIN AlternateBudget ab ON pap.PropertyAccountingPeriodID = ab.PropertyAccountingPeriodID
						INNER JOIN #GLAccountIDs #glIDs ON ab.GLAccountID = #glIDs.GLAccountID				
					GROUP BY ab.GLAccountID
		END

	END
	
	
	SELECT 
			gl.Number AS 'GLNumber',
			gl.Name AS 'GLName',
			gl.GLAccountType AS 'GLType',
			CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#b.Balance, 0)
				ELSE ISNULL(#b.Balance, 0)
			END AS 'Balance',
			CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#m.MonthAmount, 0)
				ELSE ISNULL(#m.MonthAmount, 0)
			END AS 'MonthAmount',			   
			ISNULL(#m.MonthBudget, 0) AS 'MonthBudget', 
			#m.MonthBudgetNotes,
			CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#y.YTDAmount, 0)
				ELSE ISNULL(#y.YTDAmount, 0)
			END AS 'YTDAmount', 
			ISNULL(#y.YTDBudget, 0) AS 'YTDBudget',			
			gl.GLAccountID AS 'GLAccountID',
			ISNULL(#ab.Budget, 0) AS 'AnnualBudget'
	FROM GLAccount gl
		INNER JOIN #GLAccountIDs #gl ON #gl.GLAccountID = gl.GLAccountID
		LEFT JOIN #MyTempBalanceTable #b ON #b.GLAccountID = gl.GLAccountID
		LEFT JOIN #MyTempYTDTable #y ON #y.GLAccountID = gl.GLAccountID
		LEFT JOIN #MyTempMonthTable #m ON #m.GLAccountID = gl.GLAccountID		
		LEFT JOIN #AnnualBudget #ab ON #gl.GLAccountID = #ab.GLAccountID
	ORDER BY gl.Number

								    
END
GO
