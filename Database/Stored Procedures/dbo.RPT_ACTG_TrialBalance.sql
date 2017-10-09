SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 16, 2012
-- Description:	Gets the basic information for a variety of Financial Reports
-- =============================================
CREATE PROCEDURE [dbo].[RPT_ACTG_TrialBalance] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@accountingBasis nvarchar(10) = null,
	@startDate datetime = null,
	@endDate datetime = null,
	@alternateChartOfAccounts uniqueidentifier = null,
	@byPropertyID bit = 0,
	@accountingPeriodID uniqueidentifier = null,
	@glAccountIDs GuidCollection READONLY,
	@accountingBookIDs GuidCollection READONLY
AS

DECLARE @fiscalYearBegin tinyint
DECLARE @fiscalYearStartDate datetime
DECLARE @accountID bigint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))

	CREATE TABLE #AllInfo (
		PropertyID uniqueidentifier null,
		Number nvarchar(50)  null,
		Name nvarchar(50)  null,
		GLAccountID uniqueidentifier  null,
		GLAccountType nvarchar(50) null,
		BeginningBalance money null,
		Amount money null)
		
	CREATE TABLE #AlternateInfo (
		PropertyID uniqueidentifier null,
		Number nvarchar(50)  null,
		Name nvarchar(50)  null,
		GLAccountID uniqueidentifier  null,
		GLAccountType nvarchar(50) null,
		BeginningBalance money null,
		Amount money null)

	CREATE TABLE #PropertiesAndDates (
		Sequence int identity,
		PropertyID uniqueidentifier null,
		StartDate [Date] NULL,
		EndDate [Date] NULL,
		StartDateAccountingPeriodID uniqueidentifier NULL,
		FiscalYearStartDate [Date] null)
	

	CREATE TABLE #AccountingBookIDs (
		AccountingBookID uniqueidentifier NOT NULL)
		
	INSERT #PropertiesAndDates 
		SELECT pids.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate), pap.AccountingPeriodID, null
			FROM @propertyIDs pids 
				LEFT JOIN PropertyAccountingPeriod pap ON pids.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	INSERT #AccountingBookIDs
			SELECT Value
				FROM @accountingBookIDs

	-- If we don't have an AccountingPeriodID passed in then get the "starting" accounting period from the
	-- period containing the start date of the report
	IF (@accountingPeriodID IS NULL)
	BEGIN
		UPDATE #PropertiesAndDates SET StartDateAccountingPeriodID = (SELECT TOP 1 pap.AccountingPeriodID
																	  FROM PropertyAccountingPeriod pap
																	  WHERE pap.PropertyID = #PropertiesAndDates.PropertyID
																		AND pap.StartDate <= #PropertiesAndDates.StartDate
																		AND pap.EndDate >= #PropertiesAndDates.StartDate
																	  ORDER BY pap.EndDate DESC)
	END
						
	DECLARE @emptyStringCollection StringCollection
		
	IF ((SELECT COUNT(*) FROM @glAccountIDs) = 0)
	BEGIN
		INSERT INTO #AllInfo
			SELECT	#p.PropertyID,
					Number AS 'Number',
					Name AS 'Name',
					GLAccountID AS 'GLAccountID',
					GLAccountType AS 'Type',
					null AS 'BeginningBalance',
					null AS 'Amount'
			FROM GetChartOfAccounts(@accountID, @emptyStringCollection)
				LEFT JOIN #PropertiesAndDates #p ON @byPropertyID = 1
	END
	ELSE
	BEGIN
		INSERT INTO #AllInfo
				SELECT	#p.PropertyID,
						Number AS 'Number',
						Name AS 'Name',
						GLAccountID AS 'GLAccountID',
						GLAccountType AS 'Type',
						null AS 'BeginningBalance',
						null AS 'Amount'
				FROM GLAccount gl
					LEFT JOIN #PropertiesAndDates #p ON @byPropertyID = 1
				WHERE gl.GLAccountID IN (SELECT Value FROM @glAccountIDs)
	END
			


	UPDATE #AllInfo SET BeginningBalance = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													--INNER JOIN #Properties p ON p.PropertyID = t.PropertyID
													--INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
													--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
													INNER JOIN #AccountingBookIDs #abIDs ON ISNULL(je.AccountingBookID, '55555555-5555-5555-5555-555555555555') = #abIDs.AccountingBookID
												WHERE --t.TransactionDate >= ap.StartDate
												  --AND t.TransactionDate <= ap.EndDate
												  ((t.TransactionDate < #pad.StartDate)
											       --  If we have a retained earnings entry in the date range
											       -- include that in the beginning balance as it really didn't
											       -- "happen" durring the date range, it just had to be
											       -- put somewhere so we put it there
												   OR (t.Origin IN ('E') 
														AND t.TransactionDate >= #pad.StartDate
														AND t.TransactionDate <= #pad.EndDate))
												  --AND t.TransactionDate >= #pad.StartDate
												  AND je.GLAccountID = #AllInfo.GLAccountID
												  AND je.AccountingBasis = @accountingBasis
												  AND #AllInfo.GLAccountType IN ('Bank', 'Accounts Receivable', 'Other Current Asset', 'Fixed Asset', 'Other Asset', 'Accounts Payable', 'Other Current Liability', 'Long Term Liability', 'Equity')												  

												  AND ((@byPropertyID = 0) OR ((@byPropertyID = 1) AND (t.PropertyID = #AllInfo.PropertyID)))
												  )	
	OPTION (RECOMPILE)
			
	--UPDATE #AllInfo SET BeginningBalance = BeginningBalance + (SELECT CASE
	--														WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.NetMonthlyTotalAccrual), 0)
	--														WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.NetMonthlyTotalCash), 0)
	--														END
	--												 FROM Budget b
	--													INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
	--													INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--												 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--												   AND ap.EndDate <= @startDate
	--												   --AND ap.StartDate >= @startDate
	--												   AND #AllInfo.GLAccountType IN ('Asset', 'Liability', 'Equity')
	--												   AND b.GLAccountID = #AllInfo.GLAccountID)													 

	UPDATE #PropertiesAndDates SET FiscalYearStartDate = dbo.GetFiscalYearStartDate(@accountID, #PropertiesAndDates.StartDateAccountingPeriodID, #PropertiesAndDates.PropertyID)




	UPDATE #AllInfo SET BeginningBalance = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													--INNER JOIN #Properties p ON p.PropertyID = t.PropertyID
													--INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
													--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
													INNER JOIN #AccountingBookIDs #abIDs ON ISNULL(je.AccountingBookID, '55555555-5555-5555-5555-555555555555') = #abIDs.AccountingBookID
												WHERE --t.TransactionDate >= ap.StartDate
												  --AND t.TransactionDate <= ap.EndDate
												   t.TransactionDate < #pad.StartDate
												  AND t.TransactionDate >= #pad.FiscalYearStartDate
												  AND je.GLAccountID = #AllInfo.GLAccountID
												  AND je.AccountingBasis = @accountingBasis
												  AND #AllInfo.GLAccountType IN ('Income', 'Expense', 'Other Income', 'Other Expense', 'Non-Operating Expense')												  
												  -- Don't include closing the year entries
												  AND t.Origin NOT IN ('Y')
												  AND ((@byPropertyID = 0) OR ((@byPropertyID = 1) AND (t.PropertyID = #AllInfo.PropertyID)))
												  )
	WHERE #AllInfo.GLAccountType IN ('Income', 'Expense', 'Other Income', 'Other Expense', 'Non-Operating Expense')
	OPTION (RECOMPILE)
												  
	--UPDATE #AllInfo SET BeginningBalance = BeginningBalance + (SELECT CASE
	--														WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.NetMonthlyTotalAccrual), 0)
	--														WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.NetMonthlyTotalCash), 0)
	--														END
	--												 FROM Budget b
	--													INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
	--													INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
	--												 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
	--												   AND ap.EndDate <= @startDate
	--												   AND ap.StartDate >= @fiscalYearStartDate
	--												   AND #AllInfo.GLAccountType IN ('Income', 'Expense')
	--												   AND b.GLAccountID = #AllInfo.GLAccountID)														   
													   


	UPDATE #AllInfo SET Amount = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													--INNER JOIN #Properties p ON p.PropertyID = t.PropertyID
													INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
													INNER JOIN #AccountingBookIDs #abIDs ON ISNULL(je.AccountingBookID, '55555555-5555-5555-5555-555555555555') = #abIDs.AccountingBookID
												WHERE t.TransactionDate <= #pad.EndDate
												  AND t.TransactionDate >= #pad.StartDate
												    -- Don't include closing the year entries
												  AND t.Origin NOT IN ('Y', 'E')
												  AND je.GLAccountID = #AllInfo.GLAccountID
												  AND je.AccountingBasis = @accountingBasis

												  AND ((@byPropertyID = 0) OR ((@byPropertyID = 1) AND (t.PropertyID = #AllInfo.PropertyID)))
												  )
	OPTION (RECOMPILE)
												  													   
	IF (1 =	(SELECT HideZeroValuesInFinancialReports 
				FROM Settings s
				WHERE s.AccountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))))
	BEGIN
		IF (@alternateChartOfAccounts IS NOT NULL)
		BEGIN
			INSERT INTO #AlternateInfo
				SELECT	#p.PropertyID,
						Number AS 'Number',
						Name AS 'Name',
						GLAccountID AS 'GLAccountID',
						GLAccountType AS 'Type',
						null AS 'BeginningBalance',
						null AS 'Amount'
					FROM GetAlternateChartOfAccounts(@accountID, @emptyStringCollection, @alternateChartOfAccounts)
						LEFT JOIN #PropertiesAndDates #p ON @byPropertyID = 1
					
			SELECT	#altInfo.PropertyID, #altInfo.GLAccountID, #altInfo.Number, #altInfo.Name, #altInfo.GLAccountType,
					ISNULL(SUM(ISNULL(#AI.BeginningBalance, 0)), 0) AS 'BeginningBalance', 
					ISNULL(SUM(ISNULL(#AI.Amount, 0)), 0) AS 'Amount'
				FROM #AlternateInfo #altInfo
					INNER JOIN GLAccountAlternateGLAccount altGL ON #altInfo.GLAccountID = altGL.AlternateGLAccountID
					INNER JOIN #AllInfo #AI ON altGL.GLAccountID = #AI.GLAccountID AND (@byPropertyID = 0 OR #AI.PropertyID = #altInfo.PropertyID)
				GROUP BY #altInfo.GLAccountID, #altInfo.Number, #altInfo.Name, #altInfo.PropertyID, #altInfo.GLAccountType
				HAVING	ISNULL(SUM(ISNULL(#AI.BeginningBalance, 0)), 0) <> 0
				  OR	ISNULL(SUM(ISNULL(#AI.Amount, 0)), 0) <> 0
				ORDER BY Number		
		END
		ELSE
		BEGIN
			SELECT	PropertyID, GLAccountID, Number, Name, GLAccountType,
					ISNULL(BeginningBalance, 0) AS 'BeginningBalance', ISNULL(Amount, 0) AS 'Amount'
				FROM #AllInfo
				WHERE BeginningBalance <> 0
				   OR Amount <> 0
				ORDER BY Number	
		END
	END
	ELSE
	BEGIN	
		IF (@alternateChartOfAccounts IS NOT NULL)
		BEGIN
			INSERT INTO #AlternateInfo
				SELECT	#p.PropertyID,
						Number AS 'Number',
						Name AS 'Name',
						GLAccountID AS 'GLAccountID',
						GLAccountType AS 'Type',
						null AS 'BeginningBalance',
						null AS 'Amount'
					FROM GetAlternateChartOfAccounts(@accountID, @emptyStringCollection, @alternateChartOfAccounts)
						LEFT JOIN #PropertiesAndDates #p ON @byPropertyID = 1
					
			SELECT	#altInfo.PropertyID, #altInfo.GLAccountID, #altInfo.Number, #altInfo.Name, #altInfo.GLAccountType,
					ISNULL(SUM(ISNULL(#AI.BeginningBalance, 0)), 0) AS 'BeginningBalance', 
					ISNULL(SUM(ISNULL(#AI.Amount, 0)), 0) AS 'Amount'
				FROM #AlternateInfo #altInfo
					INNER JOIN GLAccountAlternateGLAccount altGL ON #altInfo.GLAccountID = altGL.AlternateGLAccountID
					INNER JOIN #AllInfo #AI ON altGL.GLAccountID = #AI.GLAccountID AND #altInfo.PropertyID = #AI.PropertyID
				GROUP BY #altInfo.GLAccountID, #altInfo.Number, #altInfo.Name, #altInfo.PropertyID, #altInfo.GLAccountType
				ORDER BY Number		
		END
		ELSE
		BEGIN													  
			SELECT	PropertyID, GLAccountID, Number, Name, GLAccountType,
					ISNULL(BeginningBalance, 0) AS 'BeginningBalance', ISNULL(Amount, 0) AS 'Amount'
				FROM #AllInfo
				ORDER BY Number
		END
	END		
END









GO
