SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[RPT_ACTG_DateRangeFinancialReports] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@reportName nvarchar(50) = null,
	@accountingBasis nvarchar(10) = null,
	@reportStartDate datetime = null,
	@reportEndDate datetime = null,
	@includePOs bit = 0,
	@glAccountIDs GuidCollection READONLY,
	@calculateMonthOnly bit = 0,
	@alternateChartOfAccountsID uniqueidentifier = null,
	@byProperty bit = 0,
	@parameterGLAccountTypes StringCollection READONLY,
	@accountingBookIDs GuidCollection READONLY
AS

DECLARE @fiscalYearBegin tinyint
DECLARE @fiscalYearStartDate datetime
DECLARE @accountID bigint
DECLARE @overrideHide bit = 0
DECLARE @glAccountTypes StringCollection
--DECLARE @accountingPeriodID uniqueidentifier

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	

	CREATE TABLE #Properties (
		PropertyID uniqueidentifier NOT NULL)

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
		CurrentAPAmount money null,
		YTDAmount money null,
		CurrentAPBudget money null,
		YTDBudget money null,
		BudgetNotes nvarchar(MAX) null
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
		SummaryParentPath nvarchar(max) NOT NULL,
		CurrentAPAmount money null,
		YTDAmount money null,
		CurrentAPBudget money null,
		YTDBudget money null,
		BudgetNotes nvarchar(MAX) null
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
		SummaryParentPath nvarchar(max) NOT NULL,
		CurrentAPAmount money null,
		YTDAmount money null,
		CurrentAPBudget money null,
		YTDBudget money null,
		BudgetNotes nvarchar(MAX) null
		)									
	
	CREATE TABLE #AccountingBookIDs (
		AccountingBookID uniqueidentifier NOT NULL)
	
	IF (@byProperty IS NULL)
	BEGIN
		SET @byProperty = 0
	END
	
	INSERT #Properties SELECT Value FROM @propertyIDs

	INSERT #AccountingBookIDs
		SELECT Value
			FROM @accountingBookIDs
	
	SET @accountID = (SELECT DISTINCT AccountID FROM Property WHERE PropertyID IN (SELECT PropertyID FROM #Properties))
	
	DECLARE @includeApprovedPOs bit = (SELECT IncludeApprovedPOsInBudgetVariance FROM Settings WHERE AccountID = @accountID)
	DECLARE @includePendingPOs bit = (SELECT IncludePendingPOsInBudgetVariance FROM Settings WHERE AccountID = @accountID)

	--SET @accountingPeriodID = (SELECT AccountingPeriodID FROM AccountingPeriod WHERE EndDate >= @reportEndDate AND StartDate <= @reportEndDate AND AccountID = @accountID)
	
	IF (@reportName = 'Cash Flow Statement')
	BEGIN					
		INSERT @glAccountTypes VALUES ('Accounts Receivable')
		INSERT @glAccountTypes VALUES ('Other Current Asset')
		INSERT @glAccountTypes VALUES ('Other Asset')
		INSERT @glAccountTypes VALUES ('Accounts Payable')				
		INSERT @glAccountTypes VALUES ('Other Current Liability')						
		INSERT @glAccountTypes VALUES ('Long Term Liability')						
		INSERT @glAccountTypes VALUES ('Fixed Asset')				
		INSERT @glAccountTypes VALUES ('Equity')				
						
		INSERT #AllInfo SELECT 
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
							null
					    FROM GetChartOfAccounts(@accountID, @glAccountTypes)
							LEFT JOIN #Properties #p ON @byProperty = 1
	
	END
	ELSE IF (@reportName IS NULL AND (SELECT COUNT(*) FROM @glAccountIDs) > 0)
	BEGIN
		IF ((@includeApprovedPOs = 1) OR (@includePendingPOs = 1))
		BEGIN
			SET @includePOs = 1
		END
		ELSE 
		BEGIN
			SET @includePOs = 0
		END	
			
		SET @overrideHide = 1
		
		INSERT INTO #AllInfo
			SELECT DISTINCT 
					#p.PropertyID,
					gl.GLAccountID AS 'GLAccountID',					
					gl.Number AS 'GLAccountNumber',
					gl.Name AS 'GLAccountName',
					gl.[Description] AS 'Description',
					gl.GLAccountType AS 'GLAccountType',
					gl.ParentGLAccountID,
					0 AS 'Depth',
					1 AS 'Leaf',
					gl.SummaryParent,
					'' AS 'OrderByPath',
					'' AS 'Path',
					'' AS 'SummaryParentPath',
					null AS 'CurrentAPAmount',
					null AS 'YTDAmount',
					null AS 'CurrentAPBudget',
					null AS 'YTDBudget',
					null AS 'BudgetNotes'
			FROM GLAccount gl
				LEFT JOIN #Properties #p ON @byProperty = 1
			WHERE gl.GLAccountID IN (SELECT Value FROM @glAccountIDs)
			  AND gl.AccountID = @accountID	
	END
	ELSE IF (@reportName = 'Income Statement')
	BEGIN		
		INSERT @glAccountTypes VALUES ('Income')
		INSERT @glAccountTypes VALUES ('Expense')
		INSERT @glAccountTypes VALUES ('Other Income')				
		INSERT @glAccountTypes VALUES ('Other Expense')
		INSERT @glAccountTypes VALUES ('Non-Operating Expense')				
			
		IF (@alternateChartOfAccountsID IS NULL)
		BEGIN	
			INSERT #AllInfo SELECT 
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
								null
							FROM GetChartOfAccounts(@accountID, @glAccountTypes)		
								LEFT JOIN #Properties #p ON @byProperty = 1
		END
		ELSE
		BEGIN
			INSERT #AllInfo SELECT 
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
								null
							FROM GetChartOfAccountsByAlternate(@accountID, @glAccountTypes, @alternateChartOfAccountsID)		
								LEFT JOIN #Properties #p ON @byProperty = 1
		END
	END
	ELSE IF (@reportName = 'Cash Flow Statement Expanded')
	BEGIN		
		-- Income Statement Portion
		INSERT @glAccountTypes VALUES ('Income')
		INSERT @glAccountTypes VALUES ('Expense')
		INSERT @glAccountTypes VALUES ('Other Income')				
		INSERT @glAccountTypes VALUES ('Other Expense')
		INSERT @glAccountTypes VALUES ('Non-Operating Expense')				
		
		-- Cash Flow Statement Portion
		INSERT @glAccountTypes VALUES ('Accounts Receivable')
		INSERT @glAccountTypes VALUES ('Other Current Asset')
		INSERT @glAccountTypes VALUES ('Other Asset')
		INSERT @glAccountTypes VALUES ('Accounts Payable')				
		INSERT @glAccountTypes VALUES ('Other Current Liability')						
		INSERT @glAccountTypes VALUES ('Long Term Liability')						
		INSERT @glAccountTypes VALUES ('Fixed Asset')				
		INSERT @glAccountTypes VALUES ('Equity')									
						
		INSERT #AllInfo SELECT 
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
							null
					    FROM GetChartOfAccounts(@accountID, @glAccountTypes)	
							LEFT JOIN #Properties #p ON @byProperty = 1
	END
	ELSE
	BEGIN
		INSERT INTO #AllInfo
			SELECT DISTINCT 
					#p.PropertyID,
					glac1.ReportLabel AS 'Parent1',
					glac2.ReportLabel AS 'Parent2',
					glac3n.ReportLabel AS 'Parent3',
					rg.OrderBy AS 'OrderBy1',
					rg1.OrderBy AS 'OrderBy2',
					rg2.OrderBy AS 'OrderBy3',
					gla1.Number AS 'GLAccountNumber',
					gla1.Name AS 'GLAccountName',
					gla1.GLAccountType AS 'GLAccountType',
					gla1.GLAccountID AS 'GLAccountID',
					null AS 'CurrentAPAmount',
					null AS 'YTDAmount',
					null AS 'CurrentAPBudget',
					null AS 'YTDBudget',
					null AS 'BudgetNotes'
			FROM ReportGroup rg
				INNER JOIN GLAccountGroup glac1 on rg.ChildGLAccountGroupID = glac1.GLAccountGroupID AND rg.ParentGLAccountGroupID IS NULL
				INNER JOIN ReportGroup rg1 on glac1.GLAccountGroupID = rg1.ParentGLAccountGroupID
				INNER JOIN GLAccountGroup glac2 on rg1.ChildGLAccountGroupID = glac2.GLAccountGroupID AND rg1.ChildGLAccountGroupID IS NOT NULL
				INNER JOIN ReportGroup rg2 on glac2.GLAccountGroupID = rg2.ParentGLAccountGroupID
				INNER JOIN GLAccountGroup glac3n on rg2.ChildGLAccountGroupID = glac3n.GLAccountGroupID 
				INNER JOIN GLAccountGLAccountGroup glgroup1 on glac3n.GLAccountGroupID = glgroup1.GLAccountGroupID
				INNER JOIN GLAccount gla1 on glgroup1.GLAccountID = gla1.GLAccountID
				--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
				LEFT JOIN #Properties #p ON @byProperty = 1
			WHERE rg.ReportName = @reportName
			  --AND rg.AccountID = ap.AccountID	
			  AND rg.AccountID = @accountID
	END

	-- If we provided a list of types to filter this report by, then 
	-- delete out any that shouldn't be in there
	IF ((SELECT COUNT(*) FROM @parameterGLAccountTypes) > 0) 
	BEGIN
		DELETE FROM #AllInfo
		WHERE GLAccountType NOT IN (SELECT Value FROM @parameterGLAccountTypes)
	END
		  
	UPDATE #AllInfo SET CurrentAPAmount = (SELECT ISNULL(SUM(je.Amount), 0)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID													
													INNER JOIN #Properties p ON p.PropertyID = t.PropertyID
													INNER JOIN #AccountingBookIDs #abIDs ON ISNULL(je.AccountingBookID, '55555555-5555-5555-5555-555555555555') = #abIDs.AccountingBookID
												WHERE t.TransactionDate >= @reportStartDate
												  AND t.TransactionDate <= @reportEndDate
												   -- Don't include closing the year entries
												  AND t.Origin NOT IN ('Y', 'E')
												  AND je.GLAccountID = #AllInfo.GLAccountID
												  AND je.AccountingBasis = @accountingBasis
												  AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (t.PropertyID = #AllInfo.PropertyID)))
												  )
	OPTION (RECOMPILE)												  

	IF (@includePOs = 1)
	BEGIN
	
		CREATE TABLE #Statuses (
			[Status] nvarchar(100)
		)

		IF (@includeApprovedPOs = 1)
		BEGIN
			INSERT INTO #Statuses VALUES ('Approved')
			INSERT INTO #Statuses VALUES ('Approved-R')
		END

		IF (@includePendingPOs = 1)
		BEGIN
			INSERT INTO #Statuses VALUES ('Pending Approval')			
		END

		UPDATE #AllInfo SET CurrentAPAmount = ISNULL(CurrentAPAmount, 0) 
															+ (SELECT ISNULL(SUM(poli.GLTotal), 0)
																	FROM PurchaseOrderLineItem poli																	
																		INNER JOIN PurchaseOrder po ON poli.PurchaseOrderID = po.PurchaseOrderID
																		CROSS APPLY GetInvoiceStatusByInvoiceID(poli.PurchaseOrderID, @reportEndDate) AS [Status]
																		INNER JOIN #Properties p ON p.PropertyID = poli.PropertyID
																	WHERE [Status].InvoiceStatus IN (SELECT [Status] FROM #Statuses)
																	  AND po.[Date] >= @reportStartDate
																	  AND po.[Date] <= @reportEndDate																	  
																	  AND poli.GLAccountID = #AllInfo.GLAccountID
																	  AND ((@byProperty = 0) OR ((@byProperty = 1) AND (poli.PropertyID = #AllInfo.PropertyID)))																	  
																	  )
		OPTION (RECOMPILE)																	 

	END		
	
	IF (@alternateChartOfAccountsID IS NOT NULL)
	BEGIN
		INSERT #AlternateInfo SELECT 
							#p.PropertyID,
							GLAccountID,
							Number,
							Name, 
							[Description],
							[GLAccountType],
							ParentGLAccountID,
							Depth, 
							IsLeaf,
							SummaryParent,
							[OrderByPath],
							[Path],
							SummaryParentPath,
							0,
							0,
							0,
							0,
							null								
						 FROM GetAlternateChartOfAccounts(@accountID, @glAccountTypes, @alternateChartOfAccountsID)	
							LEFT JOIN #Properties #p ON @byProperty = 1
		
		INSERT #AlternateInfoValues				 
			SELECT	distinct #info.PropertyID,
					#ai.GLAccountID,
					#ai.Number AS 'GLAccountNumber',
					#ai.Name AS 'GLAccountName',
					#ai.[Description],
					#ai.GLAccountType AS 'Type',
					#ai.ParentGLAccountID,
					#ai.Depth,
					#ai.IsLeaf,
					#ai.SummaryParent,
					#ai.[OrderByPath],
					#ai.[Path],
					#ai.[SummaryParentPath],
					ISNULL(SUM(ISNULL(#info.CurrentAPAmount, 0)), 0) AS 'CurrentAPAmount',
					ISNULL(SUM(ISNULL(#info.YTDAmount, 0)), 0) AS 'YTDAmount',
					ISNULL(SUM(ISNULL(#info.CurrentAPBudget, 0)), 0) AS 'CurrentAPBudget',
					ISNULL(SUM(ISNULL(#info.YTDBudget, 0)), 0) AS 'YTDBudget',
					null
				FROM #AlternateInfo #ai
					INNER JOIN GLAccountAlternateGLAccount altGL ON #ai.GLAccountID = altGL.AlternateGLAccountID 
					INNER JOIN #AllInfo #info ON altGL.GLAccountID = #info.GLAccountID AND (@byProperty = 0 OR #ai.PropertyID = #info.PropertyID)				
				GROUP BY #ai.GLAccountID, #ai.Number, #ai.Name, #ai.[Description], #ai.GLAccountType, #ai.ParentGLAccountID, #ai.Depth,
					#ai.IsLeaf, #ai.SummaryParent, #ai.[OrderByPath], #ai.[Path], #ai.[SummaryParentPath], #info.PropertyID								
			
			INSERT #AlternateInfoValues 
			SELECT	PropertyID, GLAccountID, Number, Name + ' - Other', [Description], GLAccountType, ParentGLAccountID, Depth+1, 1, SummaryParent,
					OrderByPath + '!#' + RIGHT('0000000000' + Number, 10), 
					[Path] + '!#' + Number + ' ' + Name + ' - Other', 
					[SummaryParentPath] + '!#' + CAST(SummaryParent AS nvarchar(10)),
					CurrentAPAmount, YTDAmount, CurrentAPBudget, YTDBudget, BudgetNotes
			FROM #AlternateInfoValues
			WHERE IsLeaf = 0
			  AND (CurrentAPAmount <> 0)					
					
											 		
	END
	ELSE
	BEGIN
		-- Update the non-leaf nodes that have values to display on the report
		INSERT #AllInfo 
		SELECT	PropertyID, GLAccountID, Number, Name + ' - Other', [Description], GLAccountType, ParentGLAccountID, Depth+1, 1, SummaryParent,
				OrderByPath + '!#' + RIGHT('0000000000' + Number, 10), 
				[Path] + '!#' + Number + ' ' + Name + ' - Other', 
				[SummaryParentPath] + '!#' + CAST(SummaryParent AS nvarchar(10)),
				CurrentAPAmount, YTDAmount, CurrentAPBudget, YTDBudget, BudgetNotes
		FROM #AllInfo
		WHERE IsLeaf = 0
		  AND (CurrentAPAmount <> 0)
	END

	IF (@reportName = 'Cash Flow Statement' OR @reportName = 'Cash Flow Statement Expanded')
	BEGIN
		DECLARE @emptyStringCollection StringCollection

		-- Add net income amounts
		-- Temp table to store the income statement
		-- If an AlternateChartOfAccountsID is supplied, we need to UNION two rows into the return set, as done below.
		CREATE TABLE #NetIncomeAccounts (	
			PropertyID uniqueidentifier NULL,	
			PropertyName nvarchar(1000) NULL,
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

		IF (@reportName = 'Cash Flow Statement')
		BEGIN					
			-- Variables to store current and year to date net income amounts
			DECLARE @currentAPNetIncome money
			DECLARE @ytdNetIncome money			
				
			-- Get the Income Statement		
			DECLARE @emptyPlaceholder GuidCollection
			INSERT INTO #NetIncomeAccounts EXEC [RPT_ACTG_DateRangeFinancialReports] @propertyIDs, 'Income Statement', @accountingBasis, @reportStartDate, @reportEndDate, 0, 
													@emptyPlaceholder, 0, null, @byProperty, @emptyStringCollection, @accountingBookIDs
	
			CREATE TABLE #IncomeStatementSums (
				PropertyID uniqueidentifier NULL,
				CurrentAPNetIncome money NULL,
				YTDNetIncome money NULL)							
			
			-- Sum income statement
			--SELECT @currentAPNetIncome = ISNULL(SUM(CurrentAPAmount), 0),
			--	   @ytdNetIncome = ISNULL(SUM(YTDAmount), 0) 
			--FROM #NetIncomeAccounts	
			
			INSERT #IncomeStatementSums 
				SELECT PropertyID, ISNULL(SUM(CurrentAPAmount), 0), ISNULL(SUM(YTDAmount), 0)
					FROM #NetIncomeAccounts
					GROUP BY PropertyID
			
			-- Add a row for the net income
			-- This insert really only applies in the case when there is NOT an AlternateChartOfAccountsID supplied.  In this case, we UNION
			-- this row into	the result set on the final return select.  So if you change this statement, you have to change the two selects below.
			--INSERT INTO #AllInfo VALUES (null, NEWID(), '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', @currentAPNetIncome, @ytdNetIncome, 0, 0, null)
			INSERT INTO #AllInfo
				SELECT PropertyID, '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', CurrentAPNetIncome, YTDNetIncome, 0, 0, null
					FROM #IncomeStatementSums 					    		
					
			INSERT INTO #AlternateInfoValues
				SELECT PropertyID, '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', CurrentAPNetIncome, YTDNetIncome, 0, 0, null
					FROM #IncomeStatementSums 							
		END
		
		-- Add cash beginning balance		
		CREATE TABLE #BankAccounts (
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
			Balance money null	
			)
			
		DECLARE @balanceDate date	
		DECLARE @baGLAccountTypes StringCollection
		INSERT INTO @baGLAccountTypes VALUES ('Bank')			
		DECLARE @currentAPBeginnngCashBalance money
		DECLARE @ytdBeginnngCashBalance money
		
		SET @balanceDate = (SELECT DATEADD(DAY, -1, @reportStartDate))
		INSERT INTO #BankAccounts EXEC [RPT_ACTG_BalanceSheet] @propertyIDs, '', @accountingBasis, @balanceDate, @baGLAccountTypes, null, @byProperty, null, @accountingBookIDs
		
		CREATE TABLE #PropertyBalanceSheetInfo (
			PropertyID uniqueidentifier null,
			YTDBeginningCashBalance money null,
			CurrentAPBeginningCashBalance money null)
		
		IF (@byProperty = 1) 
		BEGIN
			INSERT INTO #PropertyBalanceSheetInfo
				SELECT PropertyID, 0, 0
				FROM #Properties											
		END
		ELSE
		BEGIN
			INSERT INTO #PropertyBalanceSheetInfo
				SELECT null, 0, 0					
		END										        		
		
		UPDATE #PropertyBalanceSheetInfo SET CurrentAPBeginningCashBalance = (SELECT ISNULL(SUM(Balance), 0)
																				FROM #BankAccounts
																				WHERE @byProperty = 0 OR PropertyID = #PropertyBalanceSheetInfo.PropertyID
																				)
								
		--SET @currentAPBeginnngCashBalance = (SELECT SUM(Balance) FROM #BankAccounts)

		-- This insert really only applies in the case when there is NOT an AlternateChartOfAccountsID supplied.  In this case, we UNION
		-- this row into	the result set on the final return select.  So if you change this statement, you have to change the two selects below.
		--INSERT INTO #AllInfo VALUES (NEWID(), '', 'Beginning Cash Balance', '', 'Bank', null, 0, 1, 0 , '', '', '', @currentAPBeginnngCashBalance, @ytdBeginnngCashBalance, 0, 0, null)		
		INSERT INTO #AllInfo
			SELECT	PropertyID, '22222222-2222-2222-2222-222222222222', '', 'Beginning Cash Balance', '', 'Bank', null, 0, 1, 0, '', '', '', 
					CurrentAPBeginningCashBalance, YTDBeginningCashBalance, 0, 0, null
				FROM #PropertyBalanceSheetInfo		
				
		INSERT INTO #AlternateInfoValues
			SELECT	PropertyID, '22222222-2222-2222-2222-222222222222', '', 'Beginning Cash Balance', '', 'Bank', null, 0, 1, 0, '', '', '', 
					CurrentAPBeginningCashBalance, YTDBeginningCashBalance, 0, 0, null
				FROM #PropertyBalanceSheetInfo						
	END				
											  
	--IF (@overrideHide = 0 AND
	--	1 =	(SELECT HideZeroValuesInFinancialReports 
	--			FROM Settings s
	--				INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID AND s.AccountID = ap.AccountID))
					
	IF (@overrideHide = 0 AND
		1 =	(SELECT HideZeroValuesInFinancialReports 
				FROM Settings 

				WHERE AccountID = @accountID))
				
	BEGIN
		IF (@alternateChartOfAccountsID IS NOT NULL)
		BEGIN
			SELECT  p.PropertyID AS 'PropertyID',
					p.Name AS 'PropertyName',
					#ai.GLAccountID, 
					#ai.Number AS 'GLAccountNumber',
					#ai.Name AS 'GLAccountName',
					#ai.[Description],
					LTRIM(#ai.GLAccountType) AS 'Type',
					#ai.ParentGLAccountID,
					#ai.Depth,
					#ai.IsLeaf,
					#ai.SummaryParent,
					#ai.OrderByPath,
					#ai.[Path],
					#ai.SummaryParentPath,
					ISNULL(#ai.CurrentAPAmount, 0) AS 'CurrentAPAmount',
					ISNULL(#ai.YTDAmount, 0) AS 'YTDAmount',
					ISNULL(#ai.CurrentAPBudget, 0) AS 'CurrentAPBudget',
					ISNULL(#ai.YTDBudget, 0) AS 'YTDBudget',
					#ai.BudgetNotes
				FROM #AlternateInfoValues #ai
					LEFT JOIN Property p ON #ai.PropertyID = p.PropertyID
				WHERE CurrentAPAmount <> 0
				   OR YTDAmount <> 0
				   OR CurrentAPAmount <> 0
				   OR YTDBudget <> 0			  
				   OR GLAccountID IN ( '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222')
				   ORDER BY OrderByPath			
								
		END
		ELSE	
		BEGIN
			SELECT  p.PropertyID AS 'PropertyID',
					p.Name AS 'PropertyName',
					#ai.GLAccountID, 
					#ai.Number AS 'GLAccountNumber',
					#ai.Name AS 'GLAccountName',
					#ai.[Description],
					LTRIM(#ai.GLAccountType) AS 'Type',
					#ai.ParentGLAccountID,
					#ai.Depth,
					#ai.IsLeaf,
					#ai.SummaryParent,
					#ai.OrderByPath,
					#ai.[Path],
					#ai.SummaryParentPath,
					ISNULL(#ai.CurrentAPAmount, 0) AS 'CurrentAPAmount',
					ISNULL(#ai.YTDAmount, 0) AS 'YTDAmount',
					ISNULL(#ai.CurrentAPBudget, 0) AS 'CurrentAPBudget',
					ISNULL(#ai.YTDBudget, 0) AS 'YTDBudget',
					#ai.BudgetNotes
				FROM #AllInfo #ai
					LEFT JOIN Property p ON #ai.PropertyID = p.PropertyID
				WHERE IsLeaf = 1
				  AND (CurrentAPAmount <> 0
				   OR YTDAmount <> 0
				   OR CurrentAPBudget <> 0
				   OR YTDBudget <> 0
				   OR GLAccountID IN ( '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'))
				ORDER BY OrderByPath
		END			
	END
	ELSE
	BEGIN	
		IF (@alternateChartOfAccountsID IS NOT NULL)
		BEGIN			
			SELECT  p.PropertyID AS 'PropertyID',
					p.Name AS 'PropertyName',
					#ai.GLAccountID, 
					#ai.Number AS 'GLAccountNumber',
					#ai.Name AS 'GLAccountName',
					#ai.[Description],
					LTRIM(#ai.GLAccountType) AS 'Type',
					#ai.ParentGLAccountID,
					#ai.Depth,
					#ai.IsLeaf,
					#ai.SummaryParent,
					#ai.OrderByPath,
					#ai.[Path],
					#ai.SummaryParentPath,
					ISNULL(#ai.CurrentAPAmount, 0) AS 'CurrentAPAmount',
					ISNULL(#ai.YTDAmount, 0) AS 'YTDAmount',
					ISNULL(#ai.CurrentAPBudget, 0) AS 'CurrentAPBudget',
					ISNULL(#ai.YTDBudget, 0) AS 'YTDBudget',
					#ai.BudgetNotes
				FROM #AlternateInfoValues #ai
					LEFT JOIN Property p ON #ai.PropertyID = p.PropertyID
				WHERE IsLeaf = 1		  
					ORDER BY OrderByPath			
								
		END
		ELSE	
		BEGIN
			SELECT  p.PropertyID AS 'PropertyID',
					p.Name AS 'PropertyName',
					#ai.GLAccountID, 
					#ai.Number AS 'GLAccountNumber',
					#ai.Name AS 'GLAccountName',
					#ai.[Description],
					LTRIM(#ai.GLAccountType) AS 'Type',
					#ai.ParentGLAccountID,
					#ai.Depth,
					#ai.IsLeaf,
					#ai.SummaryParent,
					#ai.OrderByPath,
					#ai.[Path],
					#ai.SummaryParentPath,
					ISNULL(#ai.CurrentAPAmount, 0) AS 'CurrentAPAmount',
					ISNULL(#ai.YTDAmount, 0) AS 'YTDAmount',
					ISNULL(#ai.CurrentAPBudget, 0) AS 'CurrentAPBudget',
					ISNULL(#ai.YTDBudget, 0) AS 'YTDBudget',
					#ai.BudgetNotes
				FROM #AllInfo #ai
					LEFT JOIN Property p ON #ai.PropertyID = p.PropertyID
				WHERE IsLeaf = 1				 
				ORDER BY OrderByPath
		END			
	END
	
			
END






GO
