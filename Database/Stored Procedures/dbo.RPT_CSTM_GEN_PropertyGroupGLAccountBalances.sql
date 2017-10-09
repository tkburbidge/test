SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 10, 2015
-- Description:	This gets a bunch of info about every GLAccount to populate the super generic custom financial report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_GEN_PropertyGroupGLAccountBalances] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyGroupIDs GuidCollection READONLY, 
	@accountingBasis nvarchar(15) = null,
	@accountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null,
	--@glAccountIDs GuidCollection READONLY,
	@alternateChartOfAccountsID uniqueidentifier = null,
	@byPropertyGroup bit = 0,
	--@parameterGLAccountTypes StringCollection READONLY,
	@includeDefaultAccountingBook bit = 1,
	@accountingBookIDs GuidCollection READONLY,
	@monthOnly bit = 0,
	@alternateBudgetIDs GuidCollection READONLY
AS

DECLARE @glAccountTypes StringCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #AllInfo (	
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
		SummaryParentPath nvarchar(max),
		CurrentAPAmount money null,
		YTDAmount money null,
		CurrentAPBudget money null,
		YTDBudget money null,
		BudgetNotes nvarchar(MAX) null
		)		

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
		--PropertyGroupID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier null,
		StartDate date null,
		EndDate date null,
		YearStartMonth int null,
		FiscalYearStartDate date null,
		CashAlternateBudgetID uniqueidentifier NULL,
		AccrualAlternateBudgetID uniqueidentifier NULL		)
		
	CREATE TABLE #MyPropertyGroups (
		PropertyGroupID uniqueidentifier not null,
		PropertyID uniqueidentifier not null)
		
	CREATE TABLE #AccountingBooks (
		AccountingBookID uniqueidentifier NOT NULL)
		
	INSERT #PropertiesAndDates
		SELECT	DISTINCT prop.PropertyID, 
				@accountingPeriodID,
				COALESCE(pap.StartDate, @startDate),
				COALESCE(pap.EndDate, @endDate),
				prop.FiscalYearStartMonth,
				null,
				null,
				null
			FROM @propertyGroupIDs pgIDs
				INNER JOIN PropertyGroupProperty pgp ON pgp.PropertyGroupID = pgIDs.Value
				INNER JOIN Property prop ON pgp.PropertyID = prop.PropertyID 
				LEFT JOIN PropertyAccountingPeriod pap ON prop.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

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
				
	INSERT #MyPropertyGroups
		SELECT pgp.PropertyGroupID, pgp.PropertyID
			FROM PropertyGroupProperty pgp
				INNER JOIN @propertyGroupIDs pgIDs ON pgp.PropertyGroupID = pgIDs.Value
				
	INSERT #AccountingBooks
		SELECT Value FROM @accountingBookIDs

	IF ('55555555-5555-5555-5555-555555555555' IN (SELECT AccountingBookID FROM #AccountingBooks))
	BEGIN
		SET @includeDefaultAccountingBook = 1
	END
	
	INSERT @glAccountTypes 
		SELECT DISTINCT GLAccountType FROM GLAccount
						
	INSERT #AllInfo 
		SELECT 
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
			null
	    FROM GetChartOfAccounts(@accountID, @glAccountTypes)
			
	IF (@accountingPeriodID IS NULL)
	BEGIN
		UPDATE #PropertiesAndDates SET AccountingPeriodID = (SELECT AccountingPeriodID 

																FROM PropertyAccountingPeriod 
																WHERE StartDate <= @endDate
																  AND EndDate >= @endDate
																  AND PropertyID = #PropertiesAndDates.PropertyID)
	END
	
	UPDATE #PropertiesAndDates SET FiscalYearStartDate = (SELECT dbo.GetFiscalYearStartDate(@accountID, #PropertiesAndDates.AccountingPeriodID, #PropertiesAndDates.PropertyID))	

	INSERT #MyTempYTDTable
		SELECT	#allI.GLAccountID,
				#pad.PropertyID,
				SUM(MyJE.Amount),
				null,
				null
			FROM #AllInfo #allI
				INNER JOIN
							(SELECT DISTINCT PropertyID
								FROM #PropertiesAndDates) #pad ON 1=1
				LEFT JOIN 
							(SELECT je.GlaccountID, je.Amount, #pad1.PropertyID
								FROM JournalEntry je 
									INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
									INNER JOIN #PropertiesAndDates #pad1 ON t.PropertyID = #pad1.PropertyID AND t.TransactionDate >= #pad1.FiscalYearStartDate AND t.TransactionDate <= #pad1.EndDate
									LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
								WHERE je.AccountingBasis = @accountingBasis
									-- Don't include closing the year entries
									AND t.Origin <> 'Y'
								  AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL)
								    OR #ab.AccountingBookID IS NOT NULL)) [MyJE] ON #allI.GLAccountID = MyJE.GLAccountID AND #pad.PropertyID = MyJE.PropertyID
			GROUP BY #allI.GLAccountID, MyJE.GLAccountID, #pad.PropertyID 
					

		CREATE TABLE #PAPIDs ( PropertyID uniqueidentifier, PropertyAccountingPeriodID uniqueidentifier )
		INSERT INTO #PAPIDs
			SELECT DISTINCT pap.PropertyID, pap.PropertyAccountingPeriodID
			FROM PropertyAccountingPeriod pap
			INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
			WHERE
				pap.StartDate >= #pads.FiscalYearStartDate
				AND pap.EndDate <= #pads.EndDate				

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
											INNER JOIN #PAPIDs ON #PAPIDs.PropertyAccountingPeriodID = b.PropertyAccountingPeriodID AND #PAPIDs.PropertyID = #MyTempYTDTable.PropertyID	
											WHERE b.GLAccountID = #MyTempYTDTable.GLAccountID)		
		END
		ELSE
		BEGIN
			UPDATE #MyTempYTDTable SET YTDBudget = (SELECT SUM(ab.Amount)
											FROM AlternateBudget ab
												INNER JOIN #PAPIDs ON #PAPIDs.PropertyAccountingPeriodID = ab.PropertyAccountingPeriodID AND #PAPIDs.PropertyID = #MyTempYTDTable.PropertyID	
												INNER JOIN #PropertiesAndDates #pad ON #PAPIDs.PropertyID = #pad.PropertyID 
															AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)
											WHERE ab.GLAccountID = #MyTempYTDTable.GLAccountID)	
		END
			
	INSERT #MyTempMonthTable
		SELECT	#allI.GLAccountID,
				#pad1.PropertyID,
				SUM(MyJE.Amount),
				null,
				null
			FROM #AllInfo #allI
				INNER JOIN 
							(SELECT DISTINCT PropertyID	
								FROM #PropertiesAndDates) [#pad1] ON 1=1
				LEFT JOIN 
							(SELECT je.GlaccountID, je.Amount, #pad.PropertyID
								FROM JournalEntry je 
									INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
									INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
									LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
								WHERE je.AccountingBasis = @accountingBasis
									-- Don't include closing the year entries
									AND t.Origin <> 'Y'
								  AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL)
								    OR #ab.AccountingBookID IS NOT NULL)) [MyJE] ON #allI.GLAccountID = MyJE.GLAccountID AND #pad1.PropertyID = MyJE.PropertyID
			GROUP BY #allI.GLAccountID, MyJE.GLAccountID, #pad1.PropertyID --MyJE.PropertyID
					
		-- Get the Accounting Periods for the month range		
		DELETE #PAPIDs
		INSERT INTO #PAPIDs
			SELECT DISTINCT pap.PropertyID, pap.PropertyAccountingPeriodID
			FROM PropertyAccountingPeriod pap
			INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = pap.PropertyID
			WHERE pap.EndDate >= #pads.StartDate
				AND pap.EndDate <= #pads.EndDate

		-- Set the "MonthBudget" to be the budget for all the months
		-- where the end date of the month occurs in the given date range
		IF (0 = (SELECT COUNT(*) FROM #PropertiesAndDates WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
		BEGIN
			UPDATE #MyTempMonthTable SET MonthBudget = (SELECT CASE
														WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
														WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
														END 
													FROM Budget b
														INNER JOIN #PAPIDs ON #PAPIDs.PropertyAccountingPeriodID = b.PropertyAccountingPeriodID AND #PAPIDs.PropertyID = #MyTempMonthTable.PropertyID												
													WHERE b.GLAccountID = #MyTempMonthTable.GLAccountID)
		END
		ELSE
		BEGIN
			UPDATE #MyTempMonthTable SET MonthBudget = (SELECT ISNULL(SUM(ab.Amount), 0)
													FROM AlternateBudget ab
														INNER JOIN #PAPIDs ON #PAPIDs.PropertyAccountingPeriodID = ab.PropertyAccountingPeriodID AND #PAPIDs.PropertyID = #MyTempMonthTable.PropertyID	
														INNER JOIN #PropertiesAndDates #pad ON #PAPIDs.PropertyID = #pad.PropertyID
																	AND (#pad.AccrualAlternateBudgetID = ab.YearBudgetID OR #pad.CashAlternateBudgetID = ab.YearBudgetID)											
													WHERE ab.GLAccountID = #MyTempMonthTable.GLAccountID)
		END
					
			
	INSERT #MyTempBalanceTable
		SELECT	#allI.GLAccountID,
				#pad1.PropertyID,
				SUM(MyJE.Amount)
			FROM #AllInfo #allI
				INNER JOIN 
							(SELECT DISTINCT PropertyID
								FROM #PropertiesAndDates) [#pad1] ON 2=2
				LEFT JOIN 
							(SELECT je.GlaccountID, je.Amount, #pad.PropertyID
								FROM JournalEntry je 
									INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
									INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID AND t.TransactionDate <= #pad.EndDate
									LEFT JOIN #AccountingBooks #ab ON je.AccountingBookID = #ab.AccountingBookID 
								WHERE je.AccountingBasis = @accountingBasis
									-- Don't include closing the year entries
									AND t.Origin <> 'Y'

								  AND ((@includeDefaultAccountingBook = 1 AND je.AccountingBookID IS NULL)
								    OR #ab.AccountingBookID IS NOT NULL)) [MyJE] ON #allI.GLAccountID = MyJE.GLAccountID AND #pad1.PropertyID = MyJE.PropertyID
			GROUP BY #allI.GLAccountID, MyJE.GLAccountID, #pad1.PropertyID
			
	IF (@byPropertyGroup = 1)
	BEGIN
		SELECT	DISTINCT
				#pad.PropertyGroupID,
				gla.Number AS 'GLNumber',
				gla.Name AS 'GLName',
				gla.GLAccountType AS 'GLType',
				gla.GLAccountID,
				ISNULL(SUM(CASE WHEN (gla.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -#myTempMonth.MonthAmount
								ELSE #myTempMonth.MonthAmount END), 0) AS 'MonthAmount',
				ISNULL(SUM(CASE WHEN (gla.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -#myTempYTD.YTDAmount
								ELSE #myTempYTD.YTDAmount END), 0) AS 'YTDAmount',
				ISNULL(SUM(CASE WHEN (gla.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -#myTempBal.Balance
								ELSE #myTempBal.Balance END), 0) AS 'Balance',
				ISNULL(SUM(ISNULL(#myTempMonth.MonthBudget, 0)), 0) AS 'MonthBudget',

				ISNULL(SUM(ISNULL(#myTempYTD.YTDBudget, 0)), 0) AS 'YTDBudget'
			FROM #MyTempYTDTable #myTempYTD
				INNER JOIN GLAccount gla ON #myTempYTD.GLAccountID = gla.GLAccountID
				INNER JOIN #MyPropertyGroups #pad ON #pad.PropertyID = #myTempYTD.PropertyID
				INNER JOIN Property prop ON #myTempYTD.PropertyID = prop.PropertyID AND #pad.PropertyID = prop.PropertyID
				INNER JOIN #myTempMonthTable #myTempMonth ON #myTempYTD.PropertyID = #myTempMonth.PropertyID AND #myTempYTD.GLAccountID = #myTempMonth.GLAccountID
				INNER JOIN #myTempBalanceTable #myTempBal ON #myTempYTD.PropertyID = #myTempBal.PropertyID AND #myTempYTD.GLAccountID = #myTempBal.GLAccountID			
			GROUP BY #pad.PropertyGroupID, gla.GLAccountID, gla.GLAccountType, gla.Name, gla.Number
			ORDER BY gla.Number
	END
	ELSE
	BEGIN
		SELECT	DISTINCT
				null AS 'PropertyGroupID',
				gla.Number AS 'GLNumber',
				gla.Name AS 'GLName',
				gla.GLAccountType AS 'GLType',
				gla.GLAccountID,
				ISNULL(SUM(CASE WHEN (gla.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -#myTempMonth.MonthAmount
								ELSE #myTempMonth.MonthAmount END), 0) AS 'MonthAmount',
				ISNULL(SUM(CASE WHEN (gla.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -#myTempYTD.YTDAmount
								ELSE #myTempYTD.YTDAmount END), 0) AS 'YTDAmount',
				ISNULL(SUM(CASE WHEN (gla.GLAccountType IN ('Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity', 'Income', 'Other Income')) THEN -#myTempBal.Balance
								ELSE #myTempBal.Balance END), 0) AS 'Balance',
				ISNULL(SUM(ISNULL(#myTempMonth.MonthBudget, 0)), 0) AS 'MonthBudget',

				ISNULL(SUM(ISNULL(#myTempYTD.YTDBudget, 0)), 0) AS 'YTDBudget'
			FROM #MyTempYTDTable #myTempYTD
				INNER JOIN GLAccount gla ON #myTempYTD.GLAccountID = gla.GLAccountID
				INNER JOIN #myTempMonthTable #myTempMonth ON #myTempYTD.PropertyID = #myTempMonth.PropertyID AND #myTempYTD.GLAccountID = #myTempMonth.GLAccountID
				INNER JOIN #myTempBalanceTable #myTempBal ON #myTempYTD.PropertyID = #myTempBal.PropertyID AND #myTempYTD.GLAccountID = #myTempBal.GLAccountID			
			GROUP BY gla.GLAccountID, gla.GLAccountType, gla.Name, gla.Number
			ORDER BY gla.Number
		END	
			
								    
END
GO
