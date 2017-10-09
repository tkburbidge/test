SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO



/****** Object:  StoredProcedure [dbo].[RPT_ACTG_BalanceSheet]    Script Date: 8/2/2016 11:13:29 AM ******/
CREATE PROCEDURE [dbo].[RPT_ACTG_BalanceSheet] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@reportName nvarchar(50) = null,
	@accountingBasis nvarchar(10) = null,
	@statementDate datetime = null,	
	@glAccountTypes StringCollection READONLY,
	@alternateChartOfAccountsID uniqueidentifier = null,
	@byProperty bit = 0,
	@accountingPeriodID uniqueidentifier = null,
	@accountingBookIDs GuidCollection READONLY
AS

DECLARE @accountID bigint
DECLARE @reportGLAccountTypes StringCollection
DECLARE @alternateBudgetIDs GuidCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))

	CREATE TABLE #BalanceSheetInfo (	
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
		Balance money null	
		)
		
	CREATE TABLE #AlternateBalanceSheetInfo (		
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
		Balance money null	
		)		
	
	CREATE TABLE #AlternateBalanceSheetInfoValues (		
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
		Balance money null	
		)		
		
	CREATE TABLE #PropertiesBS (
		PropertyID uniqueidentifier NOT NULL,
		StatementDate date)

	CREATE TABLE #AccountingBookIDs (
		AccountingBookID uniqueidentifier NOT NULL)
		
	INSERT #PropertiesBS
		SELECT Value, COALESCE(pap.EndDate, @statementDate)
		FROM @propertyIDs pIDs
			LEFT JOIN PropertyAccountingPeriod pap ON pap.PropertyID = pIDs.Value AND pap.AccountingPeriodID = @accountingPeriodID

	INSERT #AccountingBookIDs
		SELECT Value
			FROM @accountingBookIDs
		
	IF ((SELECT COUNT(*) FROM @glAccountTypes) = 0)
	BEGIN
	
		INSERT @reportGLAccountTypes VALUES ('Bank')
		INSERT @reportGLAccountTypes VALUES ('Accounts Receivable')
		INSERT @reportGLAccountTypes VALUES ('Other Current Asset')				
		INSERT @reportGLAccountTypes VALUES ('Fixed Asset')				
		INSERT @reportGLAccountTypes VALUES ('Other Asset')				
		INSERT @reportGLAccountTypes VALUES ('Accounts Payable')
		INSERT @reportGLAccountTypes VALUES ('Other Current Liability')
		INSERT @reportGLAccountTypes VALUES ('Long Term Liability')
		INSERT @reportGLAccountTypes VALUES ('Equity')
			
		INSERT #BalanceSheetInfo SELECT 
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
							0
						 FROM GetChartOfAccounts(@accountID, @reportGLAccountTypes)
							LEFT JOIN #PropertiesBS #p ON @byProperty = 1
	END
	ELSE
	BEGIN
	
		INSERT @reportGLAccountTypes SELECT Value FROM @glAccountTypes
			
		IF (@alternateChartOfAccountsID IS NULL)
		BEGIN
			INSERT #BalanceSheetInfo SELECT 
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
								0
							 FROM GetChartOfAccounts(@accountID, @reportGLAccountTypes)
								LEFT JOIN #PropertiesBS #p ON @byProperty = 1
		END
		ELSE
		BEGIN
			INSERT #BalanceSheetInfo SELECT 
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
								0
							 FROM GetChartOfAccountsByAlternate(@accountID, @reportGLAccountTypes, @alternateChartOfAccountsID)
								LEFT JOIN #PropertiesBS #p ON @byProperty = 1
		END
	END
	--ELSE 
	--BEGIN
	--	INSERT INTO #BalanceSheetInfo
	--		SELECT DISTINCT 
	--				gl.GLAccountID AS 'GLAccountID',					
	--				gl.Number AS 'GLAccountNumber',
	--				gl.Name AS 'GLAccountName',
	--				gl.[Description] AS 'Description',
	--				gl.GLAccountType AS 'GLAccountType',
	--				gl.ParentGLAccountID,
	--				0 AS 'Depth',
	--				1 AS 'Leaf',
	--				'' AS 'OrderByPath',
	--				'' AS 'Path',
	--				0 AS 'Balance'
	--		FROM GLAccount gl
	--		WHERE gl.GLAccountID IN (SELECT Value FROM @glAccountIDs)
	--		  AND gl.AccountID = @accountID	
	--END	
			  
	IF ('55555555-5555-5555-5555-555555555555' IN (SELECT Value FROM @accountingBookIDs))
	BEGIN
		UPDATE #BalanceSheetInfo SET Balance = (SELECT ISNULL(SUM(je.Amount), 0)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID														
														INNER JOIN #PropertiesBS p ON p.PropertyID = t.PropertyID
													WHERE 
													   t.TransactionDate <= p.StatementDate
													  -- Don't include closing the year entries
													  AND t.Origin NOT IN ('Y')
													  AND je.GLAccountID = #BalanceSheetInfo.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND je.AccountingBookID IS NULL
													  -- Either the period isn't closed or we are running the report for a date inbetween a period
													  -- or we are looking at a close year entry to the retained earnings account																									  
													  AND ((@byProperty = 0) OR ((@byProperty = 1 AND t.PropertyID = #BalanceSheetInfo.PropertyID)))
													  )
			OPTION (RECOMPILE)
			
		
	END

	IF ((SELECT COUNT(*) FROM @accountingBookIDs WHERE Value <> '55555555-5555-5555-5555-555555555555') > 0)
	BEGIN
		-- Include other AccountingBooks as necessary.
		UPDATE #BalanceSheetInfo SET Balance = ISNULL(Balance, 0) + (SELECT ISNULL(SUM(je.Amount), 0)
																		FROM JournalEntry je
																			INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																			INNER JOIN #PropertiesBS p ON p.PropertyID = t.PropertyID
																			INNER JOIN #AccountingBookIDs #abIDs ON je.AccountingBookID = #abIDs.AccountingBookID
																		WHERE je.GLAccountID = #BalanceSheetInfo.GLAccountID
																		  -- Don't include closing the year entries
																		  AND t.Origin NOT IN ('Y')
																		  AND je.AccountingBasis = @accountingBasis
																		  -- Either the period isn't closed or we are running the report for a date inbetween a period
																		  -- or we are looking at a close year entry to the retained earnings account
																		  AND t.TransactionDate <= p.StatementDate												
																		  AND ((@byProperty = 0) OR ((@byProperty = 1 AND t.PropertyID = #BalanceSheetInfo.PropertyID)))
																		  )
		
		
		OPTION (RECOMPILE)
	END
	
	IF ((SELECT COUNT(*) FROM @glAccountTypes) = 0)
	BEGIN
		
		-- Get net income numbers
		CREATE TABLE #NetIncome
		(
			PropertyID uniqueidentifier NULL,
			YTDIncome money,
			CurrentIncome money,
			LastYearIncome money
		)
		
		-- We are ok using @statementDate here because this is only called when we are running the
		-- Balance Sheet report which is always on a given date not a period
		INSERT INTO #NetIncome EXEC RPT_ACTG_IncomeStatementTotals @propertyIDs, 'Income Statement', @accountingBasis, @statementDate, @byProperty, @alternateChartOfAccountsID, @accountingBookIDs,
														@alternateBudgetIDs, @accountingPeriodID

		--DECLARE @ytdIncome money
		--DECLARE @lastYearIncome money
		
		--SELECT @ytdIncome = YTDIncome, @lastYearIncome = LastYearIncome FROM #NetIncome
		
		-- Add net income to the return set
		--INSERT INTO #BalanceSheetInfo VALUES ('11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', @ytdIncome)
		--INSERT INTO #BalanceSheetInfo VALUES ('22222222-2222-2222-2222-222222222222', '', 'Previous years calculated Net Income', '', 'Income', null, 0, 1, 0, '', '', '', @lastYearIncome)
		INSERT INTO #BalanceSheetInfo
			SELECT PropertyID, '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', YTDIncome
				FROM #NetIncome
				
		INSERT INTO #AlternateBalanceSheetInfoValues
			SELECT PropertyID, '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', YTDIncome
				FROM #NetIncome				
		--INSERT INTO #BalanceSheetInfo
		--	SELECT PropertyID, '22222222-2222-2222-2222-222222222222', '', 'Previous years calculated Net Income', '', 'Income', null, 0, 1, 0, '', '', '', LastYearIncome 
		--		FROM #NetIncome 
	
	END
														   
	--INSERT #BalanceSheetInfo 
	--	SELECT	GLAccountID, Number, Name + ' - Other', [Description], GLAccountType, ParentGLAccountID, Depth+1, 1, SummaryParent,
	--			OrderByPath + '/' + RIGHT('0000000000' + Number, 10), 
	--			[Path] + '/' + Number + ' - ' + Name + ' - Other', 
	--			[SummaryParentPath] + '/' + CAST(SummaryParent AS nvarchar(10)),
	--			Balance
	--	FROM #BalanceSheetInfo
	--	WHERE IsLeaf = 0
	--	  AND Balance <> 0 			
	
	IF (@alternateChartOfAccountsID IS NOT NULL)
	BEGIN
		INSERT #AlternateBalanceSheetInfo 
				SELECT 
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
					0
				 FROM GetAlternateChartOfAccounts(@accountID, @reportGLAccountTypes, @alternateChartOfAccountsID)	
					LEFT JOIN #PropertiesBS #p ON @byProperty = 1
							
		INSERT INTO #AlternateBalanceSheetInfoValues							 	
			SELECT	#absi.PropertyID,
					#absi.GLAccountID,
					#absi.Number,
					#absi.Name,
					#absi.[Description],
					#absi.GLAccountType AS 'Type',
					#absi.ParentGLAccountID,
					#absi.Depth,
					#absi.IsLeaf,
					#absi.SummaryParent,
					#absi.[OrderByPath],
					#absi.[Path],
					#absi.[SummaryParentPath],
					--ISNULL(Balance, 0) AS 'Balance'
					ISNULL(SUM(ISNULL(#bsi.Balance, 0)), 0) AS [Balance]
				FROM #AlternateBalanceSheetInfo #absi
					INNER JOIN GLAccountAlternateGLAccount altGL ON #absi.GLAccountID = altGL.AlternateGLAccountID
					INNER JOIN #BalanceSheetInfo #bsi ON altGL.GLAccountID = #bsi.GLAccountID AND (@byProperty = 0 OR #absi.PropertyID = #bsi.PropertyID)
				---WHERE #absi.IsLeaf = 1 AND #bsi.IsLeaf = 1
				GROUP BY #absi.GLAccountID, #absi.PropertyID, #absi.Number, #absi.Name, #absi.[Description], #absi.GLAccountType, #absi.ParentGLAccountID, #absi.Depth,
					#absi.IsLeaf, #absi.SummaryParent, #absi.[OrderByPath], #absi.[Path], #absi.[SummaryParentPath]
					
		INSERT #AlternateBalanceSheetInfoValues 
			SELECT	PropertyID, GLAccountID, Number, Name + ' - Other', [Description], GLAccountType, ParentGLAccountID, Depth+1, 1, 0,
					OrderByPath + '!#' + RIGHT('0000000000' + Number, 10), 
					[Path] + '!#' + Number + ' - ' + Name + ' - Other',
					[SummaryParentPath] + '!#' + CAST(SummaryParent AS nvarchar(10)),
					 Balance
			FROM #AlternateBalanceSheetInfoValues
			WHERE IsLeaf = 0
			  AND Balance <> 0 					
	END
	ELSE
	BEGIN
																				   
		INSERT #BalanceSheetInfo 
			SELECT	PropertyID, GLAccountID, Number, Name + ' - Other', [Description], GLAccountType, ParentGLAccountID, Depth+1, 1, 0,
					OrderByPath + '!#' + RIGHT('0000000000' + Number, 10), 
					[Path] + '!#' + Number + ' - ' + Name + ' - Other',
					[SummaryParentPath] + '!#' + CAST(SummaryParent AS nvarchar(10)),
					 Balance
			FROM #BalanceSheetInfo
			WHERE IsLeaf = 0
			  AND Balance <> 0 

	END										   
													   
	IF (1 =	(SELECT HideZeroValuesInFinancialReports 
				FROM Settings s
				WHERE s.AccountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))))
	BEGIN
		IF (@alternateChartOfAccountsID IS NOT NULL)
		BEGIN
			SELECT	PropertyID,
					GLAccountID,
					Number,
					Name,
					[Description],
					GLAccountType AS 'Type',
					ParentGLAccountID,
					Depth,
					IsLeaf,
					SummaryParent,
					[OrderByPath],
					[Path],
					[SummaryParentPath],
					ISNULL(Balance, 0) AS 'Balance'
				FROM #AlternateBalanceSheetInfoValues
				WHERE IsLeaf = 1
					AND Balance <> 0
				ORDER BY OrderByPath
				   
			--INSERT #AlternateBalanceSheetInfo 
			--	SELECT 
			--		#p.PropertyID,
			--		GLAccountID,
			--		Number,
			--		Name, 
			--		[Description],
			--		[GLAccountType],
			--		ParentGLAccountID,
			--		Depth, 
			--		IsLeaf,
			--		SummaryParent,
			--		[OrderByPath],
			--		[Path],
			--		SummaryParentPath,
			--		0
			--	 FROM GetAlternateChartOfAccounts(@accountID, @reportGLAccountTypes, @alternateChartOfAccountsID)	
			--		LEFT JOIN #Properties #p ON @byProperty = 1
							 	
			--SELECT	#absi.PropertyID,
			--		#absi.GLAccountID,
			--		#absi.Number,
			--		#absi.Name,
			--		#absi.[Description],
			--		#absi.GLAccountType AS 'Type',
			--		#absi.ParentGLAccountID,
			--		#absi.Depth,
			--		#absi.IsLeaf,
			--		#absi.SummaryParent,
			--		#absi.[OrderByPath],
			--		#absi.[Path],
			--		#absi.[SummaryParentPath],
			--		--ISNULL(Balance, 0) AS 'Balance'
			--		ISNULL(SUM(ISNULL(#bsi.Balance, 0)), 0) AS [Balance]
			--	FROM #AlternateBalanceSheetInfo #absi
			--		INNER JOIN GLAccountAlternateGLAccount altGL ON #absi.GLAccountID = altGL.AlternateGLAccountID
			--		INNER JOIN #BalanceSheetInfo #bsi ON altGL.GLAccountID = #bsi.GLAccountID AND #absi.PropertyID = #bsi.PropertyID				
			--	WHERE #absi.IsLeaf = 1 AND #bsi.IsLeaf = 1
			--	GROUP BY #absi.GLAccountID, #absi.Number, #absi.Name, #absi.[Description], #absi.GLAccountType, #absi.ParentGLAccountID, #absi.Depth,
			--		#absi.IsLeaf, #absi.SummaryParent, #absi.[OrderByPath], #absi.[Path], #absi.[SummaryParentPath]
			--	HAVING ISNULL(SUM(ISNULL(#bsi.Balance, 0)), 0) <> 0
				
			--UNION
			--	--SELECT '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', @ytdIncome
			--	--	WHERE @ytdIncome <> 0
			--	--	  AND (0 = (SELECT COUNT(*) FROM @glAccountTypes))
			--	SELECT PropertyID, '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', YTDIncome
			--		FROM #NetIncome
			--		WHERE YTDIncome <> 0
					  
			--UNION
			--	--SELECT '22222222-2222-2222-2222-222222222222', '', 'Previous years calculated Net Income', '', 'Income', null, 0, 1, 0, '', '', '', @lastYearIncome
			--	--	WHERE @lastYearIncome <> 0
			--	--	  AND (0 = (SELECT COUNT(*) FROM @glAccountTypes))
			--	SELECT PropertyID, '22222222-2222-2222-2222-222222222222', '', 'Previous years calculated Net Income', '', 'Income', null, 0, 1, 0, '', '', '', LastYearIncome 
			--		FROM #NetIncome 
			--		WHERE LastYearIncome <> 0
					  
			--UNION
			--	SELECT	#bsi.PropertyID,
			--			#absi.GLAccountID,
			--			#absi.Number,
			--			#absi.Name,
			--			#absi.[Description],
			--			#absi.GLAccountType AS 'Type',
			--			#absi.ParentGLAccountID,
			--			#absi.Depth,
			--			#absi.IsLeaf,
			--			#absi.SummaryParent,
			--			#absi.[OrderByPath],
			--			#absi.[Path],
			--			#absi.[SummaryParentPath],
			--			--ISNULL(Balance, 0) AS 'Balance'
			--			#bsi.Balance
			--		FROM #AlternateBalanceSheetInfo #absi
			--			INNER JOIN GLAccountAlternateGLAccount altGL ON #absi.GLAccountID = altGL.AlternateGLAccountID
			--			INNER JOIN #BalanceSheetInfo #bsi ON altGL.GLAccountID = #bsi.GLAccountID AND #absi.PropertyID = #bsi.PropertyID					
			--		WHERE #absi.IsLeaf = 0 OR #bsi.IsLeaf = 0
			--		GROUP BY #absi.GLAccountID, #absi.Number, #absi.Name, #absi.[Description], #absi.GLAccountType, #absi.ParentGLAccountID, #absi.Depth,
			--			#absi.IsLeaf, #absi.SummaryParent, #absi.[OrderByPath], #absi.[Path], #absi.[SummaryParentPath], #bsi.Balance
			--		HAVING ISNULL(SUM(ISNULL(#bsi.Balance, 0)), 0) <> 0
			--	ORDER BY OrderByPath			
				
		END
		ELSE
		BEGIN
			SELECT	PropertyID,
					GLAccountID,
					Number,
					Name,
					[Description],
					GLAccountType AS 'Type',
					ParentGLAccountID,
					Depth,
					IsLeaf,
					SummaryParent,
					[OrderByPath],
					[Path],
					[SummaryParentPath],
					ISNULL(Balance, 0) AS 'Balance'
				FROM #BalanceSheetInfo
				WHERE Balance <> 0	
					AND IsLeaf = 1	
				ORDER BY OrderByPath						
		END
	END
	ELSE
	BEGIN
		IF (@alternateChartOfAccountsID IS NOT NULL)
		BEGIN
			SELECT	PropertyID,
					GLAccountID,
					Number,
					Name,
					[Description],
					GLAccountType AS 'Type',
					ParentGLAccountID,
					Depth,
					IsLeaf,
					SummaryParent,
					[OrderByPath],
					[Path],
					[SummaryParentPath],
					ISNULL(Balance, 0) AS 'Balance'
				FROM #AlternateBalanceSheetInfoValues
				WHERE IsLeaf = 1					
				ORDER BY OrderByPath
			--INSERT #AlternateBalanceSheetInfo 
			--	SELECT 
			--		#p.PropertyID,
			--		GLAccountID,
			--		Number,
			--		Name, 
			--		[Description],
			--		[GLAccountType],
			--		ParentGLAccountID,
			--		Depth, 
			--		IsLeaf,
			--		SummaryParent,
			--		[OrderByPath],
			--		[Path],
			--		SummaryParentPath,
			--		0
			--	 FROM GetAlternateChartOfAccounts(@accountID, @reportGLAccountTypes, @alternateChartOfAccountsID)	
			--		LEFT JOIN #Properties #p ON @byProperty = 1	
			--SELECT	#absi.PropertyID,
			--		#absi.GLAccountID,
			--		#absi.Number,
			--		#absi.Name,
			--		#absi.[Description],
			--		#absi.GLAccountType AS 'Type',
			--		#absi.ParentGLAccountID,
			--		#absi.Depth,
			--		#absi.IsLeaf,
			--		#absi.SummaryParent,
			--		#absi.[OrderByPath],
			--		#absi.[Path],
			--		#absi.[SummaryParentPath],
			--		--ISNULL(Balance, 0) AS 'Balance'
			--		ISNULL(SUM(ISNULL(#bsi.Balance, 0)), 0) AS [Balance]
			--	FROM #AlternateBalanceSheetInfo #absi
			--		INNER JOIN GLAccountAlternateGLAccount altGL ON #absi.GLAccountID = altGL.AlternateGLAccountID
			--		INNER JOIN #BalanceSheetInfo #bsi ON altGL.GLAccountID = #bsi.GLAccountID AND #absi.PropertyID = #bsi.PropertyID				
			--	WHERE #absi.IsLeaf = 1 AND #bsi.IsLeaf = 1
			--	GROUP BY #absi.GLAccountID, #absi.Number, #absi.Name, #absi.[Description], #absi.GLAccountType, #absi.ParentGLAccountID, #absi.Depth,
			--		#absi.IsLeaf, #absi.SummaryParent, #absi.[OrderByPath], #absi.[Path], #absi.[SummaryParentPath], #absi.PropertyID
				
			----UNION
			----	--SELECT '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', @ytdIncome
			----	--	WHERE (0 = (SELECT COUNT(*) FROM @glAccountTypes))
			----	SELECT PropertyID, '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', YTDIncome
			----		FROM #NetIncome				
					  
			----UNION
			----	--SELECT '22222222-2222-2222-2222-222222222222', '', 'Previous years calculated Net Income', '', 'Income', null, 0, 1, 0, '', '', '', @lastYearIncome
			----	--	WHERE (0 = (SELECT COUNT(*) FROM @glAccountTypes))
			----	SELECT PropertyID, '22222222-2222-2222-2222-222222222222', '', 'Previous years calculated Net Income', '', 'Income', null, 0, 1, 0, '', '', '', LastYearIncome 
			----		FROM #NetIncome 
					
			----UNION
			----	SELECT	#absi.PropertyID,
			----			#absi.GLAccountID,
			----			#absi.Number,
			----			#absi.Name + ' - Other',
			----			#absi.[Description],
			----			#absi.GLAccountType AS 'Type',
			----			#absi.ParentGLAccountID,
			----			#absi.Depth + 1,
			----			1,
			----			#absi.SummaryParent,
			----			#absi.[OrderByPath] + '!#' + RIGHT('0000000000' + #absi.Number, 10),
			----			#absi.[Path] + '!#' + #absi.Number + ' - ' + #absi.Name + ' - Other',
			----			#absi.[SummaryParentPath] + '!#' + CAST(#absi.SummaryParent AS nvarchar(10)),
			----			--ISNULL(Balance, 0) AS 'Balance'
			----			#bsi.Balance
			----		FROM #AlternateBalanceSheetInfo #absi
			----			INNER JOIN GLAccountAlternateGLAccount altGL ON #absi.GLAccountID = altGL.AlternateGLAccountID
			----			INNER JOIN #BalanceSheetInfo #bsi ON altGL.GLAccountID = #bsi.GLAccountID AND #absi.PropertyID = #bsi.PropertyID					
			----		WHERE #absi.IsLeaf = 0 OR #bsi.IsLeaf = 0
			----		GROUP BY #absi.GLAccountID, #absi.Number, #absi.Name, #absi.[Description], #absi.GLAccountType, #absi.ParentGLAccountID, #absi.Depth,
			----			#absi.IsLeaf, #absi.SummaryParent, #absi.[OrderByPath], #absi.[Path], #absi.[SummaryParentPath], #bsi.Balance, #absi.PropertyID
			----		HAVING ISNULL(SUM(ISNULL(#bsi.Balance, 0)), 0) <> 0
			--	ORDER BY #absi.OrderByPath								
		END
		ELSE
		BEGIN													  
			SELECT	PropertyID,
					GLAccountID,
					Number,
					Name,
					[Description],
					GLAccountType AS 'Type',
					ParentGLAccountID,
					Depth,
					IsLeaf,
					SummaryParent,
					[OrderByPath],
					[Path],
					[SummaryParentPath],
					ISNULL(Balance, 0) AS 'Balance'
				FROM #BalanceSheetInfo			
				WHERE IsLeaf = 1
		END
	END	
END






GO
