SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_ACTG_TwelveMonthBudgetVarianceComparison] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@propertyIDs GuidCollection READONLY, 
	@reportName nvarchar(100) = null,
	@accountingBasis nvarchar(50) = null,
	@budgetsOnly bit = 1, 
	@accountingPeriodID uniqueidentifier = null,
	@showAllAccounts bit = 1,
	@glAccountTypes StringCollection READONLY,					-- Types to INCLUDE
	@parameterGLAccountTypes StringCollection READONLY,			-- Types to EXCLUDE, as in, we're going to build a wall around these types and not let them in.
	@excludeRestrictedGLAccounts bit = 1,
	@alternateChartOfAccountsID uniqueidentifier = null,
	@accountingBookIDs GuidCollection READONLY   --,
	--@alternateBudgetIDs GuidCollection READONLY

AS

DECLARE @earlyAccountingPeriodID uniqueidentifier = null

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PonytailComparisons (
		GLAccountNumber nvarchar(50) null,
		GLAccountName nvarchar(50) null,
		GLAccountID uniqueidentifier null,
		--IsRestrictedGLAccount bit null,
		[Type] nvarchar(50) null,
		Depth int null,
		[Path] nvarchar(max) null,
		OrderByPath nvarchar(max) null,
        SummaryParentPath nvarchar(500) null,
		ParentGLAccountNumber nvarchar(100) null,
		Month1Amount money null,
		Month1Budget money null,
		Month2Amount money null,
		Month2Budget money null,
		Month3Amount money null,
		Month3Budget money null,
		Month4Amount money null,
		Month4Budget money null,
		Month5Amount money null,
		Month5Budget money null,
		Month6Amount money null,
		Month6Budget money null,
		Month7Amount money null,
		Month7Budget money null,
		Month8Amount money null,
		Month8Budget money null,
		Month9Amount money null,
		Month9Budget money null,
		Month10Amount money null,
		Month10Budget money null,
		Month11Amount money null,
		Month11Budget money null,
		Month12Amount money null,
		Month12Budget money null,
		LastYearMonth1Amount money null,
		LastYearMonth1Budget money null,
		LastYearMonth2Amount money null,
		LastYearMonth2Budget money null,
		LastYearMonth3Amount money null,
		LastYearMonth3Budget money null,
		LastYearMonth4Amount money null,
		LastYearMonth4Budget money null,
		LastYearMonth5Amount money null,
		LastYearMonth5Budget money null,
		LastYearMonth6Amount money null,
		LastYearMonth6Budget money null,
		LastYearMonth7Amount money null,
		LastYearMonth7Budget money null,
		LastYearMonth8Amount money null,
		LastYearMonth8Budget money null,
		LastYearMonth9Amount money null,
		LastYearMonth9Budget money null,
		LastYearMonth10Amount money null,
		LastYearMonth10Budget money null,
		LastYearMonth11Amount money null,
		LastYearMonth11Budget money null,
		LastYearMonth12Amount money null,
		LastYearMonth12Budget money null,
		BudgetMonthStart int null
		)

	CREATE TABLE #EarlyPeriodResults (
		EarlyPropertyID uniqueidentifier null,
		EarlyGLAccountID uniqueidentifier null,
		EarlyGLNumber nvarchar(20) null,
		EarlyGLName nvarchar(100) null,
		EarlyDescription nvarchar(500) null,
		EarlyGLAccountType nvarchar(50) null,
		EarlyParentGLAccountID uniqueidentifier null,
		EarlyDepth int NOT NULL,
		EarlyIsLeaf bit NOT NULL,
		EarlySummaryParent bit NOT NULL,
		EarlyOrderByPath nvarchar(max) NOT NULL,
		EarlyPath  nvarchar(max) NOT NULL,
		EarlySummaryParentPath nvarchar(max),
		EarlyJanBudget money null default 0,
		EarlyJanActual money null default 0,
		EarlyJanNotes nvarchar(MAX) null,
		EarlyFebBudget money null default 0,
		EarlyFebActual money null default 0,
		EarlyFebNotes nvarchar(MAX) null,
		EarlyMarBudget money null default 0,
		EarlyMarActual money null default 0,
		EarlyMarNotes nvarchar(MAX) null,
		EarlyAprBudget money null default 0,
		EarlyAprActual money null default 0,
		EarlyAprNotes nvarchar(MAX) null,
		EarlyMayBudget money null default 0,
		EarlyMayActual money null default 0,
		EarlyMayNotes nvarchar(MAX) null,
		EarlyJunBudget money null default 0,
		EarlyJunActual money null default 0,
		EarlyJunNotes nvarchar(MAX) null,
		EarlyJulBudget money null default 0,
		EarlyJulActual money null default 0,
		EarlyJulNotes nvarchar(MAX) null,
		EarlyAugBudget money null default 0,
		EarlyAugActual money null default 0,
		EarlyAugNotes nvarchar(MAX) null,
		EarlySepBudget money null default 0,
		EarlySepActual money null default 0,
		EarlySepNotes nvarchar(MAX) null,
		EarlyOctBudget money null default 0,
		EarlyOctActual money null default 0,
		EarlyOctNotes nvarchar(MAX) null,
		EarlyNovBudget money null default 0,
		EarlyNovActual money null default 0,
		EarlyNovNotes nvarchar(MAX) null,
		EarlyDecBudget money null default 0,
		EarlyDecActual money null default 0,
		EarlyDecNotes nvarchar(MAX) null		
		)

	CREATE TABLE #LaterPeriodResults (
		LaterPropertyID uniqueidentifier NULL,	
		LaterGLAccountID uniqueidentifier NOT NULL,
		LaterNumber nvarchar(15) NOT NULL,
		LaterName nvarchar(200) NOT NULL, 
		[LaterDescription] nvarchar(500) NULL,
		LaterGLAccountType nvarchar(50) NOT NULL,
		LaterParentGLAccountID uniqueidentifier NULL,
		LaterDepth int NOT NULL,
		LaterIsLeaf bit NOT NULL,
		LaterSummaryParent bit NOT NULL,
		[LaterOrderByPath] nvarchar(max) NOT NULL,
		[LaterPath]  nvarchar(max) NOT NULL,
		LaterSummaryParentPath nvarchar(max),
		LaterJanBudget money null default 0,
		LaterJanActual money null default 0,
		LaterJanNotes nvarchar(MAX) null,
		LaterFebBudget money null default 0,
		LaterFebActual money null default 0,
		LaterFebNotes nvarchar(MAX) null,
		LaterMarBudget money null default 0,
		LaterMarActual money null default 0,
		LaterMarNotes nvarchar(MAX) null,
		LaterAprBudget money null default 0,
		LaterAprActual money null default 0,
		LaterAprNotes nvarchar(MAX) null,
		LaterMayBudget money null default 0,
		LaterMayActual money null default 0,
		LaterMayNotes nvarchar(MAX) null,
		LaterJunBudget money null default 0,
		LaterJunActual money null default 0,
		LaterJunNotes nvarchar(MAX) null,
		LaterJulBudget money null default 0,
		LaterJulActual money null default 0,
		LaterJulNotes nvarchar(MAX) null,
		LaterAugBudget money null default 0,
		LaterAugActual money null default 0,
		LaterAugNotes nvarchar(MAX) null,
		LaterSepBudget money null default 0,
		LaterSepActual money null default 0,
		LaterSepNotes nvarchar(MAX) null,
		LaterOctBudget money null default 0,
		LaterOctActual money null default 0,
		LaterOctNotes nvarchar(MAX) null,
		LaterNovBudget money null default 0,
		LaterNovActual money null default 0,
		LaterNovNotes nvarchar(MAX) null,
		LaterDecBudget money null default 0,
		LaterDecActual money null default 0,
		LaterDecNotes nvarchar(MAX) null		
		)		

	CREATE TABLE #EarlyPeriods (
		AccountingPeriodID uniqueidentifier not null,
		[Sequence] int null,
		GLAccountID uniqueidentifier null,
		Amount money null,
		Budget money null
		)
	
	CREATE TABLE #StandardYear (
		[Month] int identity,
		MonthContains nvarchar(3) null
		)

	CREATE TABLE #EvenEarlierSequencing (
		[Sequence] int identity,
		AccountingPeriodID uniqueidentifier null,
		MonthContains nvarchar(3) null
		)

	CREATE TABLE #EarlySequencing (
		[Sequence] int identity,
		AccountingPeriodID uniqueidentifier null,
		MonthContains nvarchar(3) null
		)

	CREATE TABLE #LaterSequencing (
		[Sequence] int identity,
		AccountingPeriodID uniqueidentifier null,
		MonthContains nvarchar(3) null
		)

	SET @earlyAccountingPeriodID = (SELECT TOP 1 AccountingPeriodID 
										FROM (SELECT TOP 13 *
												FROM AccountingPeriod
												WHERE StartDate <= (SELECT StartDate
																		FROM AccountingPeriod
																		WHERE AccountingPeriodID = @accountingPeriodID)
												ORDER BY StartDate DESC) [OrderedAPs]
										ORDER BY StartDate ASC)

	INSERT #StandardYear values ('Jan'), ('Feb'), ('Mar'), ('Apr'), ('May'), ('Jun'), ('Jul'), ('Aug'), ('Sep'), ('Oct'), ('Nov'), ('Dec')

	INSERT #EarlySequencing
		SELECT TOP 12 [WhatAHack].AccountingPeriodID, CAST([WhatAHack].Name AS nvarchar(3))
			FROM
				(SELECT TOP 12 *
					FROM AccountingPeriod
					WHERE EndDate <= (SELECT EndDate 
										  FROM AccountingPeriod
										  WHERE AccountingPeriodID = @earlyAccountingPeriodID)
					ORDER BY EndDate DESC) [WhatAHack]
				ORDER BY [WhatAHack].EndDate

	INSERT #LaterSequencing
		SELECT TOP 12 [WhatAHack].AccountingPeriodID, CAST([WhatAHack].Name AS nvarchar(3))
			FROM
				(SELECT TOP 12 *
					FROM AccountingPeriod
					WHERE EndDate <= (SELECT EndDate 
										  FROM AccountingPeriod
										  WHERE AccountingPeriodID = @accountingPeriodID)
					ORDER BY EndDate DESC) [WhatAHack]
				ORDER BY [WhatAHack].EndDate

	INSERT INTO #EarlyPeriodResults
		EXEC [dbo].[RPT_ACTG_TwelveMonthBudgetVariance] @propertyIDs, @reportName, @accountingBasis, @earlyAccountingPeriodID, @budgetsOnly, @glAccountTypes,
			@showAllAccounts, @alternateChartOfAccountsID, 0, @accountingBookIDs, @parameterGLAccountTypes, @excludeRestrictedGLAccounts

	INSERT INTO #LaterPeriodResults
		EXEC [dbo].[RPT_ACTG_TwelveMonthBudgetVariance] @propertyIDs, @reportName, @accountingBasis, @accountingPeriodID, @budgetsOnly, @glAccountTypes,
			@showAllAccounts, @alternateChartOfAccountsID, 0, @accountingBookIDs, @parameterGLAccountTypes, @excludeRestrictedGLAccounts

	INSERT INTO #PonytailComparisons
		SELECT	DISTINCT
				#e.EarlyGLNumber,
				#e.EarlyGLName,
				#e.EarlyGLAccountID,
				--null AS 'IsRestrictedGLAccount',				-- Need to figure this one out.
				#e.EarlyGLAccountType,
				#e.EarlyDepth,
				#e.EarlyPath,
				#e.EarlyOrderByPath,
				#e.EarlySummaryParentPath,
				glaEarlyParent.Number AS 'ParentGLAccountNumber',
				-- 48 nulls, 2x24.
				null, null, null, null, null, null, null, null, null, null, null, null,
				null, null, null, null, null, null, null, null, null, null, null, null,
				null, null, null, null, null, null, null, null, null, null, null, null,
				null, null, null, null, null, null, null, null, null, null, null, null,
				null AS 'BudgetMonthStart'
			FROM #EarlyPeriodResults #e
				--INNER JOIN #LaterPeriodResults #l ON #e.EarlyPropertyID = #l.LaterPropertyID AND #e.EarlyGLAccountID = #l.LaterGLAccountID
				INNER JOIN GLAccount glaEarlyParent ON #e.EarlyGLAccountID = glaEarlyParent.GLAccountID
		UNION 
			SELECT	DISTINCT
				#e.LaterNumber,
				#e.LaterName,
				#e.LaterGLAccountID,
				--null AS 'IsRestrictedGLAccount',				-- Need to figure this one out.
				#e.LaterGLAccountType,
				#e.LaterDepth,
				#e.LaterPath,
				#e.LaterOrderByPath,
				#e.LaterSummaryParentPath,
				glaEarlyParent.Number AS 'ParentGLAccountNumber',
				-- 48 nulls, 2x24.
				null, null, null, null, null, null, null, null, null, null, null, null,
				null, null, null, null, null, null, null, null, null, null, null, null,
				null, null, null, null, null, null, null, null, null, null, null, null,
				null, null, null, null, null, null, null, null, null, null, null, null,
				null AS 'BudgetMonthStart'
			FROM #LaterPeriodResults #e
				--INNER JOIN #LaterPeriodResults #l ON #e.EarlyPropertyID = #l.LaterPropertyID AND #e.EarlyGLAccountID = #l.LaterGLAccountID
				INNER JOIN GLAccount glaEarlyParent ON #e.LaterGLAccountID = glaEarlyParent.GLAccountID


	CREATE TABLE #MyTempBudget (
		GLAccountID uniqueidentifier not null,
		[Sequence] int not null,
		Amount money not null,
		Budget money not null)

	INSERT #MyTempBudget
		SELECT #e.EarlyGLAccountID, #es.[Sequence], #e.EarlyJanActual, #e.EarlyJanBudget
			FROM #EarlyPeriodResults #e
				INNER JOIN #EarlySequencing #es ON #es.MonthContains = 'Jan'

	INSERT #MyTempBudget
		SELECT #e.EarlyGLAccountID, #es.[Sequence], #e.EarlyFebActual, #e.EarlyFebBudget
			FROM #EarlyPeriodResults #e
				INNER JOIN #EarlySequencing #es ON #es.MonthContains = 'Feb'

	INSERT #MyTempBudget
		SELECT #e.EarlyGLAccountID, #es.[Sequence], #e.EarlyMarActual, #e.EarlyMarBudget
			FROM #EarlyPeriodResults #e
				INNER JOIN #EarlySequencing #es ON #es.MonthContains = 'Mar'

	INSERT #MyTempBudget
		SELECT #e.EarlyGLAccountID, #es.[Sequence], #e.EarlyAprActual, #e.EarlyAprBudget
			FROM #EarlyPeriodResults #e
				INNER JOIN #EarlySequencing #es ON #es.MonthContains = 'Apr'

	INSERT #MyTempBudget
		SELECT #e.EarlyGLAccountID, #es.[Sequence], #e.EarlyMayActual, #e.EarlyMayBudget
			FROM #EarlyPeriodResults #e
				INNER JOIN #EarlySequencing #es ON #es.MonthContains = 'May'

	INSERT #MyTempBudget
		SELECT #e.EarlyGLAccountID, #es.[Sequence], #e.EarlyJunActual, #e.EarlyJunBudget
			FROM #EarlyPeriodResults #e
				INNER JOIN #EarlySequencing #es ON #es.MonthContains = 'Jun'

	INSERT #MyTempBudget
		SELECT #e.EarlyGLAccountID, #es.[Sequence], #e.EarlyJulActual, #e.EarlyJulBudget
			FROM #EarlyPeriodResults #e
				INNER JOIN #EarlySequencing #es ON #es.MonthContains = 'Jul'

	INSERT #MyTempBudget
		SELECT #e.EarlyGLAccountID, #es.[Sequence], #e.EarlyAugActual, #e.EarlyAugBudget
			FROM #EarlyPeriodResults #e
				INNER JOIN #EarlySequencing #es ON #es.MonthContains = 'Aug'

	INSERT #MyTempBudget
		SELECT #e.EarlyGLAccountID, #es.[Sequence], #e.EarlySepActual, #e.EarlySepBudget
			FROM #EarlyPeriodResults #e
				INNER JOIN #EarlySequencing #es ON #es.MonthContains = 'Sep'

	INSERT #MyTempBudget
		SELECT #e.EarlyGLAccountID, #es.[Sequence], #e.EarlyOctActual, #e.EarlyOctBudget
			FROM #EarlyPeriodResults #e
				INNER JOIN #EarlySequencing #es ON #es.MonthContains = 'Oct'

	INSERT #MyTempBudget
		SELECT #e.EarlyGLAccountID, #es.[Sequence], #e.EarlyNovActual, #e.EarlyNovBudget
			FROM #EarlyPeriodResults #e
				INNER JOIN #EarlySequencing #es ON #es.MonthContains = 'Nov'

	INSERT #MyTempBudget
		SELECT #e.EarlyGLAccountID, #es.[Sequence], #e.EarlyDecActual, #e.EarlyDecBudget
			FROM #EarlyPeriodResults #e
				INNER JOIN #EarlySequencing #es ON #es.MonthContains = 'Dec'


	UPDATE #ptc SET LastYearMonth1Amount = #mtb.Amount, LastYearMonth1Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 1

	UPDATE #ptc SET LastYearMonth2Amount = #mtb.Amount, LastYearMonth2Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 2

	UPDATE #ptc SET LastYearMonth3Amount = #mtb.Amount, LastYearMonth3Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 3

	UPDATE #ptc SET LastYearMonth4Amount = #mtb.Amount, LastYearMonth4Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 4

	UPDATE #ptc SET LastYearMonth5Amount = #mtb.Amount, LastYearMonth5Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 5

	UPDATE #ptc SET LastYearMonth6Amount = #mtb.Amount, LastYearMonth6Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 6

	UPDATE #ptc SET LastYearMonth7Amount = #mtb.Amount, LastYearMonth7Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 7

	UPDATE #ptc SET LastYearMonth8Amount = #mtb.Amount, LastYearMonth8Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 8

	UPDATE #ptc SET LastYearMonth9Amount = #mtb.Amount, LastYearMonth9Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 9

	UPDATE #ptc SET LastYearMonth10Amount = #mtb.Amount, LastYearMonth10Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 10

	UPDATE #ptc SET LastYearMonth11Amount = #mtb.Amount, LastYearMonth11Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 11

	UPDATE #ptc SET LastYearMonth12Amount = #mtb.Amount, LastYearMonth12Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 12

	DELETE #MyTempBudget

	INSERT #MyTempBudget
		SELECT #l.LaterGLAccountID, #ls.[Sequence], #l.LaterJanActual, #l.LaterJanBudget
			FROM #LaterPeriodResults #l
				INNER JOIN #LaterSequencing #ls ON #ls.MonthContains = 'Jan'

	INSERT #MyTempBudget
		SELECT #l.LaterGLAccountID, #es.[Sequence], #l.LaterFebActual, #l.LaterFebBudget
			FROM #LaterPeriodResults #l
				INNER JOIN #LaterSequencing #es ON #es.MonthContains = 'Feb'

	INSERT #MyTempBudget
		SELECT #l.LaterGLAccountID, #es.[Sequence], #l.LaterMarActual, #l.LaterMarBudget
			FROM #LaterPeriodResults #l
				INNER JOIN #LaterSequencing #es ON #es.MonthContains = 'Mar'

	INSERT #MyTempBudget
		SELECT #l.LaterGLAccountID, #es.[Sequence], #l.LaterAprActual, #l.LaterAprBudget
			FROM #LaterPeriodResults #l
				INNER JOIN #LaterSequencing #es ON #es.MonthContains = 'Apr'

	INSERT #MyTempBudget
		SELECT #l.LaterGLAccountID, #es.[Sequence], #l.LaterMayActual, #l.LaterMayBudget
			FROM #LaterPeriodResults #l
				INNER JOIN #LaterSequencing #es ON #es.MonthContains = 'May'

	INSERT #MyTempBudget
		SELECT #l.LaterGLAccountID, #es.[Sequence], #l.LaterJunActual, #l.LaterJunBudget
			FROM #LaterPeriodResults #l
				INNER JOIN #LaterSequencing #es ON #es.MonthContains = 'Jun'

	INSERT #MyTempBudget
		SELECT #l.LaterGLAccountID, #es.[Sequence], #l.LaterJulActual, #l.LaterJulBudget
			FROM #LaterPeriodResults #l
				INNER JOIN #LaterSequencing #es ON #es.MonthContains = 'Jul'

	INSERT #MyTempBudget
		SELECT #l.LaterGLAccountID, #es.[Sequence], #l.LaterAugActual, #l.LaterAugBudget
			FROM #LaterPeriodResults #l
				INNER JOIN #LaterSequencing #es ON #es.MonthContains = 'Aug'

	INSERT #MyTempBudget
		SELECT #l.LaterGLAccountID, #es.[Sequence], #l.LaterSepActual, #l.LaterSepBudget
			FROM #LaterPeriodResults #l
				INNER JOIN #LaterSequencing #es ON #es.MonthContains = 'Sep'

	INSERT #MyTempBudget
		SELECT #l.LaterGLAccountID, #es.[Sequence], #l.LaterOctActual, #l.LaterOctBudget
			FROM #LaterPeriodResults #l
				INNER JOIN #LaterSequencing #es ON #es.MonthContains = 'Oct'

	INSERT #MyTempBudget
		SELECT #l.LaterGLAccountID, #es.[Sequence], #l.LaterNovActual, #l.LaterNovBudget
			FROM #LaterPeriodResults #l
				INNER JOIN #LaterSequencing #es ON #es.MonthContains = 'Nov'

	INSERT #MyTempBudget
		SELECT #l.LaterGLAccountID, #es.[Sequence], #l.LaterDecActual, #l.LaterDecBudget
			FROM #LaterPeriodResults #l
				INNER JOIN #LaterSequencing #es ON #es.MonthContains = 'Dec'

	UPDATE #ptc SET Month1Amount = #mtb.Amount, Month1Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 1

	UPDATE #ptc SET Month2Amount = #mtb.Amount, Month2Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 2

	UPDATE #ptc SET Month3Amount = #mtb.Amount, Month3Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 3

	UPDATE #ptc SET Month4Amount = #mtb.Amount, Month4Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 4

	UPDATE #ptc SET Month5Amount = #mtb.Amount, Month5Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 5

	UPDATE #ptc SET Month6Amount = #mtb.Amount, Month6Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 6

	UPDATE #ptc SET Month7Amount = #mtb.Amount, Month7Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 7

	UPDATE #ptc SET Month8Amount = #mtb.Amount, Month8Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 8

	UPDATE #ptc SET Month9Amount = #mtb.Amount, Month9Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 9

	UPDATE #ptc SET Month10Amount = #mtb.Amount, Month10Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 10

	UPDATE #ptc SET Month11Amount = #mtb.Amount, Month11Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 11

	UPDATE #ptc SET Month12Amount = #mtb.Amount, Month12Budget = #mtb.Budget
		FROM #PonytailComparisons #ptc
			INNER JOIN #MyTempBudget #mtb ON #ptc.GLAccountID = #mtb.GLAccountID AND #mtb.[Sequence] = 12

	UPDATE #PonytailComparisons SET BudgetMonthStart = (SELECT DATEPART(MONTH, MonthContains + ' 01 2020')
															FROM #EarlySequencing
															WHERE [Sequence] = 1)

	SELECT *
		FROM #PonytailComparisons
		ORDER BY OrderByPath

END

GO
