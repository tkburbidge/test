SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_ACTG_GenerateKeyFinancialReports] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@reportName nvarchar(50) = null,
	@accountingBasis nvarchar(10) = null,
	@accountingPeriodID uniqueidentifier = null,
	@includePOs bit = 0,
	@glAccountIDs GuidCollection READONLY,
	@calculateMonthOnly bit = 0,
	@alternateChartOfAccountsID uniqueidentifier = null,
	@byProperty bit = 0,
	@parameterGLAccountTypes StringCollection READONLY,
	@accountingBookIDs GuidCollection READONLY,
	@alternateBudgetIDs GuidCollection READONLY
AS

--DECLARE @fiscalYearBegin tinyint
--DECLARE @fiscalYearStartDate datetime
--DECLARE @reportEndDate datetime
--DECLARE @reportStartDate datetime
DECLARE @accountID bigint
DECLARE @overrideHide bit = 0
DECLARE @glAccountTypes StringCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	
	
	CREATE TABLE #Properties (
		Sequence int identity,
		PropertyID uniqueidentifier NOT NULL,
		FiscalYearStartDate date NULL,
		StartDate [Date] NULL,
		EndDate [Date] NULL,
		--The column below is for the AccountingPeriod just prior to the FiscalYearStart AccountingPeriod.  It's used to get the report beginning balance information!
		BalanceDateAccounintPeriodID uniqueidentifier NULL,
		AccountingPeriodJustPriorToCurrentAPID uniqueidentifier NULL,
		CashAlternateBudgetID uniqueidentifier NULL,
		AccrualAlternateBudgetID uniqueidentifier NULL)
		
	--CREATE TABLE #PropertiesAndDates (
	--	PropertyID uniqueidentifier NOT NULL,
	--	AccountingPeriodID uniqueidentifier NOT NULL,
	--	StartDate [Date] NOT NULL,
	--	EndDate [Date] NOT NULL,
	--	BalanceDate [Date] NULL)

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
	
	-- Get period start and end dates
	SELECT @accountID = AccountID--,
		   --@reportStartDate = StartDate, 
		   --@reportEndDate = EndDate 
		FROM AccountingPeriod 
		WHERE AccountingPeriodID = @accountingPeriodID	

	INSERT #AccountingBookIDs
		SELECT Value
			FROM @accountingBookIDs

	DECLARE @includeApprovedPOs bit = (SELECT IncludeApprovedPOsInBudgetVariance FROM Settings WHERE AccountID = @accountID)
	DECLARE @includePendingPOs bit = (SELECT IncludePendingPOsInBudgetVariance FROM Settings WHERE AccountID = @accountID)

	IF (@byProperty IS NULL)
	BEGIN
		SET @byProperty = 0
	END
	
	INSERT #Properties SELECT pIDs.Value, NULL, pap.StartDate, pap.EndDate, NULL, NULL, NULL, NULL
		FROM @propertyIDs pIDs
			INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	UPDATE #Properties SET CashAlternateBudgetID = (SELECT YearBudgetID
														FROM YearBudget
														WHERE PropertyID = #Properties.PropertyID
														  AND AccountingBasis = 'Cash'
														  AND @accountingBasis = 'Cash'
														  AND YearBudgetID IN (SELECT Value FROM @alternateBudgetIDs))

	UPDATE #Properties SET AccrualAlternateBudgetID = (SELECT YearBudgetID
														   FROM YearBudget
														   WHERE PropertyID = #Properties.PropertyID
														     AND AccountingBasis = 'Accrual'
															 AND @accountingBasis = 'Accrual'
														     AND YearBudgetID IN (SELECT Value FROM @alternateBudgetIDs))
		
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
				INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
				LEFT JOIN #Properties #p ON @byProperty = 1
			WHERE rg.ReportName = @reportName
			  AND rg.AccountID = ap.AccountID	
	END


 
	-- If we provided a list of types to filter this report by, then 
	-- delete out any that shouldn't be in there
	IF ((SELECT COUNT(*) FROM @parameterGLAccountTypes) > 0) 
	BEGIN



		DELETE 
			FROM #AllInfo
			WHERE GLAccountType NOT IN (SELECT Value FROM @parameterGLAccountTypes)
	END
		  
	UPDATE #AllInfo SET CurrentAPAmount = (SELECT ISNULL(SUM(je.Amount), 0)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
													INNER JOIN #Properties #pad ON t.PropertyID = #pad.PropertyID
													--INNER JOIN #Properties p ON p.PropertyID = t.PropertyID
													INNER JOIN #AccountingBookIDs #abIDs ON ISNULL(je.AccountingBookID, '55555555-5555-5555-5555-555555555555') = #abIDs.AccountingBookID
												WHERE t.TransactionDate >= #pad.StartDate
												  AND t.TransactionDate <= #pad.EndDate
												  -- Don't include closing the year entries
												  AND t.Origin NOT IN ('Y', 'E')
												  AND je.GLAccountID = #AllInfo.GLAccountID
												  AND je.AccountingBasis = @accountingBasis
												  AND (((@byProperty = 0)) OR ((@byProperty = 1) AND (t.PropertyID = #AllInfo.PropertyID)))
												  )
	OPTION (RECOMPILE)

	IF (1 < (SELECT COUNT(*) FROM #Properties WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
	BEGIN
		UPDATE #AllInfo SET CurrentAPBudget = ISNULL((SELECT ISNULL(SUM(ab.Amount), 0)
													FROM AlternateBudget ab
														INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID 
																										AND pap.AccountingPeriodID = @accountingPeriodID
														INNER JOIN #Properties #props ON pap.PropertyID = #props.PropertyID
																		AND (ab.YearBudgetID = #props.AccrualAlternateBudgetID OR ab.YearBudgetID = #props.CashAlternateBudgetID)
													WHERE #props.PropertyID = #AllInfo.PropertyID
													  AND ab.GLAccountID = #AllInfo.GLAccountID
													  AND @byProperty = 1), 0)
			WHERE @byProperty = 1
		OPTION (RECOMPILE)

		UPDATE #AllInfo SET CurrentAPBudget = ISNULL(CurrentAPBudget, 0) + ISNULL((SELECT ISNULL(SUM(ab.Amount), 0)
													FROM AlternateBudget ab
														INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID 
																										AND pap.AccountingPeriodID = @accountingPeriodID
														INNER JOIN #Properties #props ON pap.PropertyID = #props.PropertyID
																		AND (ab.YearBudgetID = #props.AccrualAlternateBudgetID OR ab.YearBudgetID = #props.CashAlternateBudgetID)
													WHERE ab.GLAccountID = #AllInfo.GLAccountID
													  AND @byProperty = 0), 0)
			WHERE @byProperty = 0
		OPTION (RECOMPILE)

		IF (1 < (SELECT COUNT(*) FROM #Properties))
		BEGIN
			UPDATE #AllInfo SET BudgetNotes = ISNULL(BudgetNotes, 'XYZ') + (SELECT '; ' + STUFF((SELECT '; ' + (p.Abbreviation + ':' + ab.Notes)
												 FROM AlternateBudget ab
													INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
													INNER JOIN #Properties #props ON pap.PropertyID = #props.PropertyID
																AND (ab.YearBudgetID = #props.AccrualAlternateBudgetID OR ab.YearBudgetID = #props.CashAlternateBudgetID)
													INNER JOIN Property p ON #props.PropertyID = p.PropertyID
												 WHERE ab.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																									FROM PropertyAccountingPeriod pap
																									INNER JOIN #Properties p ON p.PropertyID = pap.PropertyID
																									WHERE
																									  ((@byProperty = 0) OR ((@byProperty = 1) AND (pap.PropertyID = #AllInfo.PropertyID)))
																									  AND AccountingPeriodID = @accountingPeriodID)
														  AND ab.GLAccountID = #AllInfo.GLAccountID
														  AND ab.Notes IS NOT NULL
														  AND ab.Notes <> ''
												 ORDER BY p.Abbreviation
												 FOR XML PATH ('')), 1, 2, ''))
			OPTION (RECOMPILE)

			UPDATE #ai SET BudgetNotes = REPLACE(BudgetNotes, 'XYZ; ', '')
				FROM #AllInfo #ai
				WHERE (CHARINDEX('XYZ; ', BudgetNotes, 1) = 1)

		END
		ELSE
		BEGIN
			UPDATE #AllInfo SET BudgetNotes = (SELECT b.Notes
												 FROM Budget b
													INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
													INNER JOIN Property p ON pap.PropertyID = p.PropertyID
														WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																									FROM PropertyAccountingPeriod pap
																									INNER JOIN #Properties p ON p.PropertyID = pap.PropertyID
																									WHERE
																									  AccountingPeriodID = @accountingPeriodID)
														  AND b.GLAccountID = #AllInfo.GLAccountID)
		END
	END
	ELSE
	BEGIN
		UPDATE #AllInfo SET CurrentAPBudget = (SELECT CASE
														WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
														WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
														END 
													FROM Budget b
													WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																								FROM PropertyAccountingPeriod pap
																								INNER JOIN #Properties p ON p.PropertyID = pap.PropertyID
																								WHERE
																								  ((@byProperty = 0) OR ((@byProperty = 1) AND (pap.PropertyID = #AllInfo.PropertyID)))
																								  AND AccountingPeriodID = @accountingPeriodID)
													  AND b.GLAccountID = #AllInfo.GLAccountID)
		OPTION (RECOMPILE)
		
		IF ((SELECT COUNT(*) FROM @propertyIDs) > 1) 
		BEGIN												  
			UPDATE #AllInfo SET BudgetNotes = (SELECT STUFF((SELECT '; ' + (p.Abbreviation + ':' + b.Notes)
												 FROM Budget b
													INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
													INNER JOIN Property p ON pap.PropertyID = p.PropertyID
												 WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																									FROM PropertyAccountingPeriod pap
																									INNER JOIN #Properties p ON p.PropertyID = pap.PropertyID
																									WHERE
																									  ((@byProperty = 0) OR ((@byProperty = 1) AND (pap.PropertyID = #AllInfo.PropertyID)))
																									  AND AccountingPeriodID = @accountingPeriodID)
														  AND b.GLAccountID = #AllInfo.GLAccountID
														  AND b.Notes IS NOT NULL
														  AND b.Notes <> ''
												 ORDER BY p.Abbreviation
												 FOR XML PATH ('')), 1, 2, ''))
			OPTION (RECOMPILE)
		
		END
		ELSE
		BEGIN
			UPDATE #AllInfo SET BudgetNotes = (SELECT b.Notes
												 FROM Budget b
													INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
													INNER JOIN Property p ON pap.PropertyID = p.PropertyID
														WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																									FROM PropertyAccountingPeriod pap
																									INNER JOIN #Properties p ON p.PropertyID = pap.PropertyID
																									WHERE
																									  AccountingPeriodID = @accountingPeriodID)
														  AND b.GLAccountID = #AllInfo.GLAccountID)

		END
	END
											
	--SET @fiscalYearStartDate = (SELECT dbo.GetFiscalYearStartDate(@accountID, @accountingPeriodID, (SELECT TOP 1 PropertyID FROM #Properties)))
	UPDATE #Properties SET FiscalYearStartDate = (SELECT dbo.GetFiscalYearStartDate(@accountID, @accountingPeriodID, #Properties.PropertyID))

	IF (@calculateMonthOnly = 0)
	BEGIN
		UPDATE #AllInfo SET YTDBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											FROM Budget b
											WHERE b.GLAccountID = #AllInfo.GLAccountID
											  AND b.PropertyAccountingPeriodID IN (SELECT DISTINCT pap.PropertyAccountingPeriodID
																						FROM PropertyAccountingPeriod pap
																						INNER JOIN #Properties p ON p.PropertyID = pap.PropertyID
																						WHERE
																						   ((@byProperty = 0) OR ((@byProperty = 1) AND (pap.PropertyID = #AllInfo.PropertyID)))																				  
																						  AND pap.StartDate >= p.FiscalYearStartDate
																						  AND pap.EndDate <= p.EndDate))																						  																								
		OPTION (RECOMPILE)
		
		-- If we are running on default books
		IF ('55555555-5555-5555-5555-555555555555' IN (SELECT Value FROM @accountingBookIDs))
		BEGIN											
			UPDATE  #AllInfo SET YTDAmount = (SELECT CASE
														WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.NetMonthlyTotalAccrual), 0)
														WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.NetMonthlyTotalCash), 0)
														END
												 FROM Budget b
												 WHERE b.GLAccountID = #AllInfo.GLAccountID
												   AND b.PropertyAccountingPeriodID IN (SELECT DISTINCT pap.PropertyAccountingPeriodID
																							FROM PropertyAccountingPeriod pap
																								--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID AND pap.Closed = 1
																								INNER JOIN #Properties p ON p.PropertyID = pap.PropertyID
																							WHERE 
																							  ((@byProperty = 0) OR ((@byProperty = 1) AND (pap.PropertyID = #AllInfo.PropertyID)))
																							  -- Do not include the period for which we are running the report
																							  -- as that will be added in in the next query																					  
																							  AND pap.AccountingPeriodID <> @accountingPeriodID


																							  AND pap.Closed = 1
																							  AND pap.StartDate >= p.FiscalYearStartDate
																							  AND pap.EndDate <= p.EndDate))
			OPTION (RECOMPILE)

			UPDATE #AllInfo SET YTDAmount = ISNULL(CurrentAPAmount, 0) + ISNULL(YTDAmount, 0) + (SELECT ISNULL(SUM(je.Amount), 0)
																								FROM JournalEntry je
																									INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																									INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
																									--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
																									INNER JOIN #Properties p ON p.PropertyID = t.PropertyID AND pap.PropertyID = p.PropertyID
																								WHERE
																								   (((@byProperty = 0)) OR ((@byProperty = 1) AND (t.PropertyID = #AllInfo.PropertyID)))
																								  AND t.TransactionDate >= pap.StartDate


																								  AND t.TransactionDate >= p.FiscalYearStartDate
																								  AND t.TransactionDate <= pap.EndDate


																								  AND t.TransactionDate <= p.EndDate
																								  ---- Don't include closing the year entries
																								  AND t.Origin NOT IN ('Y', 'E')
																								  -- Default accounting book
																								  AND je.AccountingBookID IS NULL
																								  AND je.AccountingBasis = @accountingBasis
																								  ---- Do not include the period for which we are running the report
																								  ---- as that will comes from CurrentAPAmount
																								  AND pap.AccountingPeriodID <> @accountingPeriodID
																								  AND je.GLAccountID = #AllInfo.GLAccountID)
			OPTION (RECOMPILE)
		END

		-- Consider other Accounting Books																						  
		IF ((SELECT COUNT(*) FROM @accountingBookIDs WHERE Value <> '55555555-5555-5555-5555-555555555555') > 0)
		BEGIN
			UPDATE #AllInfo SET YTDAmount = ISNULL(YTDAmount, 0) + ISNULL((SELECT ISNULL(SUM(je.Amount), 0)
																		FROM JournalEntry je
																			INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
																			INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID																			
																			INNER JOIN #Properties p ON p.PropertyID = t.PropertyID AND pap.PropertyID = p.PropertyID
																			INNER JOIN #AccountingBookIDs #abIDs ON je.AccountingBookID = #abIDs.AccountingBookID
																		WHERE
																		   (((@byProperty = 0)) OR ((@byProperty = 1) AND (t.PropertyID = #AllInfo.PropertyID)))
																		  AND t.TransactionDate >= pap.StartDate																		  
																		  AND t.TransactionDate >= p.FiscalYearStartDate
																		  AND t.TransactionDate <= pap.EndDate																		 
																		  AND t.TransactionDate <= p.EndDate
																		  ---- Don't include closing the year entries
																		  AND t.Origin NOT IN ('Y', 'E')
																		  AND je.AccountingBasis = @accountingBasis
																		  ---- Do not include the period for which we are running the report
																		  ---- as that will comes from CurrentAPAmount
																		  AND pap.AccountingPeriodID <> @accountingPeriodID
																		  AND je.GLAccountID = #AllInfo.GLAccountID), 0)
		END

	END
														  
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
																		--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
																		INNER JOIN #Properties #pad ON poli.PropertyID = #pad.PropertyID
																		INNER JOIN PurchaseOrder po ON poli.PurchaseOrderID = po.PurchaseOrderID
																		--CROSS APPLY GetInvoiceStatusByInvoiceID(poli.PurchaseOrderID, @reportEndDate) AS [Status]
																		CROSS APPLY GetInvoiceStatusByInvoiceID(poli.PurchaseOrderID, #pad.EndDate) AS [Status]
																		--INNER JOIN #Properties p ON p.PropertyID = poli.PropertyID
																	WHERE [Status].InvoiceStatus IN (SELECT [Status] FROM #Statuses)
																	  --AND po.[Date] >= ap.StartDate
																	  --AND po.[Date] <= ap.EndDate
																	  --AND po.[Date] >= @fiscalYearStartDate
																	  --AND po.[Date] <= @reportEndDate
																	  AND po.[Date] >= #pad.StartDate
																	  AND po.[Date] <= #pad.EndDate
																	  AND po.[Date] >= #pad.FiscalYearStartDate
																	  AND poli.GLAccountID = #AllInfo.GLAccountID
																	  AND ((@byProperty = 0) OR ((@byProperty = 1) AND (poli.PropertyID = #AllInfo.PropertyID)))																	  
																	  )
		OPTION (RECOMPILE)

		IF (@calculateMonthOnly = 0)
		BEGIN
			UPDATE #AllInfo SET YTDAmount = ISNULL(YTDAmount, 0) 
													+ (SELECT ISNULL(SUM(poli.GLTotal), 0)
															FROM PurchaseOrderLineItem poli
																--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
																INNER JOIN PurchaseOrder po ON poli.PurchaseOrderID = po.PurchaseOrderID
																INNER JOIN #Properties #pad ON #pad.PropertyID = poli.PropertyID
																--CROSS APPLY GetInvoiceStatusByInvoiceID(poli.PurchaseOrderID, @reportEndDate) AS [Status]
																CROSS APPLY GetInvoiceStatusByInvoiceID(poli.PurchaseOrderID, #pad.EndDate) AS [Status]
															WHERE [Status].InvoiceStatus IN (SELECT [Status] FROM #Statuses)
															  AND poli.GLAccountID = #AllInfo.GLAccountID
															  --AND po.[Date] >= @fiscalYearStartDate
															  --AND po.[Date] <= @reportEndDate
															  AND po.[Date] >= #pad.FiscalYearStartDate
															  AND po.[Date] <= #pad.EndDate
															  AND ((@byProperty = 0) OR ((@byProperty = 1) AND (poli.PropertyID = #AllInfo.PropertyID)))															  
															  )
			OPTION (RECOMPILE)
		END															  
	END		

/*		  
	Logic
	-----
	If have ACOA
		Populate #AlternateInfo with ACOA
		Populate #AlternateInfoValues from report data (#AllInfo) joining in the ACOA (#AlternateInfo)
		Update non-leaf nodes that have a value to display on the report as XXXX - Other
	Else	
		Update non-leaf nodes that have a value to display on the report as XXXX - Other
		
	If Cash Flow Statement or Cash Flow Statement Expanded
		If Cash Flow Statement
			Put Profit and Loss into #NetIncomeAccounts
			Put Net Income sums intl #IncomeStatementSums
		Get bank balances for YTD and Current from BalanceSheet and put into #BankAccounts	

	If hide zero accounts
		If have ACOA
			Select everything out of AlternateInfo 		
		Else
			Select everything out of #AllInfo
	Else
		If have ACOA
			Select everything out of AlternateInfo 		
		Else
			Select everything out of #AllInfo
*/
		  
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
					--(SELECT STUFF((SELECT '; ' + (#AllInfo.Number + ':' + #AllInfo.BudgetNotes)
					--				   FROM #AllInfo
					--				   WHERE #AllInfo.GLAccountID = #info.GLAccountID
					--				   FOR XML PATH ('')), 1, 2, ''))
				FROM #AlternateInfo #ai
					INNER JOIN GLAccountAlternateGLAccount altGL ON #ai.GLAccountID = altGL.AlternateGLAccountID 
					INNER JOIN #AllInfo #info ON altGL.GLAccountID = #info.GLAccountID AND (@byProperty = 0 OR #ai.PropertyID = #info.PropertyID)
				--WHERE #ai.IsLeaf = 1 AND #info.IsLeaf = 1
				GROUP BY #ai.GLAccountID, #ai.Number, #ai.Name, #ai.[Description], #ai.GLAccountType, #ai.ParentGLAccountID, #ai.Depth,
					#ai.IsLeaf, #ai.SummaryParent, #ai.[OrderByPath], #ai.[Path], #ai.[SummaryParentPath], #info.PropertyID--, #info.GLAccountID							
			
			INSERT #AlternateInfoValues 
			SELECT	PropertyID, GLAccountID, Number, Name + ' - Other', [Description], GLAccountType, ParentGLAccountID, Depth+1, 1, SummaryParent,
					OrderByPath + '!#' + RIGHT('0000000000' + Number, 10), 
					[Path] + '!#' + Number + ' ' + Name + ' - Other', 
					[SummaryParentPath] + '!#' + CAST(SummaryParent AS nvarchar(10)),
					CurrentAPAmount, YTDAmount, CurrentAPBudget, YTDBudget, BudgetNotes
			FROM #AlternateInfoValues
			WHERE IsLeaf = 0
			  AND ((CurrentAPAmount <> 0) OR (YTDAmount <> 0) OR (CurrentAPBudget <> 0) OR (YTDBudget <> 0))	
			  
--select * from #AllInfo
--select * from #AlternateInfoValues			  				
					
		--INSERT #AlternateInfoValues 
		--	SELECT distinct	#info.PropertyID,
		--			#ai.GLAccountID,
		--			#ai.Number AS 'GLAccountNumber',
		--			#ai.Name + ' - Other' AS 'GLAccountName',
		--			#ai.[Description],
		--			#ai.GLAccountType AS 'Type',
		--			#ai.ParentGLAccountID,
		--			#ai.Depth + 1,
		--			1,
		--			#ai.SummaryParent,
		--			#ai.[OrderByPath] + '!#' + RIGHT('0000000000' + #ai.Number, 10),
		--			#ai.[Path] + '!#' + #ai.Number + ' ' + #ai.Name + ' - Other',
		--			#ai.[SummaryParentPath] + '!#' + CAST(#ai.SummaryParent AS nvarchar(10)),
		--			ISNULL(SUM(ISNULL(#info.CurrentAPAmount, 0)), 0) AS 'CurrentAPAmount',
		--			ISNULL(SUM(ISNULL(#info.YTDAmount, 0)), 0) AS 'YTDAmount',
		--			ISNULL(SUM(ISNULL(#info.CurrentAPBudget, 0)), 0) AS 'CurrentAPBudget',
		--			ISNULL(SUM(ISNULL(#info.YTDBudget, 0)), 0) AS 'YTDBudget',
		--			null		
		--		FROM #AlternateInfo #ai
		--			INNER JOIN GLAccountAlternateGLAccount altGL ON #ai.GLAccountID = altGL.AlternateGLAccountID
		--			INNER JOIN #AllInfo #info ON altGL.GLAccountID = #info.GLAccountID AND #ai.PropertyID = #info.PropertyID
		--		WHERE ((#ai.IsLeaf = 1 AND #info.IsLeaf = 0)
		--		   OR (#ai.IsLeaf = 0 AND #info.IsLeaf = 1)) 
		--		GROUP BY #ai.GLAccountID, #ai.Number, #ai.Name,	#ai.[Description], #ai.GLAccountType, #ai.ParentGLAccountID, #ai.Depth,	#ai.SummaryParent,
		--			#ai.[OrderByPath], #ai.[Path], #ai.Number, #ai.Name, #ai.[SummaryParentPath], #info.PropertyID						   
		--		HAVING ((ISNULL(SUM(ISNULL(#info.CurrentAPAmount, 0)), 0) <> 0) OR (ISNULL(SUM(ISNULL(#info.YTDAmount, 0)), 0) <> 0) 
		--		         OR (ISNULL(SUM(ISNULL(#info.CurrentAPBudget, 0)), 0) <> 0) OR (ISNULL(SUM(ISNULL(#info.YTDBudget, 0)), 0) <> 0))
			
											 		
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
		  AND ((CurrentAPAmount <> 0) OR (YTDAmount <> 0) OR (CurrentAPBudget <> 0) OR (YTDBudget <> 0))
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
			INSERT INTO #NetIncomeAccounts EXEC [RPT_ACTG_GenerateKeyFinancialReports] @propertyIDs, 'Income Statement', @accountingBasis, @accountingPeriodID, 0, 
													@emptyPlaceholder, 0, null, @byProperty,@emptyStringCollection, @accountingBookIDs	
	
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
		
		--SET @balanceDate = (SELECT DATEADD(DAY, -1, @fiscalYearStartDate))

		DECLARE @ctr int = 1
		DECLARE @maxCtr int = (SELECT MAX(Sequence) FROM #Properties)
			
		-- Get the AccountingPeriodID of FiscalYearStart minus one
		UPDATE #Properties SET BalanceDateAccounintPeriodID = pap.AccountingPeriodID
			FROM PropertyAccountingPeriod pap
			WHERE pap.StartDate <= DATEADD(DAY, -1, #Properties.FiscalYearStartDate)
			  AND pap.EndDate >= DATEADD(DAY, -1, #Properties.FiscalYearStartDate)
			  AND pap.PropertyID = #Properties.PropertyID
			  AND pap.AccountID = @accountID	

		-- Setup a table to track unique AccountingPeriodIDs
		CREATE TABLE #MyPriorAccountingPeriods (
			Sequence int identity,
			PAPID uniqueidentifier NOT NULL)
			
		INSERT #MyPriorAccountingPeriods
			SELECT DISTINCT	BalanceDateAccounintPeriodID
				FROM #Properties
				
		DECLARE @bdCtr int = 1
		DECLARE @maxBDCtr int = (SELECT MAX(Sequence) FROM #MyPriorAccountingPeriods)
		DECLARE @bdPropertyIDs GuidCollection
		DECLARE @priorFiscalStartDateAPID uniqueidentifier
		
		-- Get the beginning cash balance for the fiscal year for all properties that share the same fiscal year
		WHILE (@bdCtr <= @maxBDCtr)
		BEGIN
			DELETE @bdPropertyIDs 
			-- Add all the PropertyIDs that have the same BalanceDateAccounintPeriodID
			INSERT @bdPropertyIDs
				SELECT #pad.PropertyID
					FROM #MyPriorAccountingPeriods #myPriorAPs
						INNER JOIN #Properties #pad ON #myPriorAPs.PAPID = #pad.BalanceDateAccounintPeriodID  -- Yes, this is right!!!!
					WHERE #myPriorAPs.Sequence = @bdCtr
			
			SET @priorFiscalStartDateAPID = (SELECT PAPID FROM #MyPriorAccountingPeriods WHERE Sequence = @bdCtr)
									

			INSERT INTO #BankAccounts EXEC [RPT_ACTG_BalanceSheet] @bdPropertyIDs, '', @accountingBasis, null, @baGLAccountTypes, @alternateChartOfAccountsID, @byProperty, @priorFiscalStartDateAPID, @accountingBookIDs

			SET @bdCtr = @bdCtr + 1
		END
		
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
        
		UPDATE #PropertyBalanceSheetInfo SET YTDBeginningCashBalance = (SELECT ISNULL(SUM(Balance), 0)
																				FROM #BankAccounts
																				WHERE @byProperty = 0 OR PropertyID = #PropertyBalanceSheetInfo.PropertyID
																				)

		--SET @ytdBeginnngCashBalance = (SELECT SUM(Balance) FROM #BankAccounts)
		
		TRUNCATE TABLE #MyPriorAccountingPeriods
		
		-- Get the AccountingPeriodID of CurrentPeriod minus one
		UPDATE #Properties SET AccountingPeriodJustPriorToCurrentAPID = pap.AccountingPeriodID
			FROM PropertyAccountingPeriod pap
			WHERE pap.StartDate <= DATEADD(DAY, -1, #Properties.StartDate)
			  AND pap.EndDate >= DATEADD(DAY, -1, #Properties.StartDate)
			  AND pap.PropertyID = #Properties.PropertyID
		
		TRUNCATE TABLE #BankAccounts
		

		INSERT #MyPriorAccountingPeriods
			SELECT DISTINCT AccountingPeriodJustPriorToCurrentAPID
				FROM #Properties
				
		SET @bdCtr = 1
		SET @maxBDCtr = (SELECT MAX(Sequence) FROM #MyPriorAccountingPeriods)
			




		DECLARE @priorStartDateAPID uniqueidentifier
		
		-- Get the beginning cash balance for the previous period for all properties that share the same fiscal year
		WHILE (@bdCtr <= @maxBDCtr)
		BEGIN
			DELETE @bdPropertyIDs 
			INSERT @bdPropertyIDs
				SELECT #pad.PropertyID
					FROM #MyPriorAccountingPeriods #myPriorAPs
						INNER JOIN #Properties #pad ON #myPriorAPs.PAPID = #pad.AccountingPeriodJustPriorToCurrentAPID  -- Yes, this is right!!!!
					WHERE #myPriorAPs.Sequence = @bdCtr
			
			SET @priorStartDateAPID = (SELECT PAPID FROM #MyPriorAccountingPeriods WHERE Sequence = @bdCtr)
		
			-- INSERT INTO #BankAccounts EXEC [RPT_ACTG_BalanceSheet] @propertyIDs, '', @accountingBasis, @balanceDate, @baGLAccountTypes, null, @byProperty							
			INSERT INTO #BankAccounts EXEC [RPT_ACTG_BalanceSheet] @bdPropertyIDs, '', @accountingBasis, null, @baGLAccountTypes, @alternateChartOfAccountsID, @byProperty, @priorStartDateAPID, @accountingBookIDs		

			SET @bdCtr = @bdCtr + 1
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
											  
	IF (@overrideHide = 0 AND
		1 =	(SELECT HideZeroValuesInFinancialReports 
				FROM Settings s


				WHERE s.AccountID = @accountID))
	BEGIN
		IF (@alternateChartOfAccountsID IS NOT NULL)
		BEGIN
			SELECT  p.PropertyID,
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
				   AND (CurrentAPAmount <> 0
				   OR YTDAmount <> 0
				   OR CurrentAPAmount <> 0
				   OR YTDBudget <> 0			  
				   OR GLAccountID IN ( '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'))
				   ORDER BY OrderByPath				
								
		END
		ELSE	
		BEGIN
			SELECT  p.PropertyID,
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
			SELECT  p.PropertyID,
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
			SELECT  p.PropertyID,
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
