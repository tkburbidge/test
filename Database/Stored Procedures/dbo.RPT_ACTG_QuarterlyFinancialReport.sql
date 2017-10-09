SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO


-- GOOD QuarterlyFinancial REport - P&L
-- =============================================
-- Author:		Nick Olsen
-- Create date: Dec 3, 2012
-- Description:	Gets the quarterly financial statement numbers
-- =============================================
CREATE PROCEDURE [dbo].[RPT_ACTG_QuarterlyFinancialReport]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY, 
	@reportName nvarchar(50) = null,
	@accountingBasis nvarchar(10) = null,
	@accountingPeriodID uniqueidentifier = null,
	@includePOs bit	= 0,
	@alternateChartOfAccountsID uniqueidentifier = null,
	@byProperty bit = 0,
	@parameterGLAccountTypes StringCollection READONLY,
	@accountingBookIDs GuidCollection READONLY,
	@alternateBudgetIDs GuidCollection READONLY
AS

DECLARE @fiscalYearBegin tinyint
DECLARE @fiscalYearStartDate datetime
DECLARE @endDate datetime
DECLARE @glAccountTypes StringCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #QuarterFinancialAccounts (	
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
		SummaryParentPath nvarchar(max) NULL,
		Month1Budget money NULL default 0,
		Month1Actual money NULL default 0,		
		Month2Budget money NULL default 0,
		Month2Actual money NULL default 0,		
		Month3Budget money NULL default 0,
		Month3Actual money NULL default 0			
		)
		
	CREATE TABLE #AlternateQFA (
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
		SummaryParentPath nvarchar(max) NULL,
		Month1Budget money NULL default 0,
		Month1Actual money NULL default 0,		
		Month2Budget money NULL default 0,
		Month2Actual money NULL default 0,		
		Month3Budget money NULL default 0,
		Month3Actual money NULL default 0			
		)	
		
	CREATE TABLE #AlternateQFAValues (
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
		SummaryParentPath nvarchar(max) NULL,
		Month1Budget money NULL default 0,
		Month1Actual money NULL default 0,		
		Month2Budget money NULL default 0,
		Month2Actual money NULL default 0,		
		Month3Budget money NULL default 0,
		Month3Actual money NULL default 0			
		)			
		
	CREATE NONCLUSTERED INDEX [IX_#QuarterFinancialAccounts_GLAccount] ON [#QuarterFinancialAccounts] 
	(
		[GLAccountID] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	
	CREATE TABLE #PropertiesQFR (
		PropertyID uniqueidentifier NOT NULL)

	CREATE TABLE #AccountingBookIDs (
		AccountingBookID uniqueidentifier NOT NULL)

	CREATE TABLE #PropertiesAndAlternateBudgets (
		PropertyID uniqueidentifier NOT NULL,
		CashAlternateBudgetID uniqueidentifier NULL,
		AccrualAlternateBudgetID uniqueidentifier NULL)
		
	INSERT #PropertiesQFR
		SELECT Value FROM @propertyIDs

	INSERT #AccountingBookIDs
		SELECT Value FROM @accountingBookIDs

	INSERT #PropertiesAndAlternateBudgets
		SELECT PropertyID FROM #PropertiesQFR


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
						
		INSERT #QuarterFinancialAccounts 
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
						0,
						0,
						0,
						0,
						0,
						0
				    FROM GetChartOfAccounts(@accountID, @glAccountTypes)	
						LEFT JOIN #PropertiesQFR #p ON @byProperty = 1
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
			INSERT #QuarterFinancialAccounts 
				SELECT 
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
					0,
					0
					FROM GetChartOfAccounts(@accountID, @glAccountTypes)		
						LEFT JOIN #PropertiesQFR #p ON @byProperty = 1
		END
		ELSE
		BEGIN
				INSERT #QuarterFinancialAccounts 
					SELECT 
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
						0,
						0
						FROM GetChartOfAccountsByAlternate(@accountID, @glAccountTypes, @alternateChartOfAccountsID)		
							LEFT JOIN #PropertiesQFR #p ON @byProperty = 1
		END
	END
	--ELSE
	--BEGIN
	--	INSERT INTO #QuarterFinancialAccounts
	--		SELECT DISTINCT 
	--				glac1.ReportLabel AS 'Parent1',
	--				glac2.ReportLabel AS 'Parent2',
	--				glac3n.ReportLabel AS 'Parent3',
	--				rg.OrderBy AS 'OrderBy1',
	--				rg1.OrderBy AS 'OrderBy2',
	--				rg2.OrderBy AS 'OrderBy3',
	--				gla1.Number AS 'GLAccountNumber',
	--				gla1.Name AS 'GLAccountName',
	--				gla1.GLAccountID AS 'GLAccountID',
	--				gla1.GLAccountType AS 'GLAccountType',
	--				0 AS 'Month1Budget', 0 AS 'Month1Actual',
	--				0 AS 'Month2Budget', 0 AS 'Month2Amount',
	--				0 AS 'Month3Budget', 0 AS 'Month3Amount'					
	--		FROM ReportGroup rg
	--			INNER JOIN GLAccountGroup glac1 on rg.ChildGLAccountGroupID = glac1.GLAccountGroupID AND rg.ParentGLAccountGroupID IS NULL
	--			INNER JOIN ReportGroup rg1 on glac1.GLAccountGroupID = rg1.ParentGLAccountGroupID
	--			INNER JOIN GLAccountGroup glac2 on rg1.ChildGLAccountGroupID = glac2.GLAccountGroupID AND rg1.ChildGLAccountGroupID IS NOT NULL
	--			INNER JOIN ReportGroup rg2 on glac2.GLAccountGroupID = rg2.ParentGLAccountGroupID
	--			INNER JOIN GLAccountGroup glac3n on rg2.ChildGLAccountGroupID = glac3n.GLAccountGroupID 
	--			INNER JOIN GLAccountGLAccountGroup glgroup1 on glac3n.GLAccountGroupID = glgroup1.GLAccountGroupID
	--			INNER JOIN GLAccount gla1 on glgroup1.GLAccountID = gla1.GLAccountID
	--			INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
	--		WHERE rg.ReportName = @reportName
	--		  AND rg.AccountID = ap.AccountID	
	--END
		  
    --SELECT @endDate = EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID	
    
	-- If we provided a list of types to filter this report by, then 
	-- delete out any that shouldn't be in there
	IF ((SELECT COUNT(*) FROM @parameterGLAccountTypes) > 0) 
	BEGIN
		DELETE FROM #QuarterFinancialAccounts
		WHERE GLAccountType NOT IN (SELECT Value FROM @parameterGLAccountTypes)
	END


	DECLARE @month0APID uniqueidentifier = (SELECT TOP 1 AccountingPeriodID
									    FROM (SELECT TOP 3 AccountingPeriodID, EndDate
											  FROM AccountingPeriod ap 
											  WHERE AccountID = @accountID
												AND ap.EndDate < (SELECT EndDate From AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
											  ORDER BY EndDate DESC) Dates
										ORDER BY EndDate)
	
	DECLARE @month1APID uniqueidentifier = (SELECT TOP 1 AccountingPeriodID
										    FROM (SELECT TOP 2 AccountingPeriodID, EndDate
												  FROM AccountingPeriod ap 
												  WHERE AccountID = @accountID
													AND ap.EndDate < (SELECT EndDate From AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
												  ORDER BY EndDate DESC) Dates
											ORDER BY EndDate)
	DECLARE @month2APID uniqueidentifier = (SELECT TOP 1 AccountingPeriodID
											FROM AccountingPeriod ap 
											WHERE AccountID = @accountID
												AND ap.EndDate < (SELECT EndDate From AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
											ORDER BY EndDate DESC)											
	DECLARE @month3APID uniqueidentifier = @accountingPeriodID
	
	IF (@month1APID = @month2APID)
	BEGIN
		SET @month1APID = null
	END
    		

	DECLARE @month1StartDate date = (SELECT StartDate From AccountingPeriod WHERE AccountID = @accountID AND AccountingPeriodID = @month1APID)    		
	DECLARE @month2StartDate date = (SELECT StartDate From AccountingPeriod WHERE AccountID = @accountID AND AccountingPeriodID = @month2APID)
	DECLARE @month3StartDate date = (SELECT StartDate From AccountingPeriod WHERE AccountID = @accountID AND AccountingPeriodID = @month3APID)
	
	IF ('55555555-5555-5555-5555-555555555555' IN (SELECT Value FROM @accountingBookIDs))
	BEGIN
		UPDATE #QuarterFinancialAccounts SET Month1Actual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														INNER JOIN #PropertiesQFR p ON p.PropertyID = t.PropertyID
													WHERE t.TransactionDate >= pap.StartDate --ap.StartDate
													  AND t.TransactionDate <= pap.EndDate --ap.EndDate
													  -- Don't include closing the year entries
													  AND t.Origin NOT IN ('Y', 'E')
													  AND je.GLAccountID = #QuarterFinancialAccounts.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  --AND ap.AccountingPeriodID = @month1APID	
													  AND pap.AccountingPeriodID = @month1APID	
													  AND je.AccountingBookID IS NULL										  
													  --AND ((@byProperty = 0) OR ((@byProperty = 1) AND (t.PropertyID = #QuarterFinancialAccounts.PropertyID)))
													  )
									  
	UPDATE #QuarterFinancialAccounts SET Month1Actual = ISNULL(Month1Actual, 0) + ISNULL((SELECT CASE
																				WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																				WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																				END
																		 FROM Budget b
																			INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1																								
																			--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
																			INNER JOIN #PropertiesQFR p ON p.PropertyID = pap.PropertyID
																		 WHERE
																		    b.GLAccountID = #QuarterFinancialAccounts.GLAccountID
																		   AND pap.AccountingPeriodID = @month1APID), 0)	
	END
	
	IF ((SELECT COUNT(*) FROM @accountingBookIDs WHERE Value <> '55555555-5555-5555-5555-555555555555') > 0)
	BEGIN
		-- Consider other Accounting Books
		UPDATE #QuarterFinancialAccounts SET Month1Actual = ISNULL(Month1Actual, 0) + 
												ISNULL((SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID
														--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														INNER JOIN #PropertiesQFR p ON p.PropertyID = t.PropertyID
														INNER JOIN #AccountingBookIDs #abIDs ON je.AccountingBookID = #abIDs.AccountingBookID
													WHERE t.TransactionDate >= pap.StartDate --ap.StartDate
														AND t.TransactionDate <= pap.EndDate --ap.EndDate
														-- Don't include closing the year entries
														AND t.Origin NOT IN ('Y', 'E')
														AND je.GLAccountID = #QuarterFinancialAccounts.GLAccountID
														AND je.AccountingBasis = @accountingBasis
														--AND ap.AccountingPeriodID = @month1APID	
														AND pap.AccountingPeriodID = @month1APID	
														--AND ((@byProperty = 0) OR ((@byProperty = 1) AND (t.PropertyID = #QuarterFinancialAccounts.PropertyID)))
														), 0)
	END
    	
	IF ('55555555-5555-5555-5555-555555555555' IN (SELECT Value FROM @accountingBookIDs))
	BEGIN		  
		UPDATE #QuarterFinancialAccounts SET Month2Actual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														INNER JOIN #PropertiesQFR p ON p.PropertyID = t.PropertyID
													WHERE t.TransactionDate >= pap.StartDate --ap.StartDate
													  AND t.TransactionDate <= pap.EndDate  --ap.EndDate
													  -- Don't include closing the year entries
													  AND t.Origin NOT IN ('Y', 'E')
													  AND je.GLAccountID = #QuarterFinancialAccounts.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  --AND ap.AccountingPeriodID = @month2APID		
													  AND pap.AccountingPeriodID = @month2APID																		  

													  AND je.AccountingBookID IS NULL
													  --AND ((@byProperty = 0) OR ((@byProperty = 1) AND (t.PropertyID = #QuarterFinancialAccounts.PropertyID)))
													  )
													
	UPDATE #QuarterFinancialAccounts SET Month2Actual = ISNULL(Month2Actual, 0) + ISNULL((SELECT CASE
																				WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																				WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																				END
																		 FROM Budget b
																			INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1																									
																			--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
																			INNER JOIN #PropertiesQFR p ON p.PropertyID = pap.PropertyID
																		 WHERE
																		   b.GLAccountID = #QuarterFinancialAccounts.GLAccountID
																		   AND pap.AccountingPeriodID = @month2APID), 0)
	END

	IF ((SELECT COUNT(*) FROM @accountingBookIDs WHERE Value <> '55555555-5555-5555-5555-555555555555') > 0)
	BEGIN
		-- Consider other Accounting Books
		UPDATE #QuarterFinancialAccounts SET Month2Actual = ISNULL(Month2Actual, 0) +
												 ISNULL((SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID
														--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														INNER JOIN #PropertiesQFR p ON p.PropertyID = t.PropertyID
														INNER JOIN #AccountingBookIDs #abIDs ON je.AccountingBookID = #abIDs.AccountingBookID
													WHERE t.TransactionDate >= pap.StartDate --ap.StartDate
														AND t.TransactionDate <= pap.EndDate  --ap.EndDate
														-- Don't include closing the year entries
														AND t.Origin NOT IN ('Y', 'E')
														AND je.GLAccountID = #QuarterFinancialAccounts.GLAccountID
														AND je.AccountingBasis = @accountingBasis
														--AND ap.AccountingPeriodID = @month2APID		
														AND pap.AccountingPeriodID = @month2APID																		  
														--AND ((@byProperty = 0) OR ((@byProperty = 1) AND (t.PropertyID = #QuarterFinancialAccounts.PropertyID)))
														), 0)																		   	
	END

	IF ('55555555-5555-5555-5555-555555555555' IN (SELECT Value FROM @accountingBookIDs))
	BEGIN
		UPDATE #QuarterFinancialAccounts SET Month3Actual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														INNER JOIN #PropertiesQFR p ON p.PropertyID = t.PropertyID
													WHERE t.TransactionDate >= pap.StartDate --ap.StartDate
													  AND t.TransactionDate <= pap.EndDate --ap.EndDate
													  -- Don't include closing the year entries
													  AND t.Origin NOT IN ('Y', 'E')
													  AND je.GLAccountID = #QuarterFinancialAccounts.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  --AND ap.AccountingPeriodID = @month3APID	
													  AND pap.AccountingPeriodID = @month3APID																			  

													  AND je.AccountingBookID IS NULL
													  --AND ((@byProperty = 0) OR ((@byProperty = 1) AND (t.PropertyID = #QuarterFinancialAccounts.PropertyID)))
													  )
												  
		UPDATE #QuarterFinancialAccounts SET Month3Actual = ISNULL(Month3Actual, 0) + ISNULL((SELECT CASE
																					WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																					WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																					END
																			 FROM Budget b
																				INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1																							
																				--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
																				INNER JOIN #PropertiesQFR p ON p.PropertyID = pap.PropertyID
																			 WHERE 
																			   b.GLAccountID = #QuarterFinancialAccounts.GLAccountID
																			   AND pap.AccountingPeriodID = @month3APID), 0)
	END
	
	IF ((SELECT COUNT(*) FROM @accountingBookIDs WHERE Value <> '55555555-5555-5555-5555-555555555555') > 0)
	BEGIN
		-- Consider other Accounting Books
		UPDATE #QuarterFinancialAccounts SET Month3Actual = ISNULL(Month3Actual, 0) +
												ISNULL((SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID
														--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														INNER JOIN #PropertiesQFR p ON p.PropertyID = t.PropertyID
														INNER JOIN #AccountingBookIDs #abIDs ON je.AccountingBookID = #abIDs.AccountingBookID
													WHERE t.TransactionDate >= pap.StartDate --ap.StartDate
														AND t.TransactionDate <= pap.EndDate --ap.EndDate
														-- Don't include closing the year entries
														AND t.Origin NOT IN ('Y', 'E')
														AND je.GLAccountID = #QuarterFinancialAccounts.GLAccountID
														AND je.AccountingBasis = @accountingBasis
														--AND ap.AccountingPeriodID = @month3APID	
														AND pap.AccountingPeriodID = @month3APID																			  
														--AND ((@byProperty = 0) OR ((@byProperty = 1) AND (t.PropertyID = #QuarterFinancialAccounts.PropertyID)))
														), 0)				
	END

	IF (0 = (SELECT COUNT(*) FROM #PropertiesAndAlternateBudgets WHERE CashAlternateBudgetID IS NOT NULL OR AccrualAlternateBudgetID IS NOT NULL))
	BEGIN
		UPDATE #QuarterFinancialAccounts SET Month1Budget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID 
												--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
												INNER JOIN #PropertiesQFR p ON p.PropertyID = pap.PropertyID
											 WHERE 
											   b.GLAccountID = #QuarterFinancialAccounts.GLAccountID
											   AND pap.AccountingPeriodID = @month1APID)

		UPDATE #QuarterFinancialAccounts SET Month2Budget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
												--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
												INNER JOIN #PropertiesQFR p ON p.PropertyID = pap.PropertyID
											 WHERE 
											   b.GLAccountID = #QuarterFinancialAccounts.GLAccountID
											   AND pap.AccountingPeriodID = @month2APID)		
										   
		UPDATE #QuarterFinancialAccounts SET Month3Budget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
													WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
													END
											 FROM Budget b
												INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
												--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
												INNER JOIN #PropertiesQFR p ON p.PropertyID = pap.PropertyID
											 WHERE 
											   b.GLAccountID = #QuarterFinancialAccounts.GLAccountID
											   AND pap.AccountingPeriodID = @month3APID)	
	END
	ELSE			-- Let's use Alternate Budgets here instead, just for the fun of it
	BEGIN
		UPDATE #QuarterFinancialAccounts SET Month1Budget = (SELECT SUM(ab.Amount)
																 FROM AlternateBudget ab
																	INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID 
																	INNER JOIN #PropertiesAndAlternateBudgets p ON p.PropertyID = pap.PropertyID
																					AND (p.AccrualAlternateBudgetID = ab.YearBudgetID OR p.CashAlternateBudgetID = ab.YearBudgetID)
																 WHERE ab.GLAccountID = #QuarterFinancialAccounts.GLAccountID
																   AND pap.AccountingPeriodID = @month1APID)

		UPDATE #QuarterFinancialAccounts SET Month2Budget = (SELECT SUM(ab.Amount)
																 FROM AlternateBudget ab
																	INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																	INNER JOIN #PropertiesAndAlternateBudgets p ON p.PropertyID = pap.PropertyID
																					AND (p.AccrualAlternateBudgetID = ab.YearBudgetID OR p.CashAlternateBudgetID = ab.YearBudgetID)
																 WHERE ab.GLAccountID = #QuarterFinancialAccounts.GLAccountID
																   AND pap.AccountingPeriodID = @month2APID)		
										   
		UPDATE #QuarterFinancialAccounts SET Month3Budget = (SELECT SUM(ab.Amount)
																 FROM AlternateBudget ab
																	INNER JOIN PropertyAccountingPeriod pap ON ab.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
																	INNER JOIN #PropertiesAndAlternateBudgets p ON p.PropertyID = pap.PropertyID
																					AND (p.AccrualAlternateBudgetID = ab.YearBudgetID OR p.CashAlternateBudgetID = ab.YearBudgetID)
																 WHERE ab.GLAccountID = #QuarterFinancialAccounts.GLAccountID
																   AND pap.AccountingPeriodID = @month3APID)	
	END
										   
	
	IF @reportName = 'Cash Flow Statement' 
	BEGIN
		-- Add net income amounts
		-- Temp table to store the income statement
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
			
		-- Variables to store current and year to date net income amounts
		DECLARE @emptyGuidCollection GuidCollection
		DECLARE @emptyStringCollection StringCollection
		--DECLARE @month1NetIncome money
		--DECLARE @month2NetIncome money
		--DECLARE @month3NetIncome money	
		
		CREATE TABLE #Incomes (
			PropertyID uniqueidentifier NULL,
			Month1NetIncome money NULL,
			Month2NetIncome money NULL,
			Month3NetIncome money NULL)	
					
		IF (@byProperty = 1) 
		BEGIN
			INSERT INTO #Incomes
				SELECT PropertyID, 0, 0, 0

				FROM #PropertiesQFR											
		END
		ELSE
		BEGIN
			INSERT INTO #Incomes
				SELECT null, 0, 0, 0					
		END								
					
		-- Get the net income for month 1
		INSERT INTO #NetIncomeAccounts EXEC [RPT_ACTG_GenerateKeyFinancialReports] @propertyIDs, 'Income Statement', @accountingBasis, @month1APID, 0, @emptyGuidCollection, 1, null, @byProperty, @emptyStringCollection, @accountingBookIDs
		--SELECT @month1NetIncome = ISNULL(SUM(CurrentAPAmount), 0) FROM #NetIncomeAccounts	
		UPDATE #Incomes SET Month1NetIncome = (SELECT ISNULL(SUM(CurrentAPAmount), 0)
												   FROM #NetIncomeAccounts
												   --WHERE @byProperty = 0 OR PropertyID = #Incomes.PropertyID
												   )
										
		TRUNCATE TABLE #NetIncomeAccounts
		
		-- Get the net income for month 2
		INSERT INTO #NetIncomeAccounts EXEC [RPT_ACTG_GenerateKeyFinancialReports] @propertyIDs, 'Income Statement', @accountingBasis, @month2APID, 0, @emptyGuidCollection, 1, null, @byProperty, @emptyStringCollection, @accountingBookIDs
		--SELECT @month2NetIncome = ISNULL(SUM(CurrentAPAmount), 0) FROM #NetIncomeAccounts		
		UPDATE #Incomes SET Month2NetIncome = (SELECT ISNULL(SUM(CurrentAPAmount), 0)
												   FROM #NetIncomeAccounts
												   --WHERE @byProperty = 0 OR PropertyID = #Incomes.PropertyID
												   )
		
		TRUNCATE TABLE #NetIncomeAccounts
		
		-- Get the net income for month 3
		INSERT INTO #NetIncomeAccounts EXEC [RPT_ACTG_GenerateKeyFinancialReports] @propertyIDs, 'Income Statement', @accountingBasis, @month3APID, 0, @emptyGuidCollection, 1, null, @byProperty, @emptyStringCollection, @accountingBookIDs		
		--SELECT @month3NetIncome = ISNULL(SUM(CurrentAPAmount), 0) FROM #NetIncomeAccounts	
		UPDATE #Incomes SET Month3NetIncome = (SELECT ISNULL(SUM(CurrentAPAmount), 0)
												   FROM #NetIncomeAccounts
												   --WHERE @byProperty = 0 OR PropertyID = #Incomes.PropertyID
												   )
		
		TRUNCATE TABLE #NetIncomeAccounts
		
		-- Add a row for the net income
		INSERT INTO #QuarterFinancialAccounts --VALUES (NEWID(), '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', 0, @month1NetIncome, 0, @month2NetIncome, 0, @month3NetIncome)
			SELECT PropertyID, '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', 0, Month1NetIncome, 0, Month2NetIncome, 0, Month3NetIncome
				FROM #Incomes
				
	-- Add a row for the net income
		INSERT INTO #AlternateQFAValues --VALUES (NEWID(), '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', 0, @month1NetIncome, 0, @month2NetIncome, 0, @month3NetIncome)
			SELECT PropertyID, '11111111-1111-1111-1111-111111111111', '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', 0, Month1NetIncome, 0, Month2NetIncome, 0, Month3NetIncome
				FROM #Incomes				
		
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
		DECLARE @balance2Date date
		DECLARE @balance3Date date	
		DECLARE @baGLAccountTypes StringCollection
		INSERT INTO @baGLAccountTypes VALUES ('Bank')			
		--DECLARE @month1BeginningCashBalance money = 0
		--DECLARE @month2BeginningCashBalance money = 0
		--DECLARE @month3BeginningCashBalance money = 0
		
		CREATE TABLE #CashBalances (
			PropertyID uniqueidentifier NULL,
			Month1CashBalance money NULL,
			Month2CashBalance money NULL,
			Month3CashBalance money NULL)		
			
		IF (@byProperty = 1) 
		BEGIN
			INSERT INTO #CashBalances
				SELECT PropertyID, 0, 0, 0

				FROM #PropertiesQFR											
		END
		ELSE
		BEGIN
			INSERT INTO #CashBalances
				SELECT null, 0, 0, 0					
		END								
								
		
		--SET @balanceDate = (SELECT DATEADD(DAY, -1, @month1StartDate))
		IF (@month0APID IS NOT NULL)
		BEGIN		
			INSERT INTO #BankAccounts EXEC [RPT_ACTG_BalanceSheet] @propertyIDs, '', @accountingBasis, null, @baGLAccountTypes, null, @byProperty, @month0APID, @accountingBookIDs							
			
			--SET @month1BeginningCashBalance = (SELECT SUM(Balance) FROM #BankAccounts)
			UPDATE #CashBalances SET Month1CashBalance = (SELECT ISNULL(SUM(Balance), 0)
																  FROM #BankAccounts
																  --WHERE @byProperty = 0 OR PropertyID = #CashBalances.PropertyID
																  )
			TRUNCATE TABLE #BankAccounts
		END
								
		--SET @balance2Date = (SELECT DATEADD(DAY, -1, @month2StartDate))		
		IF (@month1APID IS NOT NULL)
		BEGIN		
			INSERT INTO #BankAccounts EXEC [RPT_ACTG_BalanceSheet] @propertyIDs, '', @accountingBasis, null, @baGLAccountTypes, null, @byProperty, @month1APID, @accountingBookIDs												
			
			--SET @month2BeginningCashBalance = (SELECT SUM(Balance) FROM #BankAccounts)
			
			UPDATE #CashBalances SET Month2CashBalance = (SELECT ISNULL(SUM(Balance), 0)
															  FROM #BankAccounts
															  --WHERE @byProperty = 0 OR PropertyID = #CashBalances.PropertyID
															  )
			TRUNCATE TABLE #BankAccounts
		END
		
		--SET @balance3Date = (SELECT DATEADD(DAY, -1, @month3StartDate))		
		IF (@month2APID IS NOT NULL)
		BEGIN		
			INSERT INTO #BankAccounts EXEC [RPT_ACTG_BalanceSheet] @propertyIDs, '', @accountingBasis, null, @baGLAccountTypes, null, @byProperty, @month2APID, @accountingBookIDs							
			
			--SET @month3BeginningCashBalance = (SELECT SUM(Balance) FROM #BankAccounts)
			
			UPDATE #CashBalances SET Month3CashBalance = (SELECT ISNULL(SUM(Balance), 0)
															  FROM #BankAccounts
															  --WHERE @byProperty = 0 OR PropertyID = #CashBalances.PropertyID
															  )
			TRUNCATE TABLE #BankAccounts
		END
		
		INSERT INTO #QuarterFinancialAccounts -- VALUES (NEWID(), '', 'Beginning Cash Balance', '', 'Bank', null, 0, 1, 0 , '', '', '', 0, @month1BeginningCashBalance, 0, @month2BeginningCashBalance, 0, @month3BeginningCashBalance)		
			SELECT PropertyID, NEWID(), '', 'Beginning Cash Balance', '', 'Bank', null, 0, 1, 0, '', '', '', 0, Month1CashBalance, 0, Month2CashBalance, 0, Month3CashBalance
				FROM #CashBalances
				
		INSERT INTO #AlternateQFAValues -- VALUES (NEWID(), '', 'Beginning Cash Balance', '', 'Bank', null, 0, 1, 0 , '', '', '', 0, @month1BeginningCashBalance, 0, @month2BeginningCashBalance, 0, @month3BeginningCashBalance)		
			SELECT PropertyID, NEWID(), '', 'Beginning Cash Balance', '', 'Bank', null, 0, 1, 0, '', '', '', 0, Month1CashBalance, 0, Month2CashBalance, 0, Month3CashBalance
				FROM #CashBalances				
	END	
	
	IF (@alternateChartOfAccountsID IS NOT NULL)
	BEGIN
			INSERT #AlternateQFA 
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
						0,
						0,
						0,
						0,
						0,
						0
					 FROM GetAlternateChartOfAccounts(@accountID, @glAccountTypes, @alternateChartOfAccountsID)	
						LEFT JOIN #PropertiesQFR #p ON @byProperty = 1
							 	
		INSERT #AlternateQFAValues
				SELECT  #AQFA.PropertyID,
						#AQFA.GLAccountID, 
						#AQFA.Number AS 'GLAccountNumber',
						#AQFA.Name AS 'GLAccountName',
						#AQFA.[Description],
						LTRIM(#AQFA.GLAccountType) AS 'Type',
						#AQFA.ParentGLAccountID,
						#AQFA.Depth,
						#AQFA.IsLeaf,
						#AQFA.SummaryParent,
						#AQFA.OrderByPath,
						#AQFA.[Path],
						#AQFA.SummaryParentPath,
						ISNULL(SUM(ISNULL(#quartFA.Month1Budget, 0)), 0) AS 'Month1Budget',
						ISNULL(SUM(ISNULL(#quartFA.Month1Actual, 0)), 0) AS 'Month1Amount',
						ISNULL(SUM(ISNULL(#quartFA.Month2Budget, 0)), 0) AS 'Month2Budget',
						ISNULL(SUM(ISNULL(#quartFA.Month2Actual, 0)), 0) AS 'Month2Amount',
						ISNULL(SUM(ISNULL(#quartFA.Month3Budget, 0)), 0) AS 'Month3Budget',
						ISNULL(SUM(ISNULL(#quartFA.Month3Actual, 0)), 0) AS 'Month3Amount'
				FROM #AlternateQFA #AQFA
					INNER JOIN GLAccountAlternateGLAccount altGL ON #AQFA.GLAccountID = altGL.AlternateGLAccountID
					INNER JOIN #QuarterFinancialAccounts #quartFA ON altGL.GLAccountID = #quartFA.GLAccountID AND (@byProperty = 0 OR #AQFA.PropertyID = #quartFA.PropertyID)
				--WHERE #AQFA.IsLeaf = 1 AND #quartFA.IsLeaf = 1
				GROUP BY #AQFA.GLAccountID, #AQFA.Number, #AQFA.Name, #AQFA.[Description], #AQFA.GLAccountType, #AQFA.ParentGLAccountID, #AQFA.Depth,
						#AQFA.IsLeaf, #AQFA.SummaryParent, #AQFA.OrderByPath, #AQFA.[Path],	#AQFA.SummaryParentPath, #AQFA.PropertyID

			INSERT #AlternateQFAValues
				SELECT	PropertyID, GLAccountID, Number, Name + ' - Other', [Description], GLAccountType, ParentGLAccountID, Depth+1, 1, SummaryParent,
						OrderByPath + '!#' + RIGHT('0000000000' + Number, 10), 
						[Path] + '!#' + Number + ' ' + Name + ' - Other', 
						[SummaryParentPath] + '!#' + CAST(SummaryParent AS nvarchar(10)),
						Month1Budget, Month1Actual, Month2Budget, Month2Actual, Month3Budget, Month3Actual
				FROM #AlternateQFAValues
				WHERE IsLeaf = 0
				  AND ((Month1Actual <> 0) OR (Month2Actual <> 0) OR (Month3Actual <> 0) OR (Month1Budget <> 0) OR (Month2Budget <> 0) OR (Month3Budget <> 0))
										   				
				--UNION
				----SELECT NEWID(), '', 'Net Income', '', 'Income', null, 0, 1, 0, '', '', '', 0, @month1NetIncome, 0, @month2NetIncome, 0, @month3NetIncome
				----	WHERE @reportName = 'Cash Flow Statement'
				--SELECT *
				--	FROM #QuarterFinancialAccounts
				--	WHERE @reportName = 'Cash Flow Statement'
				--	  AND GLAccountID IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222')
	
				----UNION
				----SELECT NEWID(), '', 'Beginning Cash Balance', '', 'Bank', null, 0, 1, 0 , '', '', '', 0, @month1BeginningCashBalance, 0, @month2BeginningCashBalance, 0, @month3BeginningCashBalance
				----	WHERE @reportName = 'Cash Flow Statement'
					
				--UNION
				--SELECT  #AQFA.PropertyID,
				--		#AQFA.GLAccountID, 
				--		#AQFA.Number AS 'GLAccountNumber',
				--		#AQFA.Name + ' - Other' AS 'GLAccountName',
				--		#AQFA.[Description],
				--		LTRIM(#AQFA.GLAccountType) AS 'Type',
				--		#AQFA.ParentGLAccountID,
				--		#AQFA.Depth+1,
				--		1,
				--		#AQFA.SummaryParent,
				--		#AQFA.OrderByPath + '!#' + RIGHT('0000000000' + #AQFA.Number, 10),
				--		#AQFA.[Path] + '!#' + #AQFA.Number + ' ' + #AQFA.Name + ' - Other',
				--		#AQFA.SummaryParentPath + '!#' + CAST(#AQFA.SummaryParent AS nvarchar(10)),
				--		#quartFA.Month1Budget,
				--		#quartFA.Month1Actual,
				--		#quartFA.Month2Budget,
				--		#quartFA.Month2Actual,
				--		#quartFA.Month3Budget,
				--		#quartFA.Month3Actual
				--FROM #AlternateQFA #AQFA
				--	INNER JOIN GLAccountAlternateGLAccount altGL ON #AQFA.GLAccountID = altGL.AlternateGLAccountID
				--	INNER JOIN #QuarterFinancialAccounts #quartFA ON altGL.GLAccountID = #quartFA.GLAccountID AND #AQFA.PropertyID = #quartFA.PropertyID 
				--WHERE ((#AQFA.IsLeaf = 1 AND #quartFA.IsLeaf = 0)
				--   OR  (#AQFA.IsLeaf = 0 AND #quartFA.IsLeaf = 1))
				--GROUP BY #AQFA.GLAccountID, #AQFA.Number, #AQFA.Name, #AQFA.[Description], #AQFA.GLAccountType, #AQFA.ParentGLAccountID, #AQFA.Depth,
				--		#AQFA.IsLeaf, #AQFA.SummaryParent, #AQFA.OrderByPath, #AQFA.[Path],	#AQFA.SummaryParentPath, #AQFA.PropertyID,
				--		#quartFA.Month1Budget, #quartFA.Month1Actual, #quartFA.Month2Budget, #quartFA.Month2Actual, #quartFA.Month3Budget, #quartFA.Month3Actual 				
			
	
	END			
	ELSE
	BEGIN
		INSERT #QuarterFinancialAccounts 
			SELECT	PropertyID, GLAccountID, Number, Name + ' - Other', [Description], GLAccountType, ParentGLAccountID, Depth+1, 1, SummaryParent,
					OrderByPath + '!#' + RIGHT('0000000000' + Number, 10), 
					[Path] + '!#' + Number + ' ' + Name + ' - Other', 
					[SummaryParentPath] + '!#' + CAST(SummaryParent AS nvarchar(10)),
					Month1Budget, Month1Actual, Month2Budget, Month2Actual, Month3Budget, Month3Actual
			FROM #QuarterFinancialAccounts
			WHERE IsLeaf = 0
			  AND ((Month1Actual <> 0) OR (Month2Actual <> 0) OR (Month3Actual <> 0) OR (Month1Budget <> 0) OR (Month2Budget <> 0) OR (Month3Budget <> 0))
										   
	END										   									   
																			
	IF (1 =	(SELECT HideZeroValuesInFinancialReports 
				FROM Settings s
					INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID AND s.AccountID = ap.AccountID))
	BEGIN
		IF (@alternateChartOfAccountsID IS NOT NULL)
		BEGIN
			SELECT PropertyID,
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
					ISNULL(Month1Budget, 0) AS 'Month1Budget', ISNULL(Month1Actual, 0) AS 'Month1Amount',
					ISNULL(Month2Budget, 0) AS 'Month2Budget', ISNULL(Month2Actual, 0) AS 'Month2Amount',
					ISNULL(Month3Budget, 0) AS 'Month3Budget', ISNULL(Month3Actual, 0) AS 'Month3Amount' 
				FROM #AlternateQFAValues #AQFAV
				WHERE 
					IsLeaf = 1 
					AND (#AQFAV.Month1Budget <> 0
				   OR #AQFAV.Month1Actual <> 0
				   OR #AQFAV.Month2Budget <> 0
				   OR #AQFAV.Month2Actual <> 0
				   OR #AQFAV.Month3Budget <> 0
				   OR #AQFAV.Month3Actual <> 0)
				ORDER BY OrderByPath
		END	
		ELSE
		BEGIN
			SELECT  PropertyID,
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
					ISNULL(Month1Budget, 0) AS 'Month1Budget', ISNULL(Month1Actual, 0) AS 'Month1Amount',
					ISNULL(Month2Budget, 0) AS 'Month2Budget', ISNULL(Month2Actual, 0) AS 'Month2Amount',
					ISNULL(Month3Budget, 0) AS 'Month3Budget', ISNULL(Month3Actual, 0) AS 'Month3Amount'
			 FROM #QuarterFinancialAccounts			 
			 WHERE (Month1Actual <> 0 OR Month1Budget <> 0
				OR Month2Actual <> 0 OR Month2Budget <> 0
				OR Month3Actual <> 0 OR Month3Budget <> 0)
				AND IsLeaf = 1		 
			ORDER BY OrderByPath
		END
	END
	ELSE	-- Show 0s in Financials
	BEGIN
		IF (@alternateChartOfAccountsID IS NOT NULL)
		BEGIN
			SELECT PropertyID,
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
					ISNULL(Month1Budget, 0) AS 'Month1Budget', ISNULL(Month1Actual, 0) AS 'Month1Amount',
					ISNULL(Month2Budget, 0) AS 'Month2Budget', ISNULL(Month2Actual, 0) AS 'Month2Amount',
					ISNULL(Month3Budget, 0) AS 'Month3Budget', ISNULL(Month3Actual, 0) AS 'Month3Amount'
				FROM #AlternateQFAValues
				WHERE IsLeaf = 1
				ORDER BY OrderByPath
		END
		ELSE
		BEGIN
			SELECT  PropertyID,
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
					ISNULL(Month1Budget, 0) AS 'Month1Budget', ISNULL(Month1Actual, 0) AS 'Month1Amount',
					ISNULL(Month2Budget, 0) AS 'Month2Budget', ISNULL(Month2Actual, 0) AS 'Month2Amount',
					ISNULL(Month3Budget, 0) AS 'Month3Budget', ISNULL(Month3Actual, 0) AS 'Month3Amount'
			 FROM #QuarterFinancialAccounts	
			 WHERE IsLeaf = 1
			 ORDER BY OrderByPath
		 END
	 END
END
GO
