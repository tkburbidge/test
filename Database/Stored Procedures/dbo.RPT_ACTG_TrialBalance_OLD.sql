SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO









-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 16, 2012
-- Description:	Gets the basic information for a variety of Financial Reports
-- =============================================
CREATE PROCEDURE [dbo].[RPT_ACTG_TrialBalance_OLD] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@accountingBasis nvarchar(10) = null,
	@startDate datetime = null,
	@endDate datetime = null
AS

DECLARE @fiscalYearBegin tinyint
DECLARE @fiscalYearStartDate datetime
DECLARE @accountID bigint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #AllInfo (
		Number nvarchar(50)  null,
		Name nvarchar(50)  null,
		GLAccountID uniqueidentifier  null,
		GLAccountType nvarchar(10) null,
		BeginningBalance money null,
		Amount money null)

		
	INSERT INTO #AllInfo
		SELECT DISTINCT 
				gla1.Number AS 'Number',
				gla1.Name AS 'Name',
				gla1.GLAccountID AS 'GLAccountID',
				gla1.GLAccountType AS 'Type',
				null AS 'BeginningBalance',
				null AS 'Amount'
		FROM GLAccount gla1 
		WHERE gla1.AccountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))		
		  
	UPDATE #AllInfo SET BeginningBalance = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													--INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
													--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
												WHERE --t.TransactionDate >= ap.StartDate
												  --AND t.TransactionDate <= ap.EndDate
												  t.TransactionDate < @startDate
												  --AND t.TransactionDate >= @startDate
												  AND je.GLAccountID = #AllInfo.GLAccountID
												  AND je.AccountingBasis = @accountingBasis
												  AND #AllInfo.GLAccountType IN ('Asset', 'Liability', 'Equity')
												  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
												  
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
													   
	SELECT @fiscalYearBegin = ISNULL(s.FiscalYearStartMonth, 1)
		FROM Settings s		
		WHERE s.AccountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))
			
	SELECT @fiscalYearStartDate = ap.StartDate
		FROM AccountingPeriod ap
			INNER JOIN AccountingPeriod apc ON ap.AccountID = apc.AccountID
		WHERE ap.AccountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))
		  AND DATEPART(month, ap.StartDate) = @fiscalYearBegin
		  AND ((DATEPART(year, ap.StartDate) = DATEPART(year, @startDate)))
	IF (@fiscalYearStartDate > @startDate)
	BEGIN
		SET @fiscalYearStartDate = DATEADD(year, -1, @fiscalYearStartDate)
	END
	
	UPDATE #AllInfo SET BeginningBalance = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													--INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
													--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
												WHERE --t.TransactionDate >= ap.StartDate
												  --AND t.TransactionDate <= ap.EndDate
												   t.TransactionDate < @startDate
												  AND t.TransactionDate >= @fiscalYearStartDate
												  AND je.GLAccountID = #AllInfo.GLAccountID
												  AND je.AccountingBasis = @accountingBasis
												  AND #AllInfo.GLAccountType IN ('Income', 'Expense')
												  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
	WHERE #AllInfo.GLAccountType IN ('Income', 'Expense')
												  
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
												WHERE t.TransactionDate <= @endDate
												  AND t.TransactionDate >= @startDate
												  AND je.GLAccountID = #AllInfo.GLAccountID
												  AND je.AccountingBasis = @accountingBasis
												  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
												  													   
	IF (1 =	(SELECT HideZeroValuesInFinancialReports 
				FROM Settings s
				WHERE s.AccountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))))
	BEGIN
		SELECT GLAccountID, Number, Name,
				ISNULL(BeginningBalance, 0) AS 'BeginningBalance', ISNULL(Amount, 0) AS 'Amount'
			FROM #AllInfo
			WHERE BeginningBalance <> 0
			   OR Amount <> 0
			ORDER BY Number	
	END
	ELSE
	BEGIN													  
		SELECT GLAccountID, Number, Name,
				ISNULL(BeginningBalance, 0) AS 'BeginningBalance', ISNULL(Amount, 0) AS 'Amount'
			FROM #AllInfo
			ORDER BY Number
	END
			
END
GO
