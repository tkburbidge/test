SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 10, 2015
-- Description:	This gets a bunch of info about every GLAccount to populate the super generic custom financial report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_GEN_PeriodYTDComparison] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyIDs GuidCollection READONLY, 
	@accountingBasis nvarchar(15) = null,
	@accountingPeriodID1 uniqueidentifier = null,
	@accountingPeriodID2 uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null,
	@startDate2 date = null,
	@endDate2 date = null,
	@includePOs bit = 0,	
	@alternateChartOfAccountsID uniqueidentifier = null,
	@byProperty bit = 0,
	@includeDefaultAccountingBook bit = 1,
	@accountingBookIDs GuidCollection READONLY,
	@glAccountIDs GuidCollection READONLY,
	@tags StringCollection READONLY,		-- This could include 'BALANCE', 'YTD', 'PERIOD'
	@alternateBudgetIDs GuidCollection READONLY
AS

DECLARE @glAccountTypes StringCollection
DECLARE @includePeriod bit = 0
DECLARE @includeYTD bit = 0
DECLARE @includeBalance bit = 0
DECLARE @includePeriodMinus bit = 0

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	IF (('Balance' IN (SELECT Value FROM @tags)) OR
		('PriorBalance' IN (SELECT Value FROM @tags)))
	BEGIN
		SET @includeBalance = 1
	END
	
	IF (('YTDAmount' IN (SELECT Value FROM @tags)) OR
		('YTDBudget' IN (SELECT Value FROM @tags)) OR
		('PriorYTDAmount' IN (SELECT Value FROM @tags)) OR
		('PriorYTDBudget' IN (SELECT Value FROM @tags)))
	BEGIN
		SET @includeYTD = 1
	END
	
	IF (('MonthAmount' IN (SELECT Value FROM @tags)) OR
		('MonthBudget' IN (SELECT Value FROM @tags)) OR
		('MonthBudgetNotes' IN (SELECT Value FROM @tags)) OR
		('PriorMonthAmount' IN (SELECT Value FROM @tags)) OR
		('PriorMonthBudget' IN (SELECT Value FROM @tags)) OR
		('PriorMonthBudgetNotes' IN (SELECT Value FROM @tags)))
	BEGIN
		SET @includePeriod = 1
	END
	
	IF (('MonthMinusOneAmount' IN (SELECT Value FROM @tags)) OR
		('MonthMinusTwoAmount' IN (SELECT Value FROM @tags)) OR
		('MonthMinusThreeAmount' IN (SELECT Value FROM @tags)))
	BEGIN
		SET @includePeriodMinus = 1
	END

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
		
	CREATE TABLE #MyTempYTDTable2 (
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		YTDAmount2 money null,
		YTDBudget2 money null,
		YTDBudgetNote2 nvarchar(MAX))
		
	CREATE TABLE #MyTempMonthTable (
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		MonthAmount money null,
		MonthBudget money null,
		MonthBudgetNotes nvarchar(MAX))
		
	CREATE TABLE #MyTempMonthTable2 (
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		MonthAmount2 money null,
		MonthBudget2 money null,
		MonthBudgetNotes2 nvarchar(MAX))
		
	CREATE TABLE #MyTempBalanceTable (
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		Balance money null)
		
	CREATE TABLE #MyTempBalanceTable2 (
		GLAccountID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		Balance2 money null)

	CREATE TABLE #MyTempMinusTable (
		PropertyID uniqueidentifier			 null,
		GLAccountID uniqueidentifier		not null,		
		MonthMinusOneAmount money					null,	
		MonthMinusTwoAmount money					null,		
		MonthMinusThreeAmount money					null)	
		
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		AccountingPeriodID1 uniqueidentifier,
		StartDate1 date null,
		EndDate1 date null,
		YearStartMonth1 int null,
		FiscalYearStartDate1 date null,
		AccountingPeriodID2 uniqueidentifier,
		StartDate2 date null,
		EndDate2 date null,
		YearStartMonth2 int null,
		FiscalYearStartDate2 date null,
		CashAlternateBudgetID uniqueidentifier null,
		AccrualAlternateBudgetID uniqueidentifier null
		)
		
	CREATE TABLE #AccountingBooks (
		AccountingBookID uniqueidentifier NOT NULL)
		
	INSERT #PropertiesAndDates
		SELECT	pIDs.Value, 
				@accountingPeriodID1,
				COALESCE(pap1.StartDate, @startDate),
				COALESCE(pap1.EndDate, @endDate),
				prop.FiscalYearStartMonth,
				null,
				@accountingPeriodID2,
				COALESCE(pap2.StartDate, @startDate2),
				COALESCE(pap2.EndDate, @endDate2),
				prop.FiscalYearStartMonth,
				null,
				null,
				null
			FROM @propertyIDs pIDs
				INNER JOIN Property prop ON pIDs.Value = prop.PropertyID 
				LEFT JOIN PropertyAccountingPeriod pap1 ON pIDs.Value = pap1.PropertyID AND pap1.AccountingPeriodID = @accountingPeriodID1
				LEFT JOIN PropertyAccountingPeriod pap2 ON pIDs.Value = pap2.PropertyID AND pap2.AccountingPeriodID = @accountingPeriodID2
	
	IF (@accountingPeriodID1 IS NULL OR @accountingPeriodID2 IS NULL)
	BEGIN
		-- Update the accounting period for each property to be the Accounting Period
		-- of the end date passed in
		UPDATE #pads
			SET #pads.AccountingPeriodID1 = pap.AccountingPeriodID
		FROM #PropertiesAndDates #pads
			INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyID = #pads.PropertyID
		WHERE pap.StartDate <= #pads.EndDate1
			AND pap.EndDate >= #pads.EndDate1
			--AND pap.AccountID = @accountID

		-- Update the accounting period for each property to be the Accounting Period
		-- of the end date passed in
		UPDATE #pads
			SET #pads.AccountingPeriodID2 = pap.AccountingPeriodID
		FROM #PropertiesAndDates #pads
			INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyID = #pads.PropertyID
		WHERE pap.StartDate <= #pads.EndDate2
			AND pap.EndDate >= #pads.EndDate2
			--AND pap.AccountID = @accountID
	END
	
	-- Set the fiscal year start date to be the start date for the calculated accounting period
	UPDATE #PropertiesAndDates 
		SET FiscalYearStartDate1 = (SELECT dbo.GetFiscalYearStartDate(@accountID, #PropertiesAndDates.AccountingPeriodID1, #PropertiesAndDates.PropertyID)),
		    FiscalYearStartDate2 = (SELECT dbo.GetFiscalYearStartDate(@accountID, #PropertiesAndDates.AccountingPeriodID2, #PropertiesAndDates.PropertyID))
	WHERE #PropertiesAndDates.AccountingPeriodID1 IS NOT NULL
		AND #PropertiesAndDates.AccountingPeriodID2 IS NOT NULL

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

	
	IF (@includeBalance = 1)
	BEGIN
		INSERT INTO #MyTempBalanceTable
			SELECT je.GLAccountID, t.PropertyID, SUM(je.Amount)
					FROM JournalEntry je
						INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
						INNER JOIN GLAccount gl ON gl.GLAccountID = je.GLAccountID			
						INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
						INNER JOIN #GLAccountIDs #gl ON #gl.GLAccountID = je.GLAccountID
						LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
					WHERE
						t.TransactionDate <= #pad.EndDate1
						AND je.AccountingBasis = @accountingBasis
						AND gl.GLAccountType IN ('Bank', 'Accounts Receivable', 'Other Current Asset', 'Fixed Asset', 'Other Asset', 'Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity')					
						AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
			GROUP BY je.GLAccountID, t.PropertyID
		OPTION (RECOMPILE)
			
		INSERT INTO #MyTempBalanceTable2
			SELECT je.GLAccountID, t.PropertyID, SUM(je.Amount)
					FROM JournalEntry je
						INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
						INNER JOIN GLAccount gl ON gl.GLAccountID = je.GLAccountID			
						INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
						INNER JOIN #GLAccountIDs #gl ON #gl.GLAccountID = je.GLAccountID
						LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
					WHERE
						t.TransactionDate <= #pad.EndDate2
						AND je.AccountingBasis = @accountingBasis
						AND gl.GLAccountType IN ('Bank', 'Accounts Receivable', 'Other Current Asset', 'Fixed Asset', 'Other Asset', 'Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity')					
						AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
			GROUP BY je.GLAccountID, t.PropertyID
		OPTION (RECOMPILE)			
	END			-- END IF 'Balance'
			
	IF (@includeYTD = 1)
	BEGIN
		INSERT INTO #MyTempYTDTable
			SELECT je.GLAccountID, t.PropertyID, SUM(je.Amount), null, null
					FROM JournalEntry je
						INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID						
						INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
						INNER JOIN #GLAccountIDs #gl ON #gl.GLAccountID =je.GLAccountID
						LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
					WHERE
						t.TransactionDate <= #pad.EndDate1
						AND t.TransactionDate >= #pad.FiscalYearStartDate1						
						AND je.AccountingBasis = @accountingBasis						
						-- Don't include closing the year entries
						AND t.Origin NOT IN ('Y', 'E')
						AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
			GROUP BY je.GLAccountID, t.PropertyID	
		OPTION (RECOMPILE)

		INSERT INTO #MyTempYTDTable
			SELECT #gl.GLAccountID, #pad.PropertyID, 0, null, null
			FROM #GLAccountIDs #gl
				INNER JOIN #PropertiesAndDates #pad ON 1 = 1
				LEFT JOIN #MyTempYTDTable #y ON #y.GLAccountID = #gl.GLAccountID AND #y.PropertyID = #pad.PropertyID
			WHERE #y.GLAccountID IS NULL

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
																						INNER JOIN #PropertiesAndDates p ON p.PropertyID = pap.PropertyID
																						WHERE
																							pap.StartDate >= p.FiscalYearStartDate1
																							AND pap.EndDate <= p.EndDate1
																							AND pap.PropertyID = #MyTempYTDTable.PropertyID))
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
																						INNER JOIN #PropertiesAndDates p2 ON p2.PropertyID = pap2.PropertyID
																						WHERE
																							pap2.StartDate >= p2.FiscalYearStartDate1
																							AND pap2.EndDate <= p2.EndDate1
																							AND pap2.PropertyID = #MyTempYTDTable.PropertyID))
		END
																						  
		INSERT INTO #MyTempYTDTable2
			SELECT je.GLAccountID, t.PropertyID, SUM(je.Amount), null, null
					FROM JournalEntry je
						INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID						
						INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
						INNER JOIN #GLAccountIDs #gl ON #gl.GLAccountID =je.GLAccountID
						LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
					WHERE
						t.TransactionDate <= #pad.EndDate2
						AND t.TransactionDate >= #pad.FiscalYearStartDate2						
						AND je.AccountingBasis = @accountingBasis						
						-- Don't include closing the year entries
						AND t.Origin NOT IN ('Y', 'E')
						AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)
			GROUP BY je.GLAccountID, t.PropertyID
		OPTION (RECOMPILE)

		INSERT INTO #MyTempYTDTable2
			SELECT #gl.GLAccountID, #pad.PropertyID, 0, null, null
			FROM #GLAccountIDs #gl
				INNER JOIN #PropertiesAndDates #pad ON 1 = 1
				LEFT JOIN #MyTempYTDTable2 #y ON #y.GLAccountID = #gl.GLAccountID AND #y.PropertyID = #pad.PropertyID
			WHERE #y.GLAccountID IS NULL

		IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
		BEGIN
			UPDATE #MyTempYTDTable2 SET YTDBudget2 = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											FROM Budget b
											WHERE b.GLAccountID = #MyTempYTDTable2.GLAccountID
												AND b.PropertyAccountingPeriodID IN (SELECT DISTINCT pap.PropertyAccountingPeriodID
																						FROM PropertyAccountingPeriod pap
																						INNER JOIN #PropertiesAndDates p ON p.PropertyID = pap.PropertyID
																						WHERE
																							pap.StartDate >= p.FiscalYearStartDate2
																							AND pap.EndDate <= p.EndDate2
																							AND pap.PropertyID = #MyTempYTDTable2.PropertyID))																							  
		END
		ELSE
		BEGIN
			UPDATE #MyTempYTDTable2 SET YTDBudget2 = (SELECT SUM(ab.Amount)
											FROM AlternateBudget ab
												INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
												INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
															AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
											WHERE ab.GLAccountID = #MyTempYTDTable2.GLAccountID
												AND ab.PropertyAccountingPeriodID IN (SELECT DISTINCT pap2.PropertyAccountingPeriodID
																						FROM PropertyAccountingPeriod pap2
																							INNER JOIN #PropertiesAndDates p2 ON p2.PropertyID = pap2.PropertyID
																						WHERE pap2.StartDate >= p2.FiscalYearStartDate2
																						  AND pap2.EndDate <= p2.EndDate2
																						  AND pap2.PropertyID = #MyTempYTDTable2.PropertyID))								
		END
	END		
		

	IF (@includePeriod = 1)
	BEGIN
		INSERT INTO #MyTempMonthTable
			SELECT je.GLAccountID, t.PropertyID, SUM(je.Amount), null, null
			FROM JournalEntry je
				INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
				--INNER JOIN #Properties p ON p.PropertyID = t.PropertyID
				INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
				INNER JOIN #GLAccountIDs #gl ON #gl.GLAccountID =je.GLAccountID
				LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
			WHERE t.TransactionDate <= #pad.EndDate1
				AND t.TransactionDate >= #pad.StartDate1
				-- Don't include closing the year entries
				AND t.Origin NOT IN ('Y', 'E')	
				AND je.AccountingBasis = @accountingBasis		
				AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)									 			
			GROUP BY je.GLAccountID, t.PropertyID
		OPTION (RECOMPILE)									  

		INSERT INTO #MyTempMonthTable2
			SELECT je.GLAccountID, t.PropertyID, SUM(je.Amount), null, null
			FROM JournalEntry je
				INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
				--INNER JOIN #Properties p ON p.PropertyID = t.PropertyID
				INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
				INNER JOIN #GLAccountIDs #gl ON #gl.GLAccountID =je.GLAccountID
				LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
			WHERE t.TransactionDate <= #pad.EndDate2
				AND t.TransactionDate >= #pad.StartDate2
				-- Don't include closing the year entries
				AND t.Origin NOT IN ('Y', 'E')	
				AND je.AccountingBasis = @accountingBasis		
				AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL) OR #ab.AccountingBookID IS NOT NULL)									 			
			GROUP BY je.GLAccountID, t.PropertyID
		OPTION (RECOMPILE)							
		

		INSERT INTO #MyTempMonthTable
			SELECT #gl.GLAccountID, #pad.PropertyID, 0, null, null
			FROM #GLAccountIDs #gl
				INNER JOIN #PropertiesAndDates #pad ON 1 = 1
				LEFT JOIN #MyTempMonthTable #m ON #m.GLAccountID = #gl.GLAccountID AND #m.PropertyID = #pad.PropertyID
			WHERE #m.GLAccountID IS NULL
				
		INSERT INTO #MyTempMonthTable2
			SELECT #gl.GLAccountID, #pad.PropertyID, 0, null, null
			FROM #GLAccountIDs #gl
				INNER JOIN #PropertiesAndDates #pad ON 1 = 1
				LEFT JOIN #MyTempMonthTable2 #m ON #m.GLAccountID = #gl.GLAccountID AND #m.PropertyID = #pad.PropertyID
			WHERE #m.GLAccountID IS NULL				

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
																									WHERE pap.EndDate >= #pads.StartDate1
																										AND pap.EndDate <= #pads.EndDate1
																										AND pap.PropertyID = #MyTempMonthTable.PropertyID)
																AND b.GLAccountID = #MyTempMonthTable.GLAccountID)
																  

			UPDATE #MyTempMonthTable2 SET MonthBudget2 = (SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
																END 
															FROM Budget b
															WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																									FROM PropertyAccountingPeriod pap
																									INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																									WHERE pap.EndDate >= #pads.StartDate2
																										AND pap.EndDate <= #pads.EndDate2
																										AND pap.PropertyID = #MyTempMonthTable2.PropertyID)
																AND b.GLAccountID = #MyTempMonthTable2.GLAccountID)	
		END
		ELSE
		BEGIN
			UPDATE #MyTempMonthTable SET MonthBudget = (SELECT SUM(ab.Amount)
															FROM AlternateBudget ab
																INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
																			AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
															WHERE ab.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																									FROM PropertyAccountingPeriod pap
																									INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																									WHERE pap.EndDate >= #pads.StartDate1
																										AND pap.EndDate <= #pads.EndDate1
																										AND pap.PropertyID = #MyTempMonthTable.PropertyID)
																AND ab.GLAccountID = #MyTempMonthTable.GLAccountID)
																  

			UPDATE #MyTempMonthTable2 SET MonthBudget2 = (SELECT SUM(ab.Amount)
															FROM AlternateBudget ab
																INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
																			AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
															WHERE ab.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																									FROM PropertyAccountingPeriod pap
																									INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																									WHERE pap.EndDate >= #pads.StartDate2
																										AND pap.EndDate <= #pads.EndDate2
																										AND pap.PropertyID = #MyTempMonthTable2.PropertyID)
																AND ab.GLAccountID = #MyTempMonthTable2.GLAccountID)			
		END																				  															  

			IF (@byProperty = 1 AND @accountingPeriodID1 IS NOT NULL AND @accountingPeriodID2 IS NOT NULL)
			BEGIN
				IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
				BEGIN
					UPDATE #MyTempMonthTable SET MonthBudgetNotes =  (SELECT b.Notes
																		FROM Budget b
																			INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																			INNER JOIN Property p ON pap.PropertyID = p.PropertyID
																		WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																											FROM PropertyAccountingPeriod pap
																											INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																											WHERE pap.EndDate >= #pads.StartDate1
																												AND pap.EndDate <= #pads.EndDate1)
																		  AND b.GLAccountID = #MyTempMonthTable.GLAccountID
																		  AND p.PropertyID = #MyTempMonthTable.PropertyID
																		  AND b.Notes IS NOT NULL
																		  AND b.Notes <> '')
						OPTION (RECOMPILE)		

					UPDATE #MyTempMonthTable2 SET MonthBudgetNotes2 = (SELECT b.Notes
																			FROM Budget b
																				INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																				INNER JOIN Property p ON pap.PropertyID = p.PropertyID
																			WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																												FROM PropertyAccountingPeriod pap
																												INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																												WHERE pap.EndDate >= #pads.StartDate2
																													AND pap.EndDate <= #pads.EndDate2)
																			  AND b.GLAccountID = #MyTempMonthTable2.GLAccountID
																			  AND p.PropertyID = #MyTempMonthTable2.PropertyID
																			  AND b.Notes IS NOT NULL
																			  AND b.Notes <> '')
						OPTION (RECOMPILE)	
				END
				ELSE
				BEGIN
					UPDATE #MyTempMonthTable SET MonthBudgetNotes =  (SELECT ab.Notes
																		FROM AlternateBudget ab
																			INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																			INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
																						AND (#pad.CashAlternateBudgetID = ab.YearBudgetID OR #pad.AccrualAlternateBudgetID = ab.YearBudgetID)
																			INNER JOIN Property p ON pap.PropertyID = p.PropertyID
																		WHERE ab.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																											FROM PropertyAccountingPeriod pap
																											INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																											WHERE pap.EndDate >= #pads.StartDate1
																												AND pap.EndDate <= #pads.EndDate1)
																		  AND ab.GLAccountID = #MyTempMonthTable.GLAccountID
																		  AND p.PropertyID = #MyTempMonthTable.PropertyID
																		  AND ab.Notes IS NOT NULL
																		  AND ab.Notes <> '')
						OPTION (RECOMPILE)		

					UPDATE #MyTempMonthTable2 SET MonthBudgetNotes2 = (SELECT ab.Notes
																			FROM AlternateBudget ab
																				INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																				INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
																							AND (#pad.CashAlternateBudgetID = ab.YearBudgetID OR #pad.AccrualAlternateBudgetID = ab.YearBudgetID)
																				INNER JOIN Property p ON pap.PropertyID = p.PropertyID
																			WHERE ab.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																												FROM PropertyAccountingPeriod pap
																												INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																												WHERE pap.EndDate >= #pads.StartDate2
																													AND pap.EndDate <= #pads.EndDate2)
																			  AND ab.GLAccountID = #MyTempMonthTable2.GLAccountID
																			  AND p.PropertyID = #MyTempMonthTable2.PropertyID
																			  AND ab.Notes IS NOT NULL
																			  AND ab.Notes <> '')
						OPTION (RECOMPILE)					
				END	

			END
			ELSE IF ((SELECT COUNT(*) FROM @propertyIDs) > 1) 
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
																								WHERE pap.EndDate >= #pads.StartDate1
																									AND pap.EndDate <= #pads.EndDate1)
																	AND b.GLAccountID = #MyTempMonthTable.GLAccountID
																	AND b.Notes IS NOT NULL
																	AND b.Notes <> ''
															ORDER BY p.Abbreviation
															FOR XML PATH ('')), 1, 2, ''))
					OPTION (RECOMPILE)
					
					UPDATE #MyTempMonthTable2 SET MonthBudgetNotes2 = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
															FROM Budget b
															INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
															INNER JOIN Property p ON pap.PropertyID = p.PropertyID
															WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																								FROM PropertyAccountingPeriod pap
																								INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																								WHERE pap.EndDate >= #pads.StartDate2
																									AND pap.EndDate <= #pads.EndDate2)
																	AND b.GLAccountID = #MyTempMonthTable2.GLAccountID
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
																								WHERE pap.EndDate >= #pads.StartDate1
																									AND pap.EndDate <= #pads.EndDate1)
																	AND ab.GLAccountID = #MyTempMonthTable.GLAccountID
																	AND ab.Notes IS NOT NULL
																	AND ab.Notes <> ''
															ORDER BY p.Abbreviation
															FOR XML PATH ('')), 1, 2, ''))
					OPTION (RECOMPILE)
					
					UPDATE #MyTempMonthTable2 SET MonthBudgetNotes2 = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + ab.Notes)
															FROM AlternateBudget ab
																INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID 
																			AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
																INNER JOIN Property p ON pap.PropertyID = p.PropertyID
															WHERE ab.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																								FROM PropertyAccountingPeriod pap
																								INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
																								WHERE pap.EndDate >= #pads.StartDate2
																									AND pap.EndDate <= #pads.EndDate2)
																	AND ab.GLAccountID = #MyTempMonthTable2.GLAccountID
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
																													INNER JOIN #PropertiesAndDates p ON p.PropertyID = pap.PropertyID
																													WHERE AccountingPeriodID = @accountingPeriodID1)
																			AND b.GLAccountID = #MyTempMonthTable.GLAccountID
																			FOR XML PATH ('')), 1, 2, ''))
																		  
					UPDATE #MyTempMonthTable2 SET MonthBudgetNotes2 = (SELECT STUFF((SELECT '; ' + b.Notes
																	FROM Budget b
																	INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																	INNER JOIN Property p ON pap.PropertyID = p.PropertyID
																		WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																													FROM PropertyAccountingPeriod pap
																													INNER JOIN #PropertiesAndDates p ON p.PropertyID = pap.PropertyID
																													WHERE AccountingPeriodID = @accountingPeriodID2)
																			AND b.GLAccountID = #MyTempMonthTable2.GLAccountID
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
																													INNER JOIN #PropertiesAndDates p ON p.PropertyID = pap.PropertyID
																													WHERE AccountingPeriodID = @accountingPeriodID1)
																			AND ab.GLAccountID = #MyTempMonthTable.GLAccountID
																			FOR XML PATH ('')), 1, 2, ''))
																		  
					UPDATE #MyTempMonthTable2 SET MonthBudgetNotes2 = (SELECT STUFF((SELECT '; ' + ab.Notes
																	FROM AlternateBudget ab
																	INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																	INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
																				AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
																	INNER JOIN Property p ON pap.PropertyID = p.PropertyID
																		WHERE ab.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																													FROM PropertyAccountingPeriod pap
																													INNER JOIN #PropertiesAndDates p ON p.PropertyID = pap.PropertyID
																													WHERE AccountingPeriodID = @accountingPeriodID2)
																			AND ab.GLAccountID = #MyTempMonthTable2.GLAccountID
																			FOR XML PATH ('')), 1, 2, ''))				
				END
			END
			
	END

	IF (@includePeriodMinus = 1)
	BEGIN

		CREATE TABLE #MonthSequencers (
			[Sequence] int identity,
			AccountingPeriodID uniqueidentifier not null)				

			CREATE TABLE #Actuals (
				GLAccountID uniqueidentifier not null,
				PropertyID uniqueidentifier null,
				MonthSequence int not null,		
				Actual money null,
				EndDate date null)

			CREATE TABLE #PropertiesAndDatesMinus (
				PropertyID uniqueidentifier not null,
				AccountingPeriodID uniqueidentifier not null,
				PropertyAccountingPeriodID uniqueidentifier not null,
				StartDate date null,
				EndDate date null,
				MonthSequence int null)

		INSERT #MonthSequencers			-- Need ot take into account the logic from the other 12 month to make sure we don't pull back more than we should
			SELECT [MyAP].AccountingPeriodID 
				FROM (SELECT TOP 3 AccountingPeriodID, EndDate
							FROM AccountingPeriod
							WHERE EndDate < (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID2)
							AND AccountID = @accountID
							ORDER BY EndDate DESC) AS [MyAP]
				ORDER BY [MyAP].EndDate DESC		 			

		INSERT #PropertiesAndDatesMinus 
			SELECT	pap.PropertyID,
					#ms.AccountingPeriodID,
					pap.PropertyAccountingPeriodID,
					pap.StartDate,
					pap.EndDate,
					#ms.Sequence
				FROM @propertyIDs pIDs
					INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID
					INNER JOIN #MonthSequencers #ms ON pap.AccountingPeriodID = #ms.AccountingPeriodID


			INSERT INTO #Actuals
				SELECT 
					je.GLAccountID,
					t.PropertyID,
					#pads.MonthSequence,
					SUM(je.Amount),			
					#pads.EndDate
				FROM JournalEntry je
					INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
					INNER JOIN #PropertiesAndDatesMinus #pads ON t.PropertyID = #pads.PropertyID AND t.TransactionDate >= #pads.StartDate AND t.TransactionDate <= #pads.EndDate
					INNER JOIN #GLAccountIDs #gl ON #gl.GLAccountID = je.GLAccountID
				WHERE t.Origin NOT IN ('Y', 'E')
					AND je.AccountID = @accountID
					AND je.AccountingBasis = @accountingBasis
				GROUP BY je.GLAccountID, t.PropertyID, #pads.MonthSequence, #pads.EndDate

			INSERT INTO #MyTempMinusTable
				SELECT DISTINCT #pad.PropertyID, #gl.GLAccountID, 0, 0, 0
				FROM #GLAccountIDs #gl
					INNER JOIN #PropertiesAndDates #pad ON 1=1
					

				UPDATE #MyTempMinusTable SET MonthMinusOneAmount = ISNULL((SELECT SUM(ISNULL(Actual, 0))
																			FROM #Actuals #a
																			WHERE #a.PropertyID = #MyTempMinusTable.PropertyID
																				AND #a.GLAccountID = #MyTempMinusTable.GLAccountID
																				AND #a.MonthSequence = 1), 0)

				UPDATE #MyTempMinusTable SET MonthMinusTwoAmount = ISNULL((SELECT SUM(ISNULL(Actual, 0))
																			FROM #Actuals #a
																			WHERE #a.PropertyID = #MyTempMinusTable.PropertyID
																				AND #a.GLAccountID = #MyTempMinusTable.GLAccountID
																				AND #a.MonthSequence = 2), 0)

				UPDATE #MyTempMinusTable SET MonthMinusThreeAmount = ISNULL((SELECT SUM(ISNULL(Actual, 0))
																			FROM #Actuals #a
																			WHERE #a.PropertyID = #MyTempMinusTable.PropertyID
																				AND #a.GLAccountID = #MyTempMinusTable.GLAccountID
																				AND #a.MonthSequence = 3), 0)

	END
		
	IF (@byProperty = 1)
	BEGIN
		SELECT 
				gl.Number AS 'GLNumber',
				gl.Name AS 'GLName',
				gl.GLAccountType AS 'GLType',
				#pad.PropertyID,
				prop.Name AS 'PropertyName',
				prop.Abbreviation AS 'Abbreviation',
				CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#b.Balance, 0)
					ELSE ISNULL(#b.Balance, 0)
				END AS 'PriorBalance',
				CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#m.MonthAmount, 0)
					ELSE ISNULL(#m.MonthAmount, 0)
				END AS 'PriorMonthAmount',			   
				ISNULL(#m.MonthBudget, 0) AS 'PriorMonthBudget', 
				#m.MonthBudgetNotes AS 'PriorMonthBudgetNotes',
				CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#y.YTDAmount, 0)
					ELSE ISNULL(#y.YTDAmount, 0)
				END AS 'PriorYTDAmount', 
				ISNULL(#y.YTDBudget, 0) AS 'PriorYTDBudget',
			
				CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#b2.Balance2, 0)
					ELSE ISNULL(#b2.Balance2, 0)
				END AS 'Balance',
				CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#m2.MonthAmount2, 0)
					ELSE ISNULL(#m2.MonthAmount2, 0)
				END AS 'MonthAmount',			   
				ISNULL(#m2.MonthBudget2, 0) AS 'MonthBudget', 
				#m2.MonthBudgetNotes2 AS 'MonthBudgetNotes',
				CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#y2.YTDAmount2, 0)
					ELSE ISNULL(#y2.YTDAmount2, 0)
				END AS 'YTDAmount', 
				ISNULL(#y2.YTDBudget2, 0) AS 'YTDBudget',
				CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#mm.MonthMinusOneAmount, 0)
					ELSE ISNULL(#mm.MonthMinusOneAmount, 0)
				END AS 'MonthMinusOneAmount',
				CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#mm.MonthMinusTwoAmount, 0)
					ELSE ISNULL(#mm.MonthMinusTwoAmount, 0)
				END AS 'MonthMinusTwoAmount',
				CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#mm.MonthMinusThreeAmount, 0)
					ELSE ISNULL(#mm.MonthMinusThreeAmount, 0)
				END AS 'MonthMinusThreeAmount',
				gl.GLAccountID AS 'GLAccountID'
		FROM GLAccount gl
			INNER JOIN #GLAccountIDs #gl ON #gl.GLAccountID = gl.GLAccountID
			INNER JOIN #PropertiesAndDates #pad ON 1=1
			INNER JOIN Property prop ON #pad.PropertyID = prop.PropertyID
			LEFT JOIN #MyTempBalanceTable #b ON #b.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #b.PropertyID
			LEFT JOIN #MyTempYTDTable #y ON #y.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #y.PropertyID
			LEFT JOIN #MyTempMonthTable #m ON #m.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #m.PropertyID
			LEFT JOIN #MyTempBalanceTable2 #b2 ON #b2.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #b2.PropertyID
			LEFT JOIN #MyTempYTDTable2 #y2 ON #y2.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #y2.PropertyID
			LEFT JOIN #MyTempMonthTable2 #m2 ON #m2.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #m2.PropertyID	
			LEFT JOIN #MyTempMinusTable #mm ON #mm.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #mm.PropertyID		
		ORDER BY gl.Number
	END
	ELSE
	BEGIN

		SELECT  distinct
				gl.Number AS 'GLNumber',
				gl.Name AS 'GLName',
				gl.GLAccountType AS 'GLType',
				null AS 'PropertyID',
				null AS 'PropertyName',
				null AS 'Abbreviation',
				SUM(CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#b.Balance, 0)
						ELSE ISNULL(#b.Balance, 0)
					END) AS 'PriorBalance',
				SUM(CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#m.MonthAmount, 0)
						ELSE ISNULL(#m.MonthAmount, 0)
					END) AS 'PriorMonthAmount',			   
				SUM(ISNULL(#m.MonthBudget, 0)) AS 'PriorMonthBudget', 
				#m.MonthBudgetNotes AS 'PriorMonthBudgetNotes',
				SUM(CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#y.YTDAmount, 0)
						ELSE ISNULL(#y.YTDAmount, 0)
					END) AS 'PriorYTDAmount', 
				SUM(ISNULL(#y.YTDBudget, 0)) AS 'PriorYTDBudget',
			
				SUM(CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#b2.Balance2, 0)
						ELSE ISNULL(#b2.Balance2, 0)
					END) AS 'Balance',
				SUM(CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#m2.MonthAmount2, 0)
						ELSE ISNULL(#m2.MonthAmount2, 0)
					END) AS 'MonthAmount',			   
				SUM(ISNULL(#m2.MonthBudget2, 0)) AS 'MonthBudget', 
				#m2.MonthBudgetNotes2 AS 'MonthBudgetNotes',
				SUM(CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#y2.YTDAmount2, 0)
						ELSE ISNULL(#y2.YTDAmount2, 0)
					END) AS 'YTDAmount', 
				SUM(ISNULL(#y2.YTDBudget2, 0)) AS 'YTDBudget',
				SUM(CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#mm.MonthMinusOneAmount, 0)
						ELSE ISNULL(#mm.MonthMinusOneAmount, 0)
					END) AS 'MonthMinusOneAmount',
				SUM(CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#mm.MonthMinusTwoAmount, 0)
						ELSE ISNULL(#mm.MonthMinusTwoAmount, 0)
					END) AS 'MonthMinusTwoAmount',
				SUM(CASE WHEN (gl.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -ISNULL(#mm.MonthMinusThreeAmount, 0)
						ELSE ISNULL(#mm.MonthMinusThreeAmount, 0)
					END) AS 'MonthMinusThreeAmount',
				gl.GLAccountID AS 'GLAccountID'
		FROM GLAccount gl
			INNER JOIN #GLAccountIDs #gl ON #gl.GLAccountID = gl.GLAccountID
			INNER JOIN #PropertiesAndDates #pad ON 1=1
			INNER JOIN Property prop ON #pad.PropertyID = prop.PropertyID
			LEFT JOIN #MyTempBalanceTable #b ON #b.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #b.PropertyID
			LEFT JOIN #MyTempYTDTable #y ON #y.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #y.PropertyID
			LEFT JOIN #MyTempMonthTable #m ON #m.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #m.PropertyID
			LEFT JOIN #MyTempBalanceTable2 #b2 ON #b2.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #b2.PropertyID
			LEFT JOIN #MyTempYTDTable2 #y2 ON #y2.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #y2.PropertyID
			LEFT JOIN #MyTempMonthTable2 #m2 ON #m2.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #m2.PropertyID	
			LEFT JOIN #MyTempMinusTable #mm ON #mm.GLAccountID = #gl.GLAccountID AND #pad.PropertyID = #mm.PropertyID	
		GROUP BY gl.GLAccountID, gl.GLAccountType, gl.Name, gl.Number, #m.MonthBudgetNotes, #m2.MonthBudgetNotes2		
		ORDER BY gl.Number
	END

								    
END
GO
