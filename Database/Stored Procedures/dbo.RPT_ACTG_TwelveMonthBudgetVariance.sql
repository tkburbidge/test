SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- Twelve month budget - Good

/****** Object:  StoredProcedure [dbo].[RPT_ACTG_TwelveMonthBudgetVariance]    Script Date: 09/11/2012 09:40:00 ******/
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 16, 2012
-- Description:	Gets the basic information for a variety of Financial Reports
-- =============================================
CREATE PROCEDURE [dbo].[RPT_ACTG_TwelveMonthBudgetVariance] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@reportName nvarchar(50) = null,
	@accountingBasis nvarchar(10) = null,
	@accountingPeriodID uniqueidentifier = null,
	@budgetsOnly bit = 0,
	@glAccountTypes StringCollection READONLY,
	@showAllAccounts bit = 0,
	@alternateChartOfAccountsID uniqueidentifier = null,
	@byProperty bit = 0,
	@accountingBookIDs GuidCollection READONLY,
	@parameterGLAccountTypes StringCollection READONLY,
	@excludeRestrictedGLAccounts bit = 0,
	@alternateBudgetIDs GuidCollection READONLY
AS

DECLARE @fiscalYearBegin tinyint
DECLARE @fiscalYearStartDate datetime
DECLARE @accountID bigint
DECLARE @endDate datetime
DECLARE @reportGLAccountTypes StringCollection 
DECLARE @includeDefaultAccountingBook bit = 1
DECLARE @runForOtherAccountingBooks bit = 0
DECLARE @useAlternateBudgets bit = 0

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT @accountID = AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs)
	
	CREATE TABLE #AccountingBooks (
		AccountingBookID uniqueidentifier not null)

	INSERT #AccountingBooks 
		SELECT Value FROM @accountingBookIDs

	IF ('55555555-5555-5555-5555-555555555555' IN (SELECT AccountingBookID FROM #AccountingBooks))
	BEGIN
		SET @includeDefaultAccountingBook = 1
	END
	ELSE
	BEGIN
		SET @includeDefaultAccountingBook = 0
	END

	IF ((SELECT COUNT(*) FROM #AccountingBooks WHERE AccountingBookID NOT IN ('55555555-5555-5555-5555-555555555555')) > 0)
	BEGIN
		SET @runForOtherAccountingBooks = 1
	END
	ELSE
	BEGIN
		SET @runForOtherAccountingBooks = 0
	END

	
	CREATE TABLE #AllInfo (		
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
		SummaryParentPath nvarchar(max),
		JanBudget money null default 0,
		JanActual money null default 0,
		JanNotes nvarchar(MAX) null,
		FebBudget money null default 0,
		FebActual money null default 0,
		FebNotes nvarchar(MAX) null,
		MarBudget money null default 0,
		MarActual money null default 0,
		MarNotes nvarchar(MAX) null,
		AprBudget money null default 0,
		AprActual money null default 0,
		AprNotes nvarchar(MAX) null,
		MayBudget money null default 0,
		MayActual money null default 0,
		MayNotes nvarchar(MAX) null,
		JunBudget money null default 0,
		JunActual money null default 0,
		JunNotes nvarchar(MAX) null,
		JulBudget money null default 0,
		JulActual money null default 0,
		JulNotes nvarchar(MAX) null,
		AugBudget money null default 0,
		AugActual money null default 0,
		AugNotes nvarchar(MAX) null,
		SepBudget money null default 0,
		SepActual money null default 0,
		SepNotes nvarchar(MAX) null,
		OctBudget money null default 0,
		OctActual money null default 0,
		OctNotes nvarchar(MAX) null,
		NovBudget money null default 0,
		NovActual money null default 0,
		NovNotes nvarchar(MAX) null,
		DecBudget money null default 0,
		DecActual money null default 0,
		DecNotes nvarchar(MAX) null		
		)	
		
	CREATE TABLE #AlternateInfo (	
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
		SummaryParentPath nvarchar(max),
		JanBudget money null default 0,
		JanActual money null default 0,
		JanNotes nvarchar(MAX) null,
		FebBudget money null default 0,
		FebActual money null default 0,
		FebNotes nvarchar(MAX) null,
		MarBudget money null default 0,
		MarActual money null default 0,
		MarNotes nvarchar(MAX) null,
		AprBudget money null default 0,
		AprActual money null default 0,
		AprNotes nvarchar(MAX) null,
		MayBudget money null default 0,
		MayActual money null default 0,
		MayNotes nvarchar(MAX) null,
		JunBudget money null default 0,
		JunActual money null default 0,
		JunNotes nvarchar(MAX) null,
		JulBudget money null default 0,
		JulActual money null default 0,
		JulNotes nvarchar(MAX) null,
		AugBudget money null default 0,
		AugActual money null default 0,
		AugNotes nvarchar(MAX) null,
		SepBudget money null default 0,
		SepActual money null default 0,
		SepNotes nvarchar(MAX) null,
		OctBudget money null default 0,
		OctActual money null default 0,
		OctNotes nvarchar(MAX) null,
		NovBudget money null default 0,
		NovActual money null default 0,
		NovNotes nvarchar(MAX) null,
		DecBudget money null default 0,
		DecActual money null default 0,
		DecNotes nvarchar(MAX) null		
		)		
		
	CREATE TABLE #AlternateInfoValues (	
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
		SummaryParentPath nvarchar(max),
		JanBudget money null default 0,
		JanActual money null default 0,
		JanNotes nvarchar(MAX) null,
		FebBudget money null default 0,
		FebActual money null default 0,
		FebNotes nvarchar(MAX) null,
		MarBudget money null default 0,
		MarActual money null default 0,
		MarNotes nvarchar(MAX) null,
		AprBudget money null default 0,
		AprActual money null default 0,
		AprNotes nvarchar(MAX) null,
		MayBudget money null default 0,
		MayActual money null default 0,
		MayNotes nvarchar(MAX) null,
		JunBudget money null default 0,
		JunActual money null default 0,
		JunNotes nvarchar(MAX) null,
		JulBudget money null default 0,
		JulActual money null default 0,
		JulNotes nvarchar(MAX) null,
		AugBudget money null default 0,
		AugActual money null default 0,
		AugNotes nvarchar(MAX) null,
		SepBudget money null default 0,
		SepActual money null default 0,
		SepNotes nvarchar(MAX) null,
		OctBudget money null default 0,
		OctActual money null default 0,
		OctNotes nvarchar(MAX) null,
		NovBudget money null default 0,
		NovActual money null default 0,
		NovNotes nvarchar(MAX) null,
		DecBudget money null default 0,
		DecActual money null default 0,
		DecNotes nvarchar(MAX) null		
		)						
		
	CREATE NONCLUSTERED INDEX [IX_#AllInfo_GLAccount] ON [#AllInfo] 
	(
		[GLAccountID] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
		
	CREATE TABLE #Properties (
		PropertyID uniqueidentifier NOT NULL,
		PropEndDate [Date] NULL)
		
	INSERT #Properties
		SELECT Value, pap.EndDate
			FROM @propertyIDs p
				INNER JOIN PropertyAccountingPeriod pap ON p.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			
		
	CREATE TABLE #MyPAPs (
		PropertyAccountingPeriodID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		DatePartInt int not null,
		Closed bit not null,
		StartDate date not null,
		EndDate date not null,
		CashAlternateBudgetID uniqueidentifier null,
		AccrualAlternateBudgetID uniqueidentifier null)
		
	DECLARE @minEndDate DATE = (SELECT TOP 1 DATEADD(MONTH, -11, CAST(DATEPART(Year, ap.EndDate) AS nvarchar(4)) + '-' + CAST(DATEPART(MONTH, ap.EndDate) AS nvarchar(4)) + '-1')
								FROM AccountingPeriod ap
								WHERE ap.AccountingPeriodID = @accountingPeriodID)

	INSERT #MyPAPs 
		SELECT TOP ((SELECT COUNT(*) FROM #Properties) * 12) pap1.PropertyAccountingPeriodID, pap1.PropertyID, DATEPART(MONTH, pap1.EndDate), pap1.Closed, pap1.StartDate, pap1.EndDate, null, null
			FROM PropertyAccountingPeriod pap1
				INNER JOIN PropertyAccountingPeriod papEnd ON papEnd.AccountingPeriodID = @accountingPeriodID AND papEnd.PropertyID = pap1.PropertyID
				INNER JOIN #Properties #p ON #p.PropertyID = pap1.PropertyID
			WHERE pap1.EndDate <= papEnd.EndDate
				AND pap1.EndDate >= @minEndDate
			ORDER BY pap1.EndDate DESC

	UPDATE #MyPAPs SET CashAlternateBudgetID = (SELECT YearBudgetID
													FROM YearBudget
													WHERE PropertyID = #MyPAPs.PropertyID
														AND AccountingBasis = 'Cash'
														AND @accountingBasis = 'Cash'
														AND YearBudgetID IN (SELECT Value FROM @alternateBudgetIDs))

	UPDATE #MyPAPs SET AccrualAlternateBudgetID = (SELECT YearBudgetID
														FROM YearBudget
														WHERE PropertyID = #MyPAPs.PropertyID
															AND AccountingBasis = 'Accrual'
															AND @accountingBasis = 'Accrual'
															AND YearBudgetID IN (SELECT Value FROM @alternateBudgetIDs))

	SET @useAlternateBudgets = (SELECT CAST((SELECT COUNT(*) FROM #MyPAPs WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL) AS bit))
		
		
	IF (@reportName = 'Cash Flow Statement')
	BEGIN
		INSERT @reportGLAccountTypes VALUES ('Accounts Receivable')
		INSERT @reportGLAccountTypes VALUES ('Other Current Asset')
		INSERT @reportGLAccountTypes VALUES ('Other Asset')
		INSERT @reportGLAccountTypes VALUES ('Accounts Payable')				
		INSERT @reportGLAccountTypes VALUES ('Other Current Liability')						
		INSERT @reportGLAccountTypes VALUES ('Long Term Liability')						
		INSERT @reportGLAccountTypes VALUES ('Fixed Asset')				
		INSERT @reportGLAccountTypes VALUES ('Equity')				
						
		INSERT #AllInfo 
			SELECT	#p.PropertyID,
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
					0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null,
					0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null
				FROM GetChartOfAccounts(@accountID, @reportGLAccountTypes)
					LEFT JOIN #Properties #p ON @byProperty = 1
			  
		--DECLARE @maxParentOrderBy int
		--SET @maxParentOrderBy = (SELECT MAX(OrderBy1) FROM #AllInfo)

	END
	ELSE IF (@reportName = 'Income Statement')
	BEGIN
		INSERT @reportGLAccountTypes VALUES ('Income')
		INSERT @reportGLAccountTypes VALUES ('Expense')
		INSERT @reportGLAccountTypes VALUES ('Other Income')				
		INSERT @reportGLAccountTypes VALUES ('Other Expense')
		INSERT @reportGLAccountTypes VALUES ('Non-Operating Expense')								


		IF (@alternateChartOfAccountsID IS NULL)
		BEGIN
			INSERT #AllInfo 
				SELECT	#p.PropertyID,
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
						0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null,
						0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null
					FROM GetChartOfAccounts(@accountID, @reportGLAccountTypes)
						LEFT JOIN #Properties #p ON @byProperty = 1
		END
		ELSE
		BEGIN
				INSERT #AllInfo 
				SELECT	#p.PropertyID,
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
						0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null,
						0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null
							FROM GetChartOfAccountsByAlternate(@accountID, @glAccountTypes, @alternateChartOfAccountsID)		
								LEFT JOIN #Properties #p ON @byProperty = 1
								
		END
	END
	ELSE IF (@reportName = 'Cash Flow Statement Expanded')
	BEGIN
		INSERT @reportGLAccountTypes VALUES ('Income')
		INSERT @reportGLAccountTypes VALUES ('Expense')
		INSERT @reportGLAccountTypes VALUES ('Other Income')				
		INSERT @reportGLAccountTypes VALUES ('Other Expense')
		INSERT @reportGLAccountTypes VALUES ('Non-Operating Expense')		

		INSERT @reportGLAccountTypes VALUES ('Accounts Receivable')
		INSERT @reportGLAccountTypes VALUES ('Other Current Asset')
		INSERT @reportGLAccountTypes VALUES ('Other Asset')
		INSERT @reportGLAccountTypes VALUES ('Accounts Payable')				
		INSERT @reportGLAccountTypes VALUES ('Other Current Liability')						
		INSERT @reportGLAccountTypes VALUES ('Long Term Liability')						
		INSERT @reportGLAccountTypes VALUES ('Fixed Asset')				
		INSERT @reportGLAccountTypes VALUES ('Equity')				
						
		INSERT #AllInfo 
			SELECT	#p.PropertyID,
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
					0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null,
					0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null
				FROM GetChartOfAccounts(@accountID, @reportGLAccountTypes)
					LEFT JOIN #Properties #p ON @byProperty = 1
			  
		--DECLARE @maxParentOrderBy int
		--SET @maxParentOrderBy = (SELECT MAX(OrderBy1) FROM #AllInfo)

	END
	ELSE IF ((SELECT COUNT(*) FROM @glAccountTypes) > 0)
	BEGIN
		INSERT #AllInfo 
			SELECT	#p.PropertyID,
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
					0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null,
					0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null
			    FROM GetChartOfAccounts(@accountID, @glAccountTypes)
					LEFT JOIN #Properties #p ON @byProperty = 1
	END

	-- If we provided a list of types to filter this report by, then 
	-- delete out any that shouldn't be in there
	IF ((SELECT COUNT(*) FROM @parameterGLAccountTypes) > 0) 
	BEGIN
		DELETE FROM #AllInfo
		WHERE GLAccountType NOT IN (SELECT Value FROM @parameterGLAccountTypes)
	END

	IF (@excludeRestrictedGLAccounts = 1)
	BEGIN		
		DELETE #ai
			FROM #AllInfo #ai
				JOIN GLAccountPropertyRestriction glpr on glpr.GLAccountID = #ai.GLAccountID
			WHERE glpr.PropertyID = #ai.PropertyID
			  AND glpr.AccountID = @accountID
			--	LEFT JOIN GLAccountProperty glp ON glp.GLAccountID = #ai.GLAccountID -- 
			--	LEFT JOIN GLAccountProperty glp2 ON glp2.GLAccountID = #ai.GLAccountID  AND glp2.PropertyID = #ai.PropertyID				
			--WHERE glp.GLAccountPropertyID IS NOT NULL -- There is a restriction for this GL
			--	AND glp2.GLAccountPropertyID IS NULL  -- And there is not an entry for this property and GL
			--	AND #ai.PropertyID IS NOT NULL		  -- And we are doing this by property
	END
		  
    SELECT @endDate = EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID	
   
    IF (@budgetsOnly = 0)
    BEGIN  		  

		IF (@includeDefaultAccountingBook = 1)
		BEGIN
			UPDATE #AllInfo SET JanActual = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0 AND pap.DatePartInt = 1
														WHERE t.TransactionDate >= pap.StartDate													
														  AND t.TransactionDate <= pap.EndDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND je.AccountingBasis = @accountingBasis)

			UPDATE #AllInfo SET JanActual = ISNULL(JanActual, 0) + ISNULL((SELECT CASE
																	WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																	WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																	END
															 FROM Budget b
																INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1 AND pap.DatePartInt = 1 
															 WHERE 
															   b.GLAccountID = #AllInfo.GLAccountID), 0)		
		END

		IF (@runForOtherAccountingBooks = 1)
		BEGIN
			UPDATE #AllInfo SET JanActual = ISNULL(JanActual, 0) + ISNULL((SELECT SUM(je.Amount)
																	FROM JournalEntry je
																		INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																		INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.DatePartInt = 1
																		INNER JOIN #AccountingBooks #ab ON #ab.AccountingBookID = je.AccountingBookID
																	WHERE t.TransactionDate >= pap.StartDate													
																		AND t.TransactionDate <= pap.EndDate
																		-- Don't include closing the year entries
																		AND t.Origin NOT IN ('Y', 'E')
																		AND je.GLAccountID = #AllInfo.GLAccountID
																		AND je.AccountingBasis = @accountingBasis), 0)
		END
	END
			
	IF (@useAlternateBudgets = 0)
	BEGIN																
		UPDATE #AllInfo SET JanBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND DatePartInt = 1 
											 WHERE 
												b.GLAccountID = #AllInfo.GLAccountID)	
	END		
	ELSE
	BEGIN
		UPDATE #AllInfo SET JanBudget = (SELECT SUM(ab.Amount)
											 FROM AlternateBudget ab
												 INNER JOIN #MyPAPs #myPAP ON ab.PropertyAccountingPeriodID = #myPAP.PropertyAccountingPeriodID AND DatePartInt = 1
																					AND (#myPAP.AccrualAlternateBudgetID = ab.YearBudgetID OR #myPAP.CashAlternateBudgetID = ab.YearBudgetID)
											 WHERE ab.GLAccountID = #AllInfo.GLAccountID)
	END											
																			
	--UPDATE #AllInfo SET JanNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
	--									 FROM Budget b
	--										INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	--										INNER JOIN Property p ON pap.PropertyID = p.PropertyID
	--										INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--									 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--									   AND b.GLAccountID = #AllInfo.GLAccountID
	--									   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
	--																		FROM AccountingPeriod 
	--																		WHERE DATEPART(month, EndDate) = 1
	--																		  AND EndDate <= @endDate
	--																		  AND AccountID = ap.AccountID
	--																		ORDER BY EndDate DESC)
	--									 FOR XML PATH ('')), 1, 2, ''))																					

    IF (@budgetsOnly = 0)
    BEGIN  		  
		IF (@includeDefaultAccountingBook = 1)
		BEGIN
			UPDATE #AllInfo SET FebActual = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0 AND pap.DatePartInt = 2
														WHERE t.TransactionDate >= pap.StartDate													
														  AND t.TransactionDate <= pap.EndDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND je.AccountingBasis = @accountingBasis)

			UPDATE #AllInfo SET FebActual = ISNULL(FebActual, 0) + ISNULL((SELECT CASE
																	WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																	WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																	END
															 FROM Budget b
																INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1 AND pap.DatePartInt = 2 
															 WHERE 
															   b.GLAccountID = #AllInfo.GLAccountID), 0)		
		END

		IF (@runForOtherAccountingBooks = 1)
		BEGIN
			UPDATE #AllInfo SET FebActual = ISNULL(FebActual, 0) + ISNULL((SELECT SUM(je.Amount)
																	FROM JournalEntry je
																		INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																		INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.DatePartInt = 2
																		INNER JOIN #AccountingBooks #ab ON #ab.AccountingBookID = je.AccountingBookID
																	WHERE t.TransactionDate >= pap.StartDate													
																		AND t.TransactionDate <= pap.EndDate
																		-- Don't include closing the year entries
																		AND t.Origin NOT IN ('Y', 'E')
																		AND je.GLAccountID = #AllInfo.GLAccountID
																		AND je.AccountingBasis = @accountingBasis), 0)
		END
	END
			
	IF (@useAlternateBudgets = 0)
	BEGIN																
		UPDATE #AllInfo SET FebBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND DatePartInt = 2 
											 WHERE 
												b.GLAccountID = #AllInfo.GLAccountID)	
	END
	ELSE
	BEGIN
		UPDATE #AllInfo SET FebBudget = (SELECT SUM(ab.Amount)
											 FROM AlternateBudget ab
												 INNER JOIN #MyPAPs #myPAP ON ab.PropertyAccountingPeriodID = #myPAP.PropertyAccountingPeriodID AND DatePartInt = 2
																					AND (#myPAP.AccrualAlternateBudgetID = ab.YearBudgetID OR #myPAP.CashAlternateBudgetID = ab.YearBudgetID)
											 WHERE ab.GLAccountID = #AllInfo.GLAccountID)
	END													
																			
																			
	--UPDATE #AllInfo SET FebNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
	--									 FROM Budget b
	--										INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	--										INNER JOIN Property p ON pap.PropertyID = p.PropertyID
	--										INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--									 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--									   AND b.GLAccountID = #AllInfo.GLAccountID
	--									   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
	--																		FROM AccountingPeriod 
	--																		WHERE DATEPART(month, EndDate) = 2
	--																		  AND EndDate <= @endDate
	--																		  AND AccountID = ap.AccountID
	--																		ORDER BY EndDate DESC)
	--									 FOR XML PATH ('')), 1, 2, ''))																									

    IF (@budgetsOnly = 0)
    BEGIN  		  
		IF (@includeDefaultAccountingBook = 1)
		BEGIN
			UPDATE #AllInfo SET MarActual = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0 AND pap.DatePartInt = 3
														WHERE t.TransactionDate >= pap.StartDate													
														  AND t.TransactionDate <= pap.EndDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND je.AccountingBasis = @accountingBasis)

			UPDATE #AllInfo SET MarActual = ISNULL(MarActual, 0) + ISNULL((SELECT CASE
																	WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																	WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																	END
															 FROM Budget b
																INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1 AND pap.DatePartInt = 3 
															 WHERE 
															   b.GLAccountID = #AllInfo.GLAccountID), 0)		
		END

		IF (@runForOtherAccountingBooks = 1)
		BEGIN
			UPDATE #AllInfo SET MarActual = ISNULL(MarActual, 0) + ISNULL((SELECT SUM(je.Amount)
																	FROM JournalEntry je
																		INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																		INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.DatePartInt = 3
																		INNER JOIN #AccountingBooks #ab ON #ab.AccountingBookID = je.AccountingBookID
																	WHERE t.TransactionDate >= pap.StartDate													
																		AND t.TransactionDate <= pap.EndDate
																		-- Don't include closing the year entries
																		AND t.Origin NOT IN ('Y', 'E')
																		AND je.GLAccountID = #AllInfo.GLAccountID
																		AND je.AccountingBasis = @accountingBasis), 0)
		END
	END
						
	IF (@useAlternateBudgets = 0)
	BEGIN													
		UPDATE #AllInfo SET MarBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND DatePartInt = 3 
											 WHERE 
												b.GLAccountID = #AllInfo.GLAccountID)	
	END		
	ELSE
	BEGIN
		UPDATE #AllInfo SET MarBudget = (SELECT SUM(ab.Amount)
											 FROM AlternateBudget ab
												 INNER JOIN #MyPAPs #myPAP ON ab.PropertyAccountingPeriodID = #myPAP.PropertyAccountingPeriodID AND DatePartInt = 3
																					AND (#myPAP.AccrualAlternateBudgetID = ab.YearBudgetID OR #myPAP.CashAlternateBudgetID = ab.YearBudgetID)
											 WHERE ab.GLAccountID = #AllInfo.GLAccountID)
	END											
																			
																			
	--UPDATE #AllInfo SET MarNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
	--									 FROM Budget b
	--										INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	--										INNER JOIN Property p ON pap.PropertyID = p.PropertyID
	--										INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--									 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--									   AND b.GLAccountID = #AllInfo.GLAccountID
	--									   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
	--																		FROM AccountingPeriod 
	--																		WHERE DATEPART(month, EndDate) = 3
	--																		  AND EndDate <= @endDate
	--																		  AND AccountID = ap.AccountID
	--																		ORDER BY EndDate DESC)
	--									 FOR XML PATH ('')), 1, 2, ''))																												

    IF (@budgetsOnly = 0)
    BEGIN  		
		IF (@includeDefaultAccountingBook = 1)
		BEGIN  
			UPDATE #AllInfo SET AprActual = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0 AND pap.DatePartInt = 4
														WHERE t.TransactionDate >= pap.StartDate													
														  AND t.TransactionDate <= pap.EndDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND je.AccountingBasis = @accountingBasis)

			UPDATE #AllInfo SET AprActual = ISNULL(AprActual, 0) + ISNULL((SELECT CASE
																	WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																	WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																	END
															 FROM Budget b
																INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1 AND pap.DatePartInt = 4 
															 WHERE 
															   b.GLAccountID = #AllInfo.GLAccountID), 0)		
		END

		IF (@runForOtherAccountingBooks = 1)
		BEGIN
			UPDATE #AllInfo SET AprActual = ISNULL(AprActual, 0) + ISNULL((SELECT SUM(je.Amount)
																	FROM JournalEntry je
																		INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																		INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.DatePartInt = 4
																		INNER JOIN #AccountingBooks #ab ON #ab.AccountingBookID = je.AccountingBookID
																	WHERE t.TransactionDate >= pap.StartDate													
																		AND t.TransactionDate <= pap.EndDate
																		-- Don't include closing the year entries
																		AND t.Origin NOT IN ('Y', 'E')
																		AND je.GLAccountID = #AllInfo.GLAccountID
																		AND je.AccountingBasis = @accountingBasis), 0)
		END
	END
		
	IF (@useAlternateBudgets = 0)
	BEGIN																	
		UPDATE #AllInfo SET AprBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND DatePartInt = 4 
											 WHERE 
												b.GLAccountID = #AllInfo.GLAccountID)	
	END
	ELSE
	BEGIN
		UPDATE #AllInfo SET AprBudget = (SELECT SUM(ab.Amount)
											 FROM AlternateBudget ab
												 INNER JOIN #MyPAPs #myPAP ON ab.PropertyAccountingPeriodID = #myPAP.PropertyAccountingPeriodID AND DatePartInt = 4
																					AND (#myPAP.AccrualAlternateBudgetID = ab.YearBudgetID OR #myPAP.CashAlternateBudgetID = ab.YearBudgetID)
											 WHERE ab.GLAccountID = #AllInfo.GLAccountID)
	END
														
																			
																			
	--UPDATE #AllInfo SET AprNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
	--									 FROM Budget b
	--										INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	--										INNER JOIN Property p ON pap.PropertyID = p.PropertyID
	--										INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--									 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--									   AND b.GLAccountID = #AllInfo.GLAccountID
	--									   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
	--																		FROM AccountingPeriod 
	--																		WHERE DATEPART(month, EndDate) = 4
	--																		  AND EndDate <= @endDate
	--																		  AND AccountID = ap.AccountID
	--																		ORDER BY EndDate DESC)
	--									 FOR XML PATH ('')), 1, 2, ''))		
										 
    IF (@budgetsOnly = 0)
    BEGIN  	
		IF (@includeDefaultAccountingBook = 1)
			BEGIN	  
			UPDATE #AllInfo SET MayActual = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0 AND pap.DatePartInt = 5
														WHERE t.TransactionDate >= pap.StartDate													
														  AND t.TransactionDate <= pap.EndDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND je.AccountingBasis = @accountingBasis)

			UPDATE #AllInfo SET MayActual = ISNULL(MayActual, 0) + ISNULL((SELECT CASE
																	WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																	WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																	END
															 FROM Budget b
																INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1 AND pap.DatePartInt = 5 
															 WHERE 
															   b.GLAccountID = #AllInfo.GLAccountID), 0)		
		END

		IF (@runForOtherAccountingBooks = 1)
		BEGIN
			UPDATE #AllInfo SET MayActual = ISNULL(MayActual, 0) + ISNULL((SELECT SUM(je.Amount)
																	FROM JournalEntry je
																		INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																		INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.DatePartInt = 5
																		INNER JOIN #AccountingBooks #ab ON #ab.AccountingBookID = je.AccountingBookID
																	WHERE t.TransactionDate >= pap.StartDate													
																		AND t.TransactionDate <= pap.EndDate
																		-- Don't include closing the year entries
																		AND t.Origin NOT IN ('Y', 'E')
																		AND je.GLAccountID = #AllInfo.GLAccountID
																		AND je.AccountingBasis = @accountingBasis), 0)
		END
	END
			
	IF (@useAlternateBudgets = 0)
	BEGIN																
		UPDATE #AllInfo SET MayBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND DatePartInt = 5 
											 WHERE 
												b.GLAccountID = #AllInfo.GLAccountID)	
	END
	ELSE
	BEGIN
		UPDATE #AllInfo SET MayBudget = (SELECT SUM(ab.Amount)
											 FROM AlternateBudget ab
												 INNER JOIN #MyPAPs #myPAP ON ab.PropertyAccountingPeriodID = #myPAP.PropertyAccountingPeriodID AND DatePartInt = 5
																					AND (#myPAP.AccrualAlternateBudgetID = ab.YearBudgetID OR #myPAP.CashAlternateBudgetID = ab.YearBudgetID)
											 WHERE ab.GLAccountID = #AllInfo.GLAccountID)
	END													
																			
																													 
	--UPDATE #AllInfo SET MayNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
	--									 FROM Budget b
	--										INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	--										INNER JOIN Property p ON pap.PropertyID = p.PropertyID
	--										INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--									 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--									   AND b.GLAccountID = #AllInfo.GLAccountID
	--									   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
	--																		FROM AccountingPeriod 
	--																		WHERE DATEPART(month, EndDate) = 5
	--																		  AND EndDate <= @endDate
	--																		  AND AccountID = ap.AccountID
	--																		ORDER BY EndDate DESC)
	--									 FOR XML PATH ('')), 1, 2, ''))		

    IF (@budgetsOnly = 0)
    BEGIN  		
		IF (@includeDefaultAccountingBook = 1)
		BEGIN  
			UPDATE #AllInfo SET JunActual = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0 AND pap.DatePartInt = 6
														WHERE t.TransactionDate >= pap.StartDate													
														  AND t.TransactionDate <= pap.EndDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND je.AccountingBasis = @accountingBasis)

			UPDATE #AllInfo SET JunActual = ISNULL(JunActual, 0) + ISNULL((SELECT CASE
																	WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																	WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																	END
															 FROM Budget b
																INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1 AND pap.DatePartInt = 6
															 WHERE 
															   b.GLAccountID = #AllInfo.GLAccountID), 0)		
		END

		IF (@runForOtherAccountingBooks = 1)
		BEGIN
			UPDATE #AllInfo SET JunActual = ISNULL(JunActual, 0) + ISNULL((SELECT SUM(je.Amount)
																	FROM JournalEntry je
																		INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																		INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.DatePartInt = 6
																		INNER JOIN #AccountingBooks #ab ON #ab.AccountingBookID = je.AccountingBookID
																	WHERE t.TransactionDate >= pap.StartDate													
																		AND t.TransactionDate <= pap.EndDate
																		-- Don't include closing the year entries
																		AND t.Origin NOT IN ('Y', 'E')
																		AND je.GLAccountID = #AllInfo.GLAccountID
																		AND je.AccountingBasis = @accountingBasis), 0)
		END
	END
										
	IF (@useAlternateBudgets = 0)
	BEGIN									
		UPDATE #AllInfo SET JunBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND DatePartInt = 6 
											 WHERE 
												b.GLAccountID = #AllInfo.GLAccountID)	
	END			
	ELSE
	BEGIN
		UPDATE #AllInfo SET JunBudget = (SELECT SUM(ab.Amount)
											 FROM AlternateBudget ab
												 INNER JOIN #MyPAPs #myPAP ON ab.PropertyAccountingPeriodID = #myPAP.PropertyAccountingPeriodID AND DatePartInt = 6
																					AND (#myPAP.AccrualAlternateBudgetID = ab.YearBudgetID OR #myPAP.CashAlternateBudgetID = ab.YearBudgetID)
											 WHERE ab.GLAccountID = #AllInfo.GLAccountID)
	END										
																			
																			
	--UPDATE #AllInfo SET JunNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
	--									 FROM Budget b
	--										INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	--										INNER JOIN Property p ON pap.PropertyID = p.PropertyID
	--										INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--									 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--									   AND b.GLAccountID = #AllInfo.GLAccountID
	--									   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
	--																		FROM AccountingPeriod 
	--																		WHERE DATEPART(month, EndDate) = 6
	--																		  AND EndDate <= @endDate
	--																		  AND AccountID = ap.AccountID
	--																		ORDER BY EndDate DESC)
	--									 FOR XML PATH ('')), 1, 2, ''))		

    IF (@budgetsOnly = 0)
    BEGIN  
		IF (@includeDefaultAccountingBook = 1)
		BEGIN		  				
			UPDATE #AllInfo SET JulActual = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0 AND pap.DatePartInt = 7
														WHERE t.TransactionDate >= pap.StartDate													
														  AND t.TransactionDate <= pap.EndDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND je.AccountingBasis = @accountingBasis)

			UPDATE #AllInfo SET JulActual = ISNULL(JulActual, 0) + ISNULL((SELECT CASE
																	WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																	WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																	END
															 FROM Budget b
																INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1 AND pap.DatePartInt = 7 
															 WHERE 
															   b.GLAccountID = #AllInfo.GLAccountID), 0)		
		END

		IF (@runForOtherAccountingBooks = 1)
		BEGIN
			UPDATE #AllInfo SET JulActual = ISNULL(JulActual, 0) + ISNULL((SELECT SUM(je.Amount)
																	FROM JournalEntry je
																		INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																		INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.DatePartInt = 7
																		INNER JOIN #AccountingBooks #ab ON #ab.AccountingBookID = je.AccountingBookID
																	WHERE t.TransactionDate >= pap.StartDate													
																		AND t.TransactionDate <= pap.EndDate
																		-- Don't include closing the year entries
																		AND t.Origin NOT IN ('Y', 'E')
																		AND je.GLAccountID = #AllInfo.GLAccountID
																		AND je.AccountingBasis = @accountingBasis), 0)
		END
	END
							
	IF (@useAlternateBudgets = 0)
	BEGIN												
		UPDATE #AllInfo SET JulBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND DatePartInt = 7 
											 WHERE 
												b.GLAccountID = #AllInfo.GLAccountID)	
	END
	ELSE
	BEGIN
		UPdATE #AllInfo SET JulBudget = (SELECT SUM(ab.Amount)
											 FROM AlternateBudget ab
												 INNER JOIN #MyPAPs #myPAP ON ab.PropertyAccountingPeriodID = #myPAP.PropertyAccountingPeriodID AND DatePartInt = 7
																					AND (#myPAP.AccrualAlternateBudgetID = ab.YearBudgetID OR #myPAP.CashAlternateBudgetID = ab.YearBudgetID)
											 WHERE ab.GLAccountID = #AllInfo.GLAccountID)
	END													
																			
																			
	--UPDATE #AllInfo SET JulNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
	--									 FROM Budget b
	--										INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	--										INNER JOIN Property p ON pap.PropertyID = p.PropertyID
	--										INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--									 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--									   AND b.GLAccountID = #AllInfo.GLAccountID
	--									   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
	--																		FROM AccountingPeriod 
	--																		WHERE DATEPART(month, EndDate) = 7
	--																		  AND EndDate <= @endDate
	--																		  AND AccountID = ap.AccountID
	--																		ORDER BY EndDate DESC)
	--									 FOR XML PATH ('')), 1, 2, ''))								 

    IF (@budgetsOnly = 0)
    BEGIN  		  
		IF (@includeDefaultAccountingBook = 1)
		BEGIN
			UPDATE #AllInfo SET AugActual = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0 AND pap.DatePartInt = 8
														WHERE t.TransactionDate >= pap.StartDate													
														  AND t.TransactionDate <= pap.EndDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND je.AccountingBasis = @accountingBasis)

			UPDATE #AllInfo SET AugActual = ISNULL(AugActual, 0) + ISNULL((SELECT CASE
																	WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																	WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																	END
															 FROM Budget b
																INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1 AND pap.DatePartInt = 8 
															 WHERE 
																b.GLAccountID = #AllInfo.GLAccountID), 0)		
		END

		IF (@runForOtherAccountingBooks = 1)
		BEGIN
			UPDATE #AllInfo SET AugActual = ISNULL(AugActual, 0) + ISNULL((SELECT SUM(je.Amount)
																	FROM JournalEntry je
																		INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																		INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.DatePartInt = 8
																		INNER JOIN #AccountingBooks #ab ON #ab.AccountingBookID = je.AccountingBookID
																	WHERE t.TransactionDate >= pap.StartDate													
																		AND t.TransactionDate <= pap.EndDate
																		-- Don't include closing the year entries
																		AND t.Origin NOT IN ('Y', 'E')
																		AND je.GLAccountID = #AllInfo.GLAccountID
																		AND je.AccountingBasis = @accountingBasis), 0)
		END
	END
					
	IF (@useAlternateBudgets = 0)
	BEGIN														
		UPDATE #AllInfo SET AugBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND DatePartInt = 8 
											 WHERE 
												b.GLAccountID = #AllInfo.GLAccountID)
	END		
	ELSE
	BEGIN
		UPDATE #AllInfo SET AugBudget = (SELECT SUM(ab.Amount)
											 FROM AlternateBudget ab
												 INNER JOIN #MyPAPs #myPAP ON ab.PropertyAccountingPeriodID = #myPAP.PropertyAccountingPeriodID AND DatePartInt = 8
																					AND (#myPAP.AccrualAlternateBudgetID = ab.YearBudgetID OR #myPAP.CashAlternateBudgetID = ab.YearBudgetID)
											 WHERE ab.GLAccountID = #AllInfo.GLAccountID)
	END												
																			
																			
	--UPDATE #AllInfo SET AugNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
	--									 FROM Budget b
	--										INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	--										INNER JOIN Property p ON pap.PropertyID = p.PropertyID
	--										INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--									 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--									   AND b.GLAccountID = #AllInfo.GLAccountID
	--									   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
	--																		FROM AccountingPeriod 
	--																		WHERE DATEPART(month, EndDate) = 8
	--																		  AND EndDate <= @endDate
	--																		  AND AccountID = ap.AccountID
	--																		ORDER BY EndDate DESC)
	--									 FOR XML PATH ('')), 1, 2, ''))		

    IF (@budgetsOnly = 0)
    BEGIN  		  
		IF (@includeDefaultAccountingBook = 1)
		BEGIN
			UPDATE #AllInfo SET SepActual = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0 AND pap.DatePartInt = 9
														WHERE t.TransactionDate >= pap.StartDate													
														  AND t.TransactionDate <= pap.EndDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND je.AccountingBasis = @accountingBasis)

			UPDATE #AllInfo SET SepActual = ISNULL(SepActual, 0) + ISNULL((SELECT CASE
																	WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																	WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																	END
															 FROM Budget b
																INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1 AND pap.DatePartInt = 9 
															 WHERE 
															   b.GLAccountID = #AllInfo.GLAccountID), 0)		
		END

		IF (@runForOtherAccountingBooks = 1)
		BEGIN
			UPDATE #AllInfo SET SepActual = ISNULL(SepActual, 0) + ISNULL((SELECT SUM(je.Amount)
																	FROM JournalEntry je
																		INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																		INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.DatePartInt = 9
																		INNER JOIN #AccountingBooks #ab ON #ab.AccountingBookID = je.AccountingBookID
																	WHERE t.TransactionDate >= pap.StartDate													
																		AND t.TransactionDate <= pap.EndDate
																		-- Don't include closing the year entries
																		AND t.Origin NOT IN ('Y', 'E')
																		AND je.GLAccountID = #AllInfo.GLAccountID
																		AND je.AccountingBasis = @accountingBasis), 0)
		END
	END
				
	IF (@useAlternateBudgets = 0)
	BEGIN															
		UPDATE #AllInfo SET SepBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND DatePartInt = 9
											 WHERE 
												b.GLAccountID = #AllInfo.GLAccountID)
	END
	ELSE
	BEGIN
		UPDATE #AllInfo SET SepBudget = (SELECT SUM(ab.Amount)
											 FROM AlternateBudget ab
												 INNER JOIN #MyPAPs #myPAP ON ab.PropertyAccountingPeriodID = #myPAP.PropertyAccountingPeriodID AND DatePartInt = 9
																					AND (#myPAP.AccrualAlternateBudgetID = ab.YearBudgetID OR #myPAP.CashAlternateBudgetID = ab.YearBudgetID)
											 WHERE ab.GLAccountID = #AllInfo.GLAccountID)
	END														
																			
																			
	--UPDATE #AllInfo SET SepNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
	--									 FROM Budget b
	--										INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	--										INNER JOIN Property p ON pap.PropertyID = p.PropertyID
	--										INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--									 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--									   AND b.GLAccountID = #AllInfo.GLAccountID
	--									   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
	--																		FROM AccountingPeriod 
	--																		WHERE DATEPART(month, EndDate) = 9
	--																		  AND EndDate <= @endDate
	--																		  AND AccountID = ap.AccountID
	--																		ORDER BY EndDate DESC)
	--									 FOR XML PATH ('')), 1, 2, ''))		

    IF (@budgetsOnly = 0)
    BEGIN  		
		IF (@includeDefaultAccountingBook = 1)
		BEGIN  
			UPDATE #AllInfo SET OctActual = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0 AND pap.DatePartInt = 10
														WHERE t.TransactionDate >= pap.StartDate													
														  AND t.TransactionDate <= pap.EndDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND je.AccountingBasis = @accountingBasis)

			UPDATE #AllInfo SET OctActual = ISNULL(OctActual, 0) + ISNULL((SELECT CASE
																	WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																	WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																	END
															 FROM Budget b
																INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1 AND pap.DatePartInt = 10 
															 WHERE 
															   b.GLAccountID = #AllInfo.GLAccountID), 0)		
		END

		IF (@runForOtherAccountingBooks = 1)
		BEGIN
			UPDATE #AllInfo SET OctActual = ISNULL(OctActual, 0) + ISNULL((SELECT SUM(je.Amount)
																	FROM JournalEntry je
																		INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																		INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.DatePartInt = 10
																		INNER JOIN #AccountingBooks #ab ON #ab.AccountingBookID = je.AccountingBookID
																	WHERE t.TransactionDate >= pap.StartDate													
																		AND t.TransactionDate <= pap.EndDate
																		-- Don't include closing the year entries
																		AND t.Origin NOT IN ('Y', 'E')
																		AND je.GLAccountID = #AllInfo.GLAccountID
																		AND je.AccountingBasis = @accountingBasis), 0)
		END
	END
		
	IF (@useAlternateBudgets = 0)
	BEGIN																	
		UPDATE #AllInfo SET OctBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND DatePartInt = 10
											 WHERE 
												b.GLAccountID = #AllInfo.GLAccountID)	
	END
	ELSE
	BEGIN
		UPDATE #AllInfo SET OctBudget = (SELECT SUM(ab.Amount)
											 FROM AlternateBudget ab
												 INNER JOIN #MyPAPs #myPAP ON ab.PropertyAccountingPeriodID = #myPAP.PropertyAccountingPeriodID AND DatePartInt = 10
																					AND (#myPAP.AccrualAlternateBudgetID = ab.YearBudgetID OR #myPAP.CashAlternateBudgetID = ab.YearBudgetID)
											 WHERE ab.GLAccountID = #AllInfo.GLAccountID)
	END													
																			
																			
	--UPDATE #AllInfo SET OctNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
	--									 FROM Budget b
	--										INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	--										INNER JOIN Property p ON pap.PropertyID = p.PropertyID
	--										INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--									 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--									   AND b.GLAccountID = #AllInfo.GLAccountID
	--									   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
	--																		FROM AccountingPeriod 
	--																		WHERE DATEPART(month, EndDate) = 10
	--																		  AND EndDate <= @endDate
	--																		  AND AccountID = ap.AccountID
	--																		ORDER BY EndDate DESC)
	--									 FOR XML PATH ('')), 1, 2, ''))		

    IF (@budgetsOnly = 0)
    BEGIN
		IF (@includeDefaultAccountingBook = 1)
		BEGIN  		  
			UPDATE #AllInfo SET NovActual = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0 AND pap.DatePartInt = 11
														WHERE t.TransactionDate >= pap.StartDate													
														  AND t.TransactionDate <= pap.EndDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND je.AccountingBasis = @accountingBasis)

			UPDATE #AllInfo SET NovActual = ISNULL(NovActual, 0) + ISNULL((SELECT CASE
																	WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																	WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																	END
															 FROM Budget b
																INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1 AND pap.DatePartInt = 11 
															 WHERE 
															   b.GLAccountID = #AllInfo.GLAccountID), 0)		
		END

		IF (@runForOtherAccountingBooks = 1)
		BEGIN
			UPDATE #AllInfo SET NovActual = ISNULL(NovActual, 0) + ISNULL((SELECT SUM(je.Amount)
																	FROM JournalEntry je
																		INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																		INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.DatePartInt = 11
																		INNER JOIN #AccountingBooks #ab ON #ab.AccountingBookID = je.AccountingBookID
																	WHERE t.TransactionDate >= pap.StartDate													
																		AND t.TransactionDate <= pap.EndDate
																		-- Don't include closing the year entries
																		AND t.Origin NOT IN ('Y', 'E')
																		AND je.GLAccountID = #AllInfo.GLAccountID
																		AND je.AccountingBasis = @accountingBasis), 0)
		END
	END
					
	IF (@useAlternateBudgets = 0)
	BEGIN														
		UPDATE #AllInfo SET NovBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND DatePartInt = 11
											 WHERE 
												b.GLAccountID = #AllInfo.GLAccountID)		
	END
	ELSE
	BEGIN
		UPDATE #AllInfo SET NovBudget = (SELECT SUM(ab.Amount)
											 FROM AlternateBudget ab
												 INNER JOIN #MyPAPs #myPAP ON ab.PropertyAccountingPeriodID = #myPAP.PropertyAccountingPeriodID AND DatePartInt = 11
																					AND (#myPAP.AccrualAlternateBudgetID = ab.YearBudgetID OR #myPAP.CashAlternateBudgetID = ab.YearBudgetID)
											 WHERE ab.GLAccountID = #AllInfo.GLAccountID)
	END												
																			
																			
	--UPDATE #AllInfo SET NovNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
	--									 FROM Budget b
	--										INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	--										INNER JOIN Property p ON pap.PropertyID = p.PropertyID
	--										INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--									 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--									   AND b.GLAccountID = #AllInfo.GLAccountID
	--									   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
	--																		FROM AccountingPeriod 
	--																		WHERE DATEPART(month, EndDate) = 11
	--																		  AND EndDate <= @endDate
	--																		  AND AccountID = ap.AccountID
	--																		ORDER BY EndDate DESC)
	--									 FOR XML PATH ('')), 1, 2, ''))		

    IF (@budgetsOnly = 0)
    BEGIN  		 
		IF (@includeDefaultAccountingBook = 1)
		BEGIN 
			UPDATE #AllInfo SET DecActual = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0 AND pap.DatePartInt = 12
														WHERE t.TransactionDate >= pap.StartDate													
														  AND t.TransactionDate <= pap.EndDate
														  -- Don't include closing the year entries
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND je.GLAccountID = #AllInfo.GLAccountID
														  AND je.AccountingBasis = @accountingBasis)

			UPDATE #AllInfo SET DecActual = ISNULL(DecActual, 0) + ISNULL((SELECT CASE
																	WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																	WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																	END
															 FROM Budget b
																INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1 AND pap.DatePartInt = 12
															 WHERE 
															   b.GLAccountID = #AllInfo.GLAccountID), 0)		
		END

		IF (@runForOtherAccountingBooks = 1)
		BEGIN
			UPDATE #AllInfo SET DecActual = ISNULL(DecActual, 0) + ISNULL((SELECT SUM(je.Amount)
																	FROM JournalEntry je
																		INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																		INNER JOIN #MyPAPs pap ON t.PropertyID = pap.PropertyID AND pap.DatePartInt = 12
																		INNER JOIN #AccountingBooks #ab ON #ab.AccountingBookID = je.AccountingBookID
																	WHERE t.TransactionDate >= pap.StartDate													
																		AND t.TransactionDate <= pap.EndDate
																		-- Don't include closing the year entries
																		AND t.Origin NOT IN ('Y', 'E')
																		AND je.GLAccountID = #AllInfo.GLAccountID
																		AND je.AccountingBasis = @accountingBasis), 0)
		END
	END
								
	IF (@useAlternateBudgets = 0)
	BEGIN											
		UPDATE #AllInfo SET DecBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN #MyPAPs pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND DatePartInt = 12
											 WHERE 
												b.GLAccountID = #AllInfo.GLAccountID)	
	END				
	ELSE
	BEGIN
		UPDATE #AllInfo SET DecBudget = (SELECT SUM(ab.Amount)
											 FROM AlternateBudget ab
												 INNER JOIN #MyPAPs #myPAP ON ab.PropertyAccountingPeriodID = #myPAP.PropertyAccountingPeriodID AND DatePartInt = 12
																					AND (#myPAP.AccrualAlternateBudgetID = ab.YearBudgetID OR #myPAP.CashAlternateBudgetID = ab.YearBudgetID)
											 WHERE ab.GLAccountID = #AllInfo.GLAccountID)
	END									
																			
	--UPDATE #AllInfo SET DecNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
	--									 FROM Budget b
	--										INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
	--										INNER JOIN Property p ON pap.PropertyID = p.PropertyID
	--										INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--									 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--									   AND b.GLAccountID = #AllInfo.GLAccountID
	--									   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
	--																		FROM AccountingPeriod 
	--																		WHERE DATEPART(month, EndDate) = 12
	--																		  AND EndDate <= @endDate
	--																		  AND AccountID = ap.AccountID
	--																		ORDER BY EndDate DESC)
	--									 FOR XML PATH ('')), 1, 2, ''))	
	
	IF (@reportName = 'Cash Flow Statement' OR @reportName = 'Cash Flow Statement Expanded')
	BEGIN
		CREATE TABLE #CashFlowBalances (	
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
		SummaryParentPath nvarchar(max),
		JanBudget money null default 0,
		JanActual money null default 0,
		JanNotes nvarchar(MAX) null,
		FebBudget money null default 0,
		FebActual money null default 0,
		FebNotes nvarchar(MAX) null,
		MarBudget money null default 0,
		MarActual money null default 0,
		MarNotes nvarchar(MAX) null,
		AprBudget money null default 0,
		AprActual money null default 0,
		AprNotes nvarchar(MAX) null,
		MayBudget money null default 0,
		MayActual money null default 0,
		MayNotes nvarchar(MAX) null,
		JunBudget money null default 0,
		JunActual money null default 0,
		JunNotes nvarchar(MAX) null,
		JulBudget money null default 0,
		JulActual money null default 0,
		JulNotes nvarchar(MAX) null,
		AugBudget money null default 0,
		AugActual money null default 0,
		AugNotes nvarchar(MAX) null,
		SepBudget money null default 0,
		SepActual money null default 0,
		SepNotes nvarchar(MAX) null,
		OctBudget money null default 0,
		OctActual money null default 0,
		OctNotes nvarchar(MAX) null,
		NovBudget money null default 0,
		NovActual money null default 0,
		NovNotes nvarchar(MAX) null,
		DecBudget money null default 0,
		DecActual money null default 0,
		DecNotes nvarchar(MAX) null		
		)	



		IF (@reportName = 'Cash Flow Statement')
		BEGIN	
			-- We declare the Collection here, but we don't add anything to it, so we're passing in an empty list.  We add the "Back" type before where make the next call!
			DECLARE @bankGLAccountTypes StringCollection			
			INSERT INTO #CashFlowBalances EXEC [RPT_ACTG_TwelveMonthBudgetVariance] @propertyIDs, 'Income Statement', @accountingBasis, @accountingPeriodID, 0, @bankGLAccountTypes,
												0, null, @byProperty, @accountingBookIDs
			--SELECT * FROM #CashFlowBalances
			INSERT INTO #AllInfo SELECT PropertyID, '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', 
					0, SUM(JanActual), '', 0, SUM(FebActual), '', 0, SUM(MarActual), '', 0, SUM(AprActual), '',
					0, SUM(MayActual), '', 0, SUM(JunActual), '', 0, SUM(JulActual), '', 0, SUM(AugActual), '',
					0, SUM(SepActual), '', 0, SUM(OctActual), '', 0, SUM(NovActual), '', 0, SUM(DecActual), ''
					FROM #CashFlowBalances
					GROUP BY PropertyID
				
			INSERT #AlternateInfoValues SELECT PropertyID, '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', 
					0, SUM(JanActual), '', 0, SUM(FebActual), '', 0, SUM(MarActual), '', 0, SUM(AprActual), '',
					0, SUM(MayActual), '', 0, SUM(JunActual), '', 0, SUM(JulActual), '', 0, SUM(AugActual), '',
					0, SUM(SepActual), '', 0, SUM(OctActual), '', 0, SUM(NovActual), '', 0, SUM(DecActual), ''
					FROM #CashFlowBalances
					GROUP BY PropertyID
		END


		
		INSERT INTO @bankGLAccountTypes VALUES ('Bank')
		
		TRUNCATE TABLE #CashFlowBalances
		
		INSERT INTO #CashFlowBalances EXEC [RPT_ACTG_TwelveMonthBudgetVariance] @propertyIDs, '', @accountingBasis, @accountingPeriodID, 0, @bankGLAccountTypes, 0, null, @byProperty, @accountingBookIDs
		
		INSERT INTO #AllInfo SELECT PropertyID, '22222222-2222-2222-2222-222222222222', '', 'Beginning Cash Balance', '', 'Bank', null, 0, 1, 0, '', '', '', 
				0, SUM(JanActual), '', 0, SUM(FebActual), '', 0, SUM(MarActual), '', 0, SUM(AprActual), '',
				0, SUM(MayActual), '', 0, SUM(JunActual), '', 0, SUM(JulActual), '', 0, SUM(AugActual), '',
				0, SUM(SepActual), '', 0, SUM(OctActual), '', 0, SUM(NovActual), '', 0, SUM(DecActual), ''
				FROM #CashFlowBalances
				GROUP BY PropertyID
				
		INSERT INTO #AlternateInfoValues SELECT PropertyID, '22222222-2222-2222-2222-222222222222', '', 'Beginning Cash Balance', '', 'Bank', null, 0, 1, 0, '', '', '', 
				0, SUM(JanActual), '', 0, SUM(FebActual), '', 0, SUM(MarActual), '', 0, SUM(AprActual), '',
				0, SUM(MayActual), '', 0, SUM(JunActual), '', 0, SUM(JulActual), '', 0, SUM(AugActual), '',
				0, SUM(SepActual), '', 0, SUM(OctActual), '', 0, SUM(NovActual), '', 0, SUM(DecActual), ''
				FROM #CashFlowBalances
				GROUP BY PropertyID				
	END																		
	
	IF (@alternateChartOfAccountsID IS NOT NULL)
	BEGIN
	
--select * from #AllInfo
	
		INSERT #AlternateInfo 
			SELECT	#p.PropertyID,
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
					0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null,
					0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null
				FROM GetAlternateChartOfAccounts(@accountID, @reportGLAccountTypes, @alternateChartOfAccountsID)
				--FROM GetChartOfAccountsByAlternate(@accountID, @reportGLAccountTypes, @alternateChartOfAccountsID)
					LEFT JOIN #Properties #p ON @byProperty = 1
	
		INSERT #AlternateInfoValues
			SELECT  #altInfo.PropertyID,
					#altInfo.GLAccountID, 
					#altInfo.Number AS 'GLAccountNumber',
					#altInfo.Name AS 'GLAccountName',
					#altInfo.[Description],
					LTRIM(#altInfo.GLAccountType) AS 'Type',
					#altInfo.ParentGLAccountID,
					#altInfo.Depth,
					#altInfo.IsLeaf,
					#altInfo.SummaryParent,
					#altInfo.OrderByPath,
					#altInfo.[Path],
					#altInfo.SummaryParentPath,
					ISNULL(SUM(ISNULL(#AI.JanBudget, 0)), 0) AS 'JanBudget', ISNULL(SUM(ISNULL(#AI.JanActual, 0)), 0) AS 'JanActual', #altInfo.JanNotes,
					ISNULL(SUM(ISNULL(#AI.FebBudget, 0)), 0) AS 'FebBudget', ISNULL(SUM(ISNULL(#AI.FebActual, 0)), 0) AS 'FebActual', #altInfo.FebNotes,
					ISNULL(SUM(ISNULL(#AI.MarBudget, 0)), 0) AS 'MarBudget', ISNULL(SUM(ISNULL(#AI.MarActual, 0)), 0) AS 'MarActual', #altInfo.MarNotes,
					ISNULL(SUM(ISNULL(#AI.AprBudget, 0)), 0) AS 'AprBudget', ISNULL(SUM(ISNULL(#AI.AprActual, 0)), 0) AS 'AprActual', #altInfo.AprNotes,
					ISNULL(SUM(ISNULL(#AI.MayBudget, 0)), 0) AS 'MayBudget', ISNULL(SUM(ISNULL(#AI.MayActual, 0)), 0) AS 'MayActual', #altInfo.MayNotes,
					ISNULL(SUM(ISNULL(#AI.JunBudget, 0)), 0) AS 'JunBudget', ISNULL(SUM(ISNULL(#AI.JunActual, 0)), 0) AS 'JunActual', #altInfo.JunNotes,
					ISNULL(SUM(ISNULL(#AI.JulBudget, 0)), 0) AS 'JulBudget', ISNULL(SUM(ISNULL(#AI.JulActual, 0)), 0) AS 'JulActual', #altInfo.JulNotes,
					ISNULL(SUM(ISNULL(#AI.AugBudget, 0)), 0) AS 'AugBudget', ISNULL(SUM(ISNULL(#AI.AugActual, 0)), 0) AS 'AugActual', #altInfo.AugNotes,
					ISNULL(SUM(ISNULL(#AI.SepBudget, 0)), 0) AS 'SepBudget', ISNULL(SUM(ISNULL(#AI.SepActual, 0)), 0) AS 'SepActual', #altInfo.SepNotes,
					ISNULL(SUM(ISNULL(#AI.OctBudget, 0)), 0) AS 'OctBudget', ISNULL(SUM(ISNULL(#AI.OctActual, 0)), 0) AS 'OctActual', #altInfo.OctNotes,
					ISNULL(SUM(ISNULL(#AI.NovBudget, 0)), 0) AS 'NovBudget', ISNULL(SUM(ISNULL(#AI.NovActual, 0)), 0) AS 'NovActual', #altInfo.NovNotes,
					ISNULL(SUM(ISNULL(#AI.DecBudget, 0)), 0) AS 'DecBudget', ISNULL(SUM(ISNULL(#AI.DecActual, 0)), 0) AS 'DecActual', #altInfo.DecNotes
				 FROM #AlternateInfo #altInfo
						INNER JOIN GLAccountAlternateGLAccount altGL ON #altInfo.GLAccountID = altGL.AlternateGLAccountID
						INNER JOIN #AllInfo #AI ON altGL.GLAccountID = #AI.GLAccountID AND (@byProperty = 0 OR #altInfo.PropertyID = #AI.PropertyID)
				 --WHERE #AI.IsLeaf = 1  
				 GROUP BY #altInfo.GLAccountID, #altInfo.Number, #altInfo.Name,	#altInfo.[Description], #altInfo.GLAccountType,	#altInfo.ParentGLAccountID,
						  #altInfo.Depth, #altInfo.IsLeaf, #altInfo.SummaryParent, #altInfo.OrderByPath, #altInfo.[Path], #altInfo.SummaryParentPath,
						  #altInfo.JanNotes, #altInfo.FebNotes, #altInfo.MarNotes, #altInfo.AprNotes, #altInfo.MayNotes, #altInfo.JunNotes,
						  #altInfo.JulNotes, #altInfo.AugNotes, #altInfo.SepNotes, #altInfo.OctNotes, #altInfo.NovNotes, #altInfo.DecNotes,
						  #altInfo.PropertyID

		INSERT #AlternateInfoValues
			SELECT	PropertyID, GLAccountID, Number, Name + ' - Other', [Description], GLAccountType, ParentGLAccountID, Depth+1, 1, SummaryParent,
					OrderByPath + '!#' + RIGHT('0000000000' + Number, 10), 
					[Path] + '!#' + Number + ' - ' + Name + ' - Other', 
					[SummaryParentPath] + '!#' + CAST(SummaryParent AS nvarchar(10)),
					JanBudget, JanActual, JanNotes, FebBudget, FebActual, FebNotes, MarBudget, MarActual, MarNotes, AprBudget, AprActual, AprNotes,
					MayBudget, MayActual, MayNotes, JunBudget, JunActual, JunNotes, JulBudget, JulActual, JulNotes, AugBudget, AugActual, AugNotes,
					SepBudget, SepActual, SepNotes, OctBudget, OctActual, OctNotes, NovBudget, NovActual, NovNotes, DecBudget, DecActual, DecNotes

			FROM #AlternateInfoValues
			WHERE IsLeaf = 0
			  AND ((JanBudget <> 0)	OR (JanActual <> 0) OR (FebBudget <> 0) OR (FebActual <> 0) OR (MarBudget <> 0) OR (MarActual <> 0)
				OR (AprBudget <> 0) OR (AprActual <> 0) OR (MayBudget <> 0) OR (MayActual <> 0) OR (JunBudget <> 0) OR (JunActual <> 0)
				OR (JulBudget <> 0) OR (JulActual <> 0) OR (AugBudget <> 0) OR (AugActual <> 0) OR (SepBudget <> 0) OR (SepActual <> 0)
				OR (OctBudget <> 0) OR (OctActual <> 0) OR (NovBudget <> 0) OR (NovActual <> 0) OR (DecBudget <> 0) OR (DecActual <> 0))	
				
				
--select * from #AllInfo
--select * from #AlternateInfoValues

		--INSERT #AlternateInfoValues 
		--		SELECT  #altInfo.PropertyID,
		--				#altInfo.GLAccountID, 
		--				#altInfo.Number AS 'GLAccountNumber',
		--				#altInfo.Name + ' - Other' AS 'GLAccountName',
		--				#altInfo.[Description],
		--				LTRIM(#altInfo.GLAccountType) AS 'Type',
		--				#altInfo.ParentGLAccountID,
		--				#altInfo.Depth + 1,
		--				1,
		--				#altInfo.SummaryParent,
		--				#altInfo.OrderByPath,
		--				#altInfo.[Path] + '!#' + #altInfo.Number + ' ' + #altInfo.Name + ' - Other',
		--				#altInfo.SummaryParentPath,
		--				ISNULL(SUM(ISNULL(#AI.JanBudget, 0)), 0) AS 'JanBudget', ISNULL(SUM(ISNULL(#AI.JanActual, 0)), 0) AS 'JanActual', #altInfo.JanNotes,
		--				ISNULL(SUM(ISNULL(#AI.FebBudget, 0)), 0) AS 'FebBudget', ISNULL(SUM(ISNULL(#AI.FebActual, 0)), 0) AS 'FebActual', #altInfo.FebNotes,
		--				ISNULL(SUM(ISNULL(#AI.MarBudget, 0)), 0) AS 'MarBudget', ISNULL(SUM(ISNULL(#AI.MarActual, 0)), 0) AS 'MarActual', #altInfo.MarNotes,
		--				ISNULL(SUM(ISNULL(#AI.AprBudget, 0)), 0) AS 'AprBudget', ISNULL(SUM(ISNULL(#AI.AprActual, 0)), 0) AS 'AprActual', #altInfo.AprNotes,
		--				ISNULL(SUM(ISNULL(#AI.MayBudget, 0)), 0) AS 'MayBudget', ISNULL(SUM(ISNULL(#AI.MayActual, 0)), 0) AS 'MayActual', #altInfo.MayNotes,
		--				ISNULL(SUM(ISNULL(#AI.JunBudget, 0)), 0) AS 'JunBudget', ISNULL(SUM(ISNULL(#AI.JunActual, 0)), 0) AS 'JunActual', #altInfo.JunNotes,
		--				ISNULL(SUM(ISNULL(#AI.JulBudget, 0)), 0) AS 'JulBudget', ISNULL(SUM(ISNULL(#AI.JulActual, 0)), 0) AS 'JulActual', #altInfo.JulNotes,
		--				ISNULL(SUM(ISNULL(#AI.AugBudget, 0)), 0) AS 'AugBudget', ISNULL(SUM(ISNULL(#AI.AugActual, 0)), 0) AS 'AugActual', #altInfo.AugNotes,
		--				ISNULL(SUM(ISNULL(#AI.SepBudget, 0)), 0) AS 'SepBudget', ISNULL(SUM(ISNULL(#AI.SepActual, 0)), 0) AS 'SepActual', #altInfo.SepNotes,
		--				ISNULL(SUM(ISNULL(#AI.OctBudget, 0)), 0) AS 'OctBudget', ISNULL(SUM(ISNULL(#AI.OctActual, 0)), 0) AS 'OctActual', #altInfo.OctNotes,
		--				ISNULL(SUM(ISNULL(#AI.NovBudget, 0)), 0) AS 'NovBudget', ISNULL(SUM(ISNULL(#AI.NovActual, 0)), 0) AS 'NovActual', #altInfo.NovNotes,
		--				ISNULL(SUM(ISNULL(#AI.DecBudget, 0)), 0) AS 'DecBudget', ISNULL(SUM(ISNULL(#AI.DecActual, 0)), 0) AS 'DecActual', #altInfo.DecNotes
		--			 FROM #AlternateInfo #altInfo
		--					INNER JOIN GLAccountAlternateGLAccount altGL ON #altInfo.GLAccountID = altGL.AlternateGLAccountID
		--					INNER JOIN #AllInfo #AI ON altGL.GLAccountID = #AI.GLAccountID AND #altInfo.PropertyID = #AI.PropertyID
		--		WHERE ((#altInfo.IsLeaf = 1 AND #AI.IsLeaf = 0)
		--		   OR (#altInfo.IsLeaf = 0 AND #AI.IsLeaf = 1)) 
		--		GROUP BY #altInfo.GLAccountID, #altInfo.Number, #altInfo.Name,	#altInfo.[Description], #altInfo.GLAccountType,	#altInfo.ParentGLAccountID,
		--				 #altInfo.Depth, #altInfo.IsLeaf, #altInfo.SummaryParent, #altInfo.OrderByPath, #altInfo.[Path], #altInfo.SummaryParentPath,
		--				 #altInfo.JanNotes, #altInfo.FebNotes, #altInfo.MarNotes, #altInfo.AprNotes, #altInfo.MayNotes, #altInfo.JunNotes,
		--				 #altInfo.JulNotes, #altInfo.AugNotes, #altInfo.SepNotes, #altInfo.OctNotes, #altInfo.NovNotes, #altInfo.DecNotes,
		--				 #altInfo.PropertyID					  	
	END
	ELSE
	BEGIN
		INSERT #AllInfo 
			SELECT	PropertyID, GLAccountID, Number, Name + ' - Other', [Description], GLAccountType, ParentGLAccountID, Depth+1, 1, SummaryParent,
					OrderByPath + '!#' + RIGHT('0000000000' + Number, 10), 
					[Path] + '!#' + Number + ' - ' + Name + ' - Other', 
					[SummaryParentPath] + '!#' + CAST(SummaryParent AS nvarchar(10)),
					JanBudget, JanActual, JanNotes, FebBudget, FebActual, FebNotes, MarBudget, MarActual, MarNotes, AprBudget, AprActual, AprNotes,
					MayBudget, MayActual, MayNotes, JunBudget, JunActual, JunNotes, JulBudget, JulActual, JulNotes, AugBudget, AugActual, AugNotes,
					SepBudget, SepActual, SepNotes, OctBudget, OctActual, OctNotes, NovBudget, NovActual, NovNotes, DecBudget, DecActual, DecNotes
			FROM #AllInfo
			WHERE IsLeaf = 0
			  AND ((JanBudget <> 0)	OR (JanActual <> 0) OR (FebBudget <> 0) OR (FebActual <> 0) OR (MarBudget <> 0) OR (MarActual <> 0)
				OR (AprBudget <> 0) OR (AprActual <> 0) OR (MayBudget <> 0) OR (MayActual <> 0) OR (JunBudget <> 0) OR (JunActual <> 0)
				OR (JulBudget <> 0) OR (JulActual <> 0) OR (AugBudget <> 0) OR (AugActual <> 0) OR (SepBudget <> 0) OR (SepActual <> 0)
				OR (OctBudget <> 0) OR (OctActual <> 0) OR (NovBudget <> 0) OR (NovActual <> 0) OR (DecBudget <> 0) OR (DecActual <> 0))	
	END
								
	DECLARE @hideZeroValues bit = (SELECT HideZeroValuesInFinancialReports 
									FROM Settings s
									INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID AND s.AccountID = ap.AccountID)																	

	IF (@showAllAccounts = 1)
	BEGIN
		SET @hideZeroValues = 0
	END								
										
	IF (@hideZeroValues = 1)
	BEGIN
		IF (@alternateChartOfAccountsID IS NOT NULL)
		BEGIN		
			SELECT  COALESCE(PropertyID, '00000000-0000-0000-0000-000000000000'),
					GLAccountID, 
					Number AS 'GLAccountNumber',
					Name AS 'GLAccountName',
					[Description],
					LTRIM(GLAccountType) AS 'Type',
					ParentGLAccountID,
					Depth,
					IsLeaf,
					SummaryParent,
					OrderByPath,
					[Path],
					SummaryParentPath,
					ISNULL(JanBudget, 0) AS 'JanBudget', ISNULL(JanActual, 0) AS 'JanActual', JanNotes,
					ISNULL(FebBudget, 0) AS 'FebBudget', ISNULL(FebActual, 0) AS 'FebActual', FebNotes,
					ISNULL(MarBudget, 0) AS 'MarBudget', ISNULL(MarActual, 0) AS 'MarActual', MarNotes,
					ISNULL(AprBudget, 0) AS 'AprBudget', ISNULL(AprActual, 0) AS 'AprActual', AprNotes,
					ISNULL(MayBudget, 0) AS 'MayBudget', ISNULL(MayActual, 0) AS 'MayActual', MayNotes,
					ISNULL(JunBudget, 0) AS 'JunBudget', ISNULL(JunActual, 0) AS 'JunActual', JunNotes,
					ISNULL(JulBudget, 0) AS 'JulBudget', ISNULL(JulActual, 0) AS 'JulActual', JulNotes,
					ISNULL(AugBudget, 0) AS 'AugBudget', ISNULL(AugActual, 0) AS 'AugActual', AugNotes,
					ISNULL(SepBudget, 0) AS 'SepBudget', ISNULL(SepActual, 0) AS 'SepActual', SepNotes,																					
					ISNULL(OctBudget, 0) AS 'OctBudget', ISNULL(OctActual, 0) AS 'OctActual', OctNotes,
					ISNULL(NovBudget, 0) AS 'NovBudget', ISNULL(NovActual, 0) AS 'NovActual', NovNotes,
					ISNULL(DecBudget, 0) AS 'DecBudget', ISNULL(DecActual, 0) AS 'DecActual', DecNotes
				FROM #AlternateInfoValues #AIV
				WHERE 
					IsLeaf = 1 AND
					(#AIV.JanBudget <> 0 OR #AIV.JanActual <> 0 OR #AIV.FebBudget <> 0 OR #AIV.FebActual <> 0
				   OR #AIV.MarBudget <> 0 OR #AIV.MarActual <> 0 OR #AIV.AprBudget <> 0 OR #AIV.AprActual <> 0
				   OR #AIV.MayBudget <> 0 OR #AIV.MayActual <> 0 OR #AIV.JunBudget <> 0 OR #AIV.JunActual <> 0
				   OR #AIV.JulBudget <> 0 OR #AIV.JulActual <> 0 OR #AIV.AugBudget <> 0 OR #AIV.AugActual <> 0
				   OR #AIV.SepBudget <> 0 OR #AIV.SepActual <> 0 OR #AIV.OctBudget <> 0 OR #AIV.OctActual <> 0
				   OR #AIV.NovBudget <> 0 OR #AIV.NovActual <> 0 OR #AIV.DecBudget <> 0 OR #AIV.DecActual <> 0)
				   		   				   
			--UNION
			--SELECT	PropertyID, '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', 
			--		0, JanActual, NULL, 0, FebActual, NULL, 0, MarActual, NULL, 0, AprActual, NULL,
			--		0, MayActual, NULL, 0, JunActual, NULL, 0, JulActual, NULL, 0, AugActual, NULL,
			--		0, SepActual, NULL, 0, OctActual, NULL, 0, NovActual, NULL, 0, DecActual, NULL
			--	FROM #AllInfo
			--	WHERE @reportName = 'Cash Flow Statement' 
			--	  AND Name = 'Net Income'
			--	  AND  (JanActual <> 0 OR FebActual <> 0 OR MarActual <> 0 OR AprActual <> 0
			--	    OR	MayActual <> 0 OR JunActual <> 0 OR JulActual <> 0 OR AugActual <> 0
			--	    OR	SepActual <> 0 OR OctActual <> 0 OR NovActual <> 0 OR DecActual <> 0)
				  
			--UNION
			--SELECT	PropertyID, '22222222-2222-2222-2222-222222222222', '', 'Beginning Cash Balance', '', 'Bank', null, 0, 1, 0, '', '', '', 
			--		0, JanActual, NULL, 0, FebActual, NULL, 0, MarActual, NULL, 0, AprActual, NULL,
			--		0, MayActual, NULL, 0, JunActual, NULL, 0, JulActual, NULL, 0, AugActual, NULL,
			--		0, SepActual, NULL, 0, OctActual, NULL, 0, NovActual, NULL, 0, DecActual, NULL
			--	FROM #AllInfo
			--	WHERE @reportName = 'Cash Flow Statement'
			--	  AND Name = 'Beginning Cash Balance'
			--	  AND  (JanActual <> 0 OR FebActual <> 0 OR MarActual <> 0 OR AprActual <> 0
			--	    OR	MayActual <> 0 OR JunActual <> 0 OR JulActual <> 0 OR AugActual <> 0
			--	    OR	SepActual <> 0 OR OctActual <> 0 OR NovActual <> 0 OR DecActual <> 0))
			ORDER BY OrderByPath					
		END
		ELSE
		BEGIN
			SELECT  COALESCE(PropertyID, '00000000-0000-0000-0000-000000000000'),
					GLAccountID, 
					Number AS 'GLAccountNumber',
					Name AS 'GLAccountName',
					[Description],
					LTRIM(GLAccountType) AS 'Type',
					ParentGLAccountID,
					Depth,
					IsLeaf,
					SummaryParent,
					OrderByPath,
					[Path],
					SummaryParentPath,
					ISNULL(JanBudget, 0) AS 'JanBudget', ISNULL(JanActual, 0) AS 'JanActual', JanNotes,
					ISNULL(FebBudget, 0) AS 'FebBudget', ISNULL(FebActual, 0) AS 'FebActual', FebNotes,
					ISNULL(MarBudget, 0) AS 'MarBudget', ISNULL(MarActual, 0) AS 'MarActual', MarNotes,
					ISNULL(AprBudget, 0) AS 'AprBudget', ISNULL(AprActual, 0) AS 'AprActual', AprNotes,
					ISNULL(MayBudget, 0) AS 'MayBudget', ISNULL(MayActual, 0) AS 'MayActual', MayNotes,
					ISNULL(JunBudget, 0) AS 'JunBudget', ISNULL(JunActual, 0) AS 'JunActual', JunNotes,
					ISNULL(JulBudget, 0) AS 'JulBudget', ISNULL(JulActual, 0) AS 'JulActual', JulNotes,
					ISNULL(AugBudget, 0) AS 'AugBudget', ISNULL(AugActual, 0) AS 'AugActual', AugNotes,
					ISNULL(SepBudget, 0) AS 'SepBudget', ISNULL(SepActual, 0) AS 'SepActual', SepNotes,																					
					ISNULL(OctBudget, 0) AS 'OctBudget', ISNULL(OctActual, 0) AS 'OctActual', OctNotes,
					ISNULL(NovBudget, 0) AS 'NovBudget', ISNULL(NovActual, 0) AS 'NovActual', NovNotes,
					ISNULL(DecBudget, 0) AS 'DecBudget', ISNULL(DecActual, 0) AS 'DecActual', DecNotes
			 FROM #AllInfo	
			 WHERE IsLeaf = 1 AND 
				(JanActual <> 0 OR JanBudget <> 0
				OR FebActual <> 0 OR FebBudget <> 0
				OR MarActual <> 0 OR MarBudget <> 0
				OR AprActual <> 0 OR AprBudget <> 0
				OR MayActual <> 0 OR MayBudget <> 0
				OR JunActual <> 0 OR JunBudget <> 0
				OR JulActual <> 0 OR JulBudget <> 0
				OR AugActual <> 0 OR AugBudget <> 0
				OR SepActual <> 0 OR SepBudget <> 0
				OR OctActual <> 0 OR OctBudget <> 0
				OR NovActual <> 0 OR NovBudget <> 0
				OR DecActual <> 0 OR DecBudget <> 0)
			ORDER BY OrderByPath
		END
	END
	ELSE
	BEGIN
		IF (@alternateChartOfAccountsID IS NOT NULL)
		BEGIN
			--INSERT #AlternateInfo SELECT 
			--		GLAccountID,
			--		Number,
			--		Name,
			--		[Description],
			--		GLAccountType,
			--		ParentGLAccountID,
			--		Depth,
			--		IsLeaf,
			--		SummaryParent,
			--		OrderByPath,
			--		[Path],
			--		SummaryParentPath,
			--		0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null,
			--		0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null, 0, 0, null
			--    FROM GetAlternateChartOfAccounts(@accountID, @reportGLAccountTypes, @alternateChartOfAccountsID)
		
			--SELECT  #altInfo.GLAccountID, 
			--		#altInfo.Number AS 'GLAccountNumber',
			--		#altInfo.Name AS 'GLAccountName',
			--		#altInfo.[Description],
			--		LTRIM(#altInfo.GLAccountType) AS 'Type',
			--		#altInfo.ParentGLAccountID,
			--		#altInfo.Depth,
			--		#altInfo.IsLeaf,
			--		#altInfo.SummaryParent,
			--		#altInfo.OrderByPath,
			--		#altInfo.[Path],
			--		#altInfo.SummaryParentPath,
			--		ISNULL(SUM(ISNULL(#AI.JanBudget, 0)), 0) AS 'JanBudget', ISNULL(SUM(ISNULL(#AI.JanActual, 0)), 0) AS 'JanActual', #altInfo.JanNotes,
			--		ISNULL(SUM(ISNULL(#AI.FebBudget, 0)), 0) AS 'FebBudget', ISNULL(SUM(ISNULL(#AI.FebActual, 0)), 0) AS 'FebActual', #altInfo.FebNotes,
			--		ISNULL(SUM(ISNULL(#AI.MarBudget, 0)), 0) AS 'MarBudget', ISNULL(SUM(ISNULL(#AI.MarActual, 0)), 0) AS 'MarActual', #altInfo.MarNotes,
			--		ISNULL(SUM(ISNULL(#AI.AprBudget, 0)), 0) AS 'AprBudget', ISNULL(SUM(ISNULL(#AI.AprActual, 0)), 0) AS 'AprActual', #altInfo.AprNotes,
			--		ISNULL(SUM(ISNULL(#AI.MayBudget, 0)), 0) AS 'MayBudget', ISNULL(SUM(ISNULL(#AI.MayActual, 0)), 0) AS 'MayActual', #altInfo.MayNotes,
			--		ISNULL(SUM(ISNULL(#AI.JunBudget, 0)), 0) AS 'JunBudget', ISNULL(SUM(ISNULL(#AI.JunActual, 0)), 0) AS 'JunActual', #altInfo.JunNotes,
			--		ISNULL(SUM(ISNULL(#AI.JulBudget, 0)), 0) AS 'JulBudget', ISNULL(SUM(ISNULL(#AI.JulActual, 0)), 0) AS 'JulActual', #altInfo.JulNotes,
			--		ISNULL(SUM(ISNULL(#AI.AugBudget, 0)), 0) AS 'AugBudget', ISNULL(SUM(ISNULL(#AI.AugActual, 0)), 0) AS 'AugActual', #altInfo.AugNotes,
			--		ISNULL(SUM(ISNULL(#AI.SepBudget, 0)), 0) AS 'SepBudget', ISNULL(SUM(ISNULL(#AI.SepActual, 0)), 0) AS 'SepActual', #altInfo.SepNotes,
			--		ISNULL(SUM(ISNULL(#AI.OctBudget, 0)), 0) AS 'OctBudget', ISNULL(SUM(ISNULL(#AI.OctActual, 0)), 0) AS 'OctActual', #altInfo.OctNotes,
			--		ISNULL(SUM(ISNULL(#AI.NovBudget, 0)), 0) AS 'NovBudget', ISNULL(SUM(ISNULL(#AI.NovActual, 0)), 0) AS 'NovActual', #altInfo.NovNotes,
			--		ISNULL(SUM(ISNULL(#AI.DecBudget, 0)), 0) AS 'DecBudget', ISNULL(SUM(ISNULL(#AI.DecActual, 0)), 0) AS 'DecActual', #altInfo.DecNotes
			--	 FROM #AlternateInfo #altInfo
			--			INNER JOIN GLAccountAlternateGLAccount altGL ON #altInfo.GLAccountID = altGL.AlternateGLAccountID
			--			INNER JOIN #AllInfo #AI ON altGL.GLAccountID = #AI.GLAccountID	 
			--	 WHERE #altInfo.IsLeaf = 1  
			--	 GROUP BY #altInfo.GLAccountID, #altInfo.Number, #altInfo.Name,	#altInfo.[Description], #altInfo.GLAccountType,	#altInfo.ParentGLAccountID,
			--			  #altInfo.Depth, #altInfo.IsLeaf, #altInfo.SummaryParent, #altInfo.OrderByPath, #altInfo.[Path], #altInfo.SummaryParentPath,
			--			  #altInfo.JanNotes, #altInfo.FebNotes, #altInfo.MarNotes, #altInfo.AprNotes, #altInfo.MayNotes, #altInfo.JunNotes,
			--			  #altInfo.JulNotes, #altInfo.AugNotes, #altInfo.SepNotes, #altInfo.OctNotes, #altInfo.NovNotes, #altInfo.DecNotes			--ORDER BY OrderByPath	
			SELECT  COALESCE(PropertyID, '00000000-0000-0000-0000-000000000000'),
					GLAccountID, 
					Number AS 'GLAccountNumber',
					Name AS 'GLAccountName',
					[Description],
					LTRIM(GLAccountType) AS 'Type',
					ParentGLAccountID,
					Depth,
					IsLeaf,
					SummaryParent,
					OrderByPath,
					[Path],
					SummaryParentPath,
					ISNULL(JanBudget, 0) AS 'JanBudget', ISNULL(JanActual, 0) AS 'JanActual', JanNotes,
					ISNULL(FebBudget, 0) AS 'FebBudget', ISNULL(FebActual, 0) AS 'FebActual', FebNotes,
					ISNULL(MarBudget, 0) AS 'MarBudget', ISNULL(MarActual, 0) AS 'MarActual', MarNotes,
					ISNULL(AprBudget, 0) AS 'AprBudget', ISNULL(AprActual, 0) AS 'AprActual', AprNotes,
					ISNULL(MayBudget, 0) AS 'MayBudget', ISNULL(MayActual, 0) AS 'MayActual', MayNotes,
					ISNULL(JunBudget, 0) AS 'JunBudget', ISNULL(JunActual, 0) AS 'JunActual', JunNotes,
					ISNULL(JulBudget, 0) AS 'JulBudget', ISNULL(JulActual, 0) AS 'JulActual', JulNotes,
					ISNULL(AugBudget, 0) AS 'AugBudget', ISNULL(AugActual, 0) AS 'AugActual', AugNotes,
					ISNULL(SepBudget, 0) AS 'SepBudget', ISNULL(SepActual, 0) AS 'SepActual', SepNotes,																					
					ISNULL(OctBudget, 0) AS 'OctBudget', ISNULL(OctActual, 0) AS 'OctActual', OctNotes,
					ISNULL(NovBudget, 0) AS 'NovBudget', ISNULL(NovActual, 0) AS 'NovActual', NovNotes,
					ISNULL(DecBudget, 0) AS 'DecBudget', ISNULL(DecActual, 0) AS 'DecActual', DecNotes
				FROM #AlternateInfoValues	
				WHERE IsLeaf = 1
			--UNION
			--SELECT	PropertyID, '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', 
			--		0, JanActual, NULL, 0, FebActual, NULL, 0, MarActual, NULL, 0, AprActual, NULL,
			--		0, MayActual, NULL, 0, JunActual, NULL, 0, JulActual, NULL, 0, AugActual, NULL,
			--		0, SepActual, NULL, 0, OctActual, NULL, 0, NovActual, NULL, 0, DecActual, NULL
			--	FROM #AllInfo
			--	WHERE @reportName = 'Cash Flow Statement'
			--	  AND Name = 'Net Income'
				  
			--UNION
			--SELECT	PropertyID, '22222222-2222-2222-2222-222222222222', '', 'Beginning Cash Balance', '', 'Bank', null, 0, 1, 0, '', '', '', 
			--		0, JanActual, NULL, 0, FebActual, NULL, 0, MarActual, NULL, 0, AprActual, NULL,
			--		0, MayActual, NULL, 0, JunActual, NULL, 0, JulActual, NULL, 0, AugActual, NULL,
			--		0, SepActual, NULL, 0, OctActual, NULL, 0, NovActual, NULL, 0, DecActual, NULL
			--	FROM #AllInfo
			--	WHERE @reportName = 'Cash Flow Statement'
			--	  AND Name = 'Beginning Cash Balance')
			ORDER BY OrderByPath
		END
		ELSE
		BEGIN
			SELECT  COALESCE(PropertyID, '00000000-0000-0000-0000-000000000000'),
					GLAccountID, 
					Number AS 'GLAccountNumber',
					Name AS 'GLAccountName',
					[Description],
					LTRIM(GLAccountType) AS 'Type',
					ParentGLAccountID,
					Depth,
					IsLeaf,
					SummaryParent,
					OrderByPath,
					[Path],
					SummaryParentPath,
					ISNULL(JanBudget, 0) AS 'JanBudget', ISNULL(JanActual, 0) AS 'JanActual', JanNotes,
					ISNULL(FebBudget, 0) AS 'FebBudget', ISNULL(FebActual, 0) AS 'FebActual', FebNotes,
					ISNULL(MarBudget, 0) AS 'MarBudget', ISNULL(MarActual, 0) AS 'MarActual', MarNotes,
					ISNULL(AprBudget, 0) AS 'AprBudget', ISNULL(AprActual, 0) AS 'AprActual', AprNotes,
					ISNULL(MayBudget, 0) AS 'MayBudget', ISNULL(MayActual, 0) AS 'MayActual', MayNotes,
					ISNULL(JunBudget, 0) AS 'JunBudget', ISNULL(JunActual, 0) AS 'JunActual', JunNotes,
					ISNULL(JulBudget, 0) AS 'JulBudget', ISNULL(JulActual, 0) AS 'JulActual', JulNotes,
					ISNULL(AugBudget, 0) AS 'AugBudget', ISNULL(AugActual, 0) AS 'AugActual', AugNotes,
					ISNULL(SepBudget, 0) AS 'SepBudget', ISNULL(SepActual, 0) AS 'SepActual', SepNotes,																					
					ISNULL(OctBudget, 0) AS 'OctBudget', ISNULL(OctActual, 0) AS 'OctActual', OctNotes,
					ISNULL(NovBudget, 0) AS 'NovBudget', ISNULL(NovActual, 0) AS 'NovActual', NovNotes,
					ISNULL(DecBudget, 0) AS 'DecBudget', ISNULL(DecActual, 0) AS 'DecActual', DecNotes
			 FROM #AllInfo	
			 WHERE IsLeaf = 1
			 ORDER BY OrderByPath
		 END
	 END
END
GO
