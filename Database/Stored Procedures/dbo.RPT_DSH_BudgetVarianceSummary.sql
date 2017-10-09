SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



--=============================================
 --Author:		Rick Bertelsen
 --Create date: Feb. 16, 2012
 --Description:	Gets the basic information for a variety of Financial Reports
 --=============================================
CREATE PROCEDURE [dbo].[RPT_DSH_BudgetVarianceSummary] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 	
	@accountingBasis nvarchar(10) = null,
	@accountingPeriodID uniqueidentifier = null,
	@includePOs bit = 0	
AS


DECLARE @fiscalYearStartDate datetime
DECLARE @reportEndDate datetime
DECLARE @reportStartDate datetime
DECLARE @accountID bigint
DECLARE @overrideHide bit = 0
DECLARE @glAccountTypes StringCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #AllInfo (	
		PropertyID uniqueidentifier NOT NULL,	
		GLAccountID uniqueidentifier NOT NULL,
		Number nvarchar(15) NOT NULL,
		Name nvarchar(200) NOT NULL, 		
		GLAccountType nvarchar(50) NOT NULL,		
		[OrderByPath] nvarchar(max) NOT NULL,
		[Path]  nvarchar(max) NOT NULL,		
		GLParent1 nvarchar(max),		
		GLParent1OrderBy nvarchar(max),
		CurrentAPAmount money null,
		YTDAmount money null,
		CurrentAPBudget money null,
		YTDBudget money null		
		)			
	
		
	CREATE TABLE #PropertiesAndDates (
		Sequence int identity,
		PropertyID uniqueidentifier NOT NULL,
		FiscalYearStartDate date null)
		
	INSERT #PropertiesAndDates 
		SELECT Value, null FROM @propertyIDs
		
	-- Get period start and end dates
	SELECT @accountID = AccountID		   
	FROM AccountingPeriod 
	WHERE AccountingPeriodID = @accountingPeriodID				
	
	
	INSERT @glAccountTypes VALUES ('Income')
	INSERT @glAccountTypes VALUES ('Expense')
	INSERT @glAccountTypes VALUES ('Other Income')				
	INSERT @glAccountTypes VALUES ('Other Expense')
	INSERT @glAccountTypes VALUES ('Non-Operating Expense')				
						
	INSERT #AllInfo SELECT 
						Properties.Value,
						GLAccountID,
						Number,
						Name,						
						GLAccountType,														
						OrderByPath,
						[Path],														
						[Path],
						[OrderByPath],
						0,
						0,
						0,
						0													
					FROM GetChartOfAccounts(@accountID, @glAccountTypes)		
					CROSS APPLY (SELECT Value FROM @propertyIDs) AS Properties

		UPDATE #AllInfo SET GLParent1 = SUBSTRING(GLParent1, 3, LEN(GLParent1) - 2)
		UPDATE #AllInfo SET GLParent1OrderBy = SUBSTRING(GLParent1OrderBy, 3, LEN(GLParent1OrderBy) - 2)
		
		UPDATE #AllInfo SET GLParent1 = SUBSTRING(GLParent1, 0, CHARINDEX('!#', GLParent1, 1)) WHERE CHARINDEX('!#', GLParent1, 1) > 0
		UPDATE #AllInfo SET GLParent1OrderBy = SUBSTRING(GLParent1OrderBy, 0, CHARINDEX('!#', GLParent1OrderBy, 1)) WHERE CHARINDEX('!#', GLParent1OrderBy, 1) > 0

		UPDATE #AllInfo SET CurrentAPAmount = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
													INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
												WHERE t.TransactionDate >= pap.StartDate
												  AND t.TransactionDate <= pap.EndDate
												  AND je.GLAccountID = #AllInfo.GLAccountID
												  AND t.PropertyID = #AllInfo.PropertyID
												  AND je.AccountingBasis = @accountingBasis
												  AND t.Origin NOT IN ('Y', 'E')
												  AND t.PropertyID IN (SELECT Value FROM @propertyIDs)
												  AND je.AccountingBookID IS NULL
												GROUP BY t.PropertyID)
												  
	UPDATE #AllInfo SET CurrentAPBudget = (SELECT CASE
													WHEN (@accountingBasis = 'Accrual') THEN SUM(CASE WHEN g.GLAccountType IN ('Expense', 'Asset', 'Other Expense', 'Non-Operating Expense') THEN -b.AccrualBudget ELSE b.AccrualBudget END)
													WHEN (@accountingBasis = 'Cash') THEN SUM(CASE WHEN g.GLAccountType IN ('Expense', 'Asset', 'Other Expense', 'Non-Operating Expense') THEN -b.CashBudget ELSE b.CashBudget END)
													END 
												FROM Budget b
												INNER JOIN GLAccount g on g.GLAccountID = b.GLAccountID
												WHERE b.PropertyAccountingPeriodID IN (SELECT DISTINCT PropertyAccountingPeriodID
																							FROM PropertyAccountingPeriod
																							WHERE PropertyID IN (SELECT Value FROM @propertyIDs)
																							  AND PropertyID = #AllInfo.PropertyID
																							  AND AccountingPeriodID = @accountingPeriodID)
												  AND b.GLAccountID = #AllInfo.GLAccountID)
												  

	UPDATE #PropertiesAndDates SET FiscalYearStartDate = (SELECT dbo.GetFiscalYearStartDate(@accountID, @accountingPeriodID, #PropertiesAndDates.PropertyID))
		

	UPDATE #AllInfo SET YTDBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN SUM(CASE WHEN g.GLAccountType IN ('Expense', 'Asset', 'Other Expense', 'Non-Operating Expense') THEN -b.AccrualBudget ELSE b.AccrualBudget END)
												WHEN (@accountingBasis = 'Cash') THEN SUM(CASE WHEN g.GLAccountType IN ('Expense', 'Asset', 'Other Expense', 'Non-Operating Expense') THEN -b.CashBudget ELSE b.CashBudget END)
												END
										FROM Budget b
										INNER JOIN GLAccount g on g.GLAccountID = b.GLAccountID
										WHERE b.GLAccountID = #AllInfo.GLAccountID
										  AND b.PropertyAccountingPeriodID IN (SELECT DISTINCT pap.PropertyAccountingPeriodID
																				  FROM PropertyAccountingPeriod pap
																					  INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
																				  WHERE pap.PropertyID = #AllInfo.PropertyID
																				    AND pap.StartDate >= #pad.FiscalYearStartDate /*@fiscalYearStartDate*/
																				    AND pap.EndDate <= (SELECT EndDate	
																											FROM PropertyAccountingPeriod 
																											WHERE AccountingPeriodID = @accountingPeriodID
																											  AND PropertyID = #AllInfo.PropertyID)))																											 								
										
	UPDATE  #AllInfo SET YTDAmount = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.NetMonthlyTotalAccrual), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.NetMonthlyTotalCash), 0)
												END
										 FROM Budget b
										 WHERE b.GLAccountID = #AllInfo.GLAccountID
										   AND b.PropertyAccountingPeriodID IN (SELECT DISTINCT pap.PropertyAccountingPeriodID
																					FROM PropertyAccountingPeriod pap
																						--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID AND pap.Closed = 1
																						INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
																					WHERE pap.Closed = 1
																					  AND pap.StartDate >= #pad.FiscalYearStartDate /*@fiscalYearStartDate*/
																					  AND pap.PropertyID = #AllInfo.PropertyID))
																					  
	UPDATE #AllInfo SET YTDAmount = YTDAmount + (SELECT ISNULL(SUM(je.Amount), 0)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														INNER JOIN #PropertiesAndDates #pad ON pap.PropertyID = #pad.PropertyID
													WHERE t.TransactionDate >= pap.StartDate
													  AND t.TransactionDate >= #pad.FiscalYearStartDate /*@fiscalYearStartDate*/
													  AND t.TransactionDate <= pap.EndDate
													   AND t.Origin NOT IN ('Y', 'E')
													  AND t.TransactionDate <= (SELECT EndDate 
																					FROM PropertyAccountingPeriod 
																					WHERE PropertyID = #AllInfo.PropertyID
																					  AND AccountingPeriodID = @accountingPeriodID)
													  AND je.AccountingBasis = @accountingBasis
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND t.PropertyID = #AllInfo.PropertyID
													  AND je.AccountingBookID IS NULL
													  AND pap.PropertyID = #AllInfo.PropertyID)
													  
														  	

	SELECT 
			(SELECT Name FROM Property WHERE PropertyID = #AllInfo.PropertyID) AS 'PropertyName',
			GLAccountType,
			GLParent1 AS 'GLParent1',
			SUM(ISNULL(-CurrentAPAmount, 0)) AS 'MonthActual',
			SUM(ISNULL(CurrentAPBudget, 0)) AS 'MonthBudget',
			SUM(ISNULL(-YTDAmount, 0)) AS 'YTDActual',
			SUM(ISNULL(YTDBudget, 0)) AS 'YTDBudget',
			GLParent1OrderBy		
		FROM #AllInfo
		GROUP BY #AllInfo.PropertyID, GLAccountType, GLParent1, GLParent1OrderBy--, OrderByPath
		ORDER BY 'PropertyName', GLParent1OrderBy
		
END







GO
