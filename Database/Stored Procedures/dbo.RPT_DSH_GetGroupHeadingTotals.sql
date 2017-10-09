SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 8, 2012
-- Description:	Gets Accounting Group Totals for the Dashboard
-- =============================================
CREATE PROCEDURE [dbo].[RPT_DSH_GetGroupHeadingTotals] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null,
	@reportName nvarchar(50) = null,
	@accountingBasis nvarchar(10) = null
AS

DECLARE @fiscalYearStartDate datetime
DECLARE @lastFiscalYearStartDate datetime
DECLARE @lastFiscalYearEndDate datetime
DECLARE @accountID bigint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	CREATE TABLE #AllInfo (
		PropertyID uniqueidentifier not null,
		Parent1 nvarchar(50) not null,
		Parent2 nvarchar(50) null,
		Parent3 nvarchar(50) null,
		OrderBy1 smallint  null,
		OrderBy2 smallint null,
		OrderBy3 smallint  null,
		GLAccountNumber nvarchar(50)  null,
		GLAccountName nvarchar(50)  null,
		GLAccountID uniqueidentifier  null,
		GLAccountType nvarchar(10) not null,
		CurrentAPAmount money null,
		YTDAmount money null,
		LastYearAmount money null,
		CurrentAPBudget money null,
		YTDBudget money null)
		
	INSERT INTO #AllInfo
		SELECT DISTINCT 
				Properties.Value AS 'PropertyID',
				glac1.ReportLabel AS 'Parent1',
				glac2.ReportLabel AS 'Parent2',
				glac3n.ReportLabel AS 'Parent3',
				rg.OrderBy AS 'OrderBy1',
				rg1.OrderBy AS 'OrderBy2',
				rg2.OrderBy AS 'OrderBy3',
				gla1.Number AS 'GLAccountNumber',
				gla1.Name AS 'GLAccountName',
				gla1.GLAccountID AS 'GLAccountID',
				gla1.GLAccountType AS 'GLAccountType',
				null AS 'CurrentAPAmount',
				null AS 'YTDAmount',
				null AS 'LastYearAmount',
				null AS 'CurrentAPBudget',
				null AS 'YTDBudget'
		FROM ReportGroup rg
			INNER JOIN GLAccountGroup glac1 on rg.ChildGLAccountGroupID = glac1.GLAccountGroupID AND rg.ParentGLAccountGroupID IS NULL
			INNER JOIN ReportGroup rg1 on glac1.GLAccountGroupID = rg1.ParentGLAccountGroupID
			INNER JOIN GLAccountGroup glac2 on rg1.ChildGLAccountGroupID = glac2.GLAccountGroupID AND rg1.ChildGLAccountGroupID IS NOT NULL
			INNER JOIN ReportGroup rg2 on glac2.GLAccountGroupID = rg2.ParentGLAccountGroupID
			INNER JOIN GLAccountGroup glac3n on rg2.ChildGLAccountGroupID = glac3n.GLAccountGroupID 
			INNER JOIN GLAccountGLAccountGroup glgroup1 on glac3n.GLAccountGroupID = glgroup1.GLAccountGroupID
			INNER JOIN GLAccount gla1 on glgroup1.GLAccountID = gla1.GLAccountID
			INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
			CROSS APPLY (SELECT Value FROM @propertyIDs) AS Properties
		WHERE rg.ReportName = @reportName
		  AND rg.AccountID = ap.AccountID
		  
	UPDATE #AllInfo SET CurrentAPAmount = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
												WHERE t.TransactionDate >= ap.StartDate
												  AND t.TransactionDate <= ap.EndDate
												  AND je.GLAccountID = #AllInfo.GLAccountID
												  AND t.PropertyID = #AllInfo.PropertyID
												  AND je.AccountingBasis = @accountingBasis
												  AND je.AccountingBookID IS NULL
												  AND t.PropertyID IN (SELECT Value FROM @propertyIDs)
												GROUP BY t.PropertyID)
												  
	UPDATE #AllInfo SET CurrentAPBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN SUM(CASE WHEN g.GLAccountType IN ('Expense', 'Asset') THEN -b.AccrualBudget ELSE b.AccrualBudget END)
													WHEN (@accountingBasis = 'Cash') THEN SUM(CASE WHEN g.GLAccountType IN ('Expense', 'Asset') THEN -b.CashBudget ELSE b.CashBudget END)
													END 
												FROM Budget b
												INNER JOIN GLAccount g on g.GLAccountID = b.GLAccountID
												WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																							FROM PropertyAccountingPeriod
																							WHERE PropertyID IN (SELECT Value FROM @propertyIDs)
																							  AND PropertyID = #AllInfo.PropertyID
																							  AND AccountingPeriodID = @accountingPeriodID)
												  AND b.GLAccountID = #AllInfo.GLAccountID)
												  
	SET @fiscalYearStartDate = (SELECT dbo.GetFiscalYearStartDate(@accountID, @accountingPeriodID, (SELECT TOP 1 Value FROM @propertyIDs)))
		
	--SET @lastFiscalYearEndDate = DATEADD(day, -1, @fiscalYearStartDate)
	--SET @lastFiscalYearStartDate = DATEADD(YEAR, -1, @fiscalYearStartDate)
	
	UPDATE #AllInfo SET YTDBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN SUM(CASE WHEN g.GLAccountType IN ('Expense', 'Asset') THEN -b.AccrualBudget ELSE b.AccrualBudget END)
												WHEN (@accountingBasis = 'Cash') THEN SUM(CASE WHEN g.GLAccountType IN ('Expense', 'Asset') THEN -b.CashBudget ELSE b.CashBudget END)
												END
										FROM Budget b
										INNER JOIN GLAccount g on g.GLAccountID = b.GLAccountID
										WHERE b.GLAccountID = #AllInfo.GLAccountID
										  AND b.PropertyAccountingPeriodID IN (SELECT DISTINCT pap.PropertyAccountingPeriodID
																					FROM PropertyAccountingPeriod pap
																					WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
																					  AND pap.PropertyID = #AllInfo.PropertyID
																					  AND pap.AccountingPeriodID IN (SELECT AccountingPeriodID 
																														FROM AccountingPeriod
																														WHERE AccountID = @accountID
																														  AND StartDate >= @fiscalYearStartDate
																														  AND EndDate <= (SELECT EndDate 
																																				FROM AccountingPeriod 
																																				WHERE AccountingPeriodID = @accountingPeriodID))))
										
	UPDATE  #AllInfo SET YTDAmount = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.NetMonthlyTotalAccrual), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.NetMonthlyTotalCash), 0)
												END
										 FROM Budget b
										 WHERE b.GLAccountID = #AllInfo.GLAccountID
										   AND b.PropertyAccountingPeriodID IN (SELECT DISTINCT pap.PropertyAccountingPeriodID
																					FROM PropertyAccountingPeriod pap
																						INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID AND pap.Closed = 1
																					WHERE pap.PropertyID IN (SELECT Value FROM @PropertyIDs)
																					  AND ap.StartDate >= @fiscalYearStartDate
																					  AND pap.PropertyID = #AllInfo.PropertyID))
																					  
	UPDATE #AllInfo SET YTDAmount = YTDAmount + (SELECT ISNULL(SUM(je.Amount), 0)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													WHERE t.PropertyID in (SELECT Value FROM @propertyIDs)
													  AND t.TransactionDate >= ap.StartDate
													  AND t.TransactionDate >= @fiscalYearStartDate
													  AND t.TransactionDate <= ap.EndDate
													  AND t.TransactionDate <= (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
													  AND je.AccountingBasis = @accountingBasis
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND t.PropertyID = #AllInfo.PropertyID
													  AND je.AccountingBookID IS NULL
													  AND pap.PropertyID = #AllInfo.PropertyID)
													  
	
	SELECT 
			(SELECT Name FROM Property WHERE PropertyID = #AllInfo.PropertyID) AS 'PropertyName',
			Parent1 AS 'GroupName',
			SUM(ISNULL(-CurrentAPAmount, 0)) AS 'MonthActual',
			SUM(ISNULL(CurrentAPBudget, 0)) AS 'MonthBudget',
			SUM(ISNULL(-YTDAmount, 0)) AS 'YTDActual',
			SUM(ISNULL(YTDBudget, 0)) AS 'YTDBudget',
			OrderBy1 AS 'OrderBy'										
		FROM #AllInfo
		GROUP BY #AllInfo.PropertyID, Parent1, OrderBy1
		ORDER BY 'PropertyName', 'OrderBy'
			


END




GO
