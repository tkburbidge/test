SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO






-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 16, 2012
-- Description:	Gets the basic information for a variety of Financial Reports
-- =============================================
CREATE PROCEDURE [dbo].[RPT_ACTG_BalanceSheet_OLD] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@reportName nvarchar(50) = null,
	@accountingBasis nvarchar(10) = null,
	@statementDate datetime = null
AS

DECLARE @fiscalYearBegin tinyint
DECLARE @fiscalYearStartDate datetime
DECLARE @accountID bigint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #AllInfo (
		Parent1 nvarchar(50) null,
		Parent2 nvarchar(50) null,
		Parent3 nvarchar(50) null,
		OrderBy1 smallint  null,
		OrderBy2 smallint null,
		OrderBy3 smallint  null,
		GLAccountNumber nvarchar(50)  null,
		GLAccountName nvarchar(50)  null,
		GLAccountID uniqueidentifier  null,
		GLAccountType nvarchar(10) null,
		Balance money null)

		
	INSERT INTO #AllInfo
		SELECT DISTINCT 
				glac1.ReportLabel AS 'Parent1',
				glac2.ReportLabel AS 'Parent2',
				glac3n.ReportLabel AS 'Parent3',
				rg.OrderBy AS 'OrderBy1',
				rg1.OrderBy AS 'OrderBy2',
				rg2.OrderBy AS 'OrderBy3',
				gla1.Number AS 'GLAccountNumber',
				gla1.Name AS 'GLAccountName',
				gla1.GLAccountID AS 'GLAccountID',
				gla1.GLAccountType AS 'Type',
				null AS 'Balance'
		FROM ReportGroup rg
			INNER JOIN GLAccountGroup glac1 on rg.ChildGLAccountGroupID = glac1.GLAccountGroupID AND rg.ParentGLAccountGroupID IS NULL
			INNER JOIN ReportGroup rg1 on glac1.GLAccountGroupID = rg1.ParentGLAccountGroupID
			INNER JOIN GLAccountGroup glac2 on rg1.ChildGLAccountGroupID = glac2.GLAccountGroupID AND rg1.ChildGLAccountGroupID IS NOT NULL
			INNER JOIN ReportGroup rg2 on glac2.GLAccountGroupID = rg2.ParentGLAccountGroupID
			INNER JOIN GLAccountGroup glac3n on rg2.ChildGLAccountGroupID = glac3n.GLAccountGroupID 
			INNER JOIN GLAccountGLAccountGroup glgroup1 on glac3n.GLAccountGroupID = glgroup1.GLAccountGroupID
			INNER JOIN GLAccount gla1 on glgroup1.GLAccountID = gla1.GLAccountID
		WHERE rg.ReportName = @reportName
		  AND rg.AccountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))
		  
	UPDATE #AllInfo SET Balance = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID 
													INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
												WHERE t.TransactionDate >= ap.StartDate
												  AND t.TransactionDate <= ap.EndDate
												  AND t.TransactionDate <= @statementDate
												  AND je.GLAccountID = #AllInfo.GLAccountID
												  AND je.AccountingBasis = @accountingBasis
												  AND (pap.Closed = 0 OR (ap.StartDate <= @statementDate AND ap.EndDate > @statementDate))
												  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
												  
	UPDATE #AllInfo SET Balance = ISNULL(Balance, 0) + ISNULL((SELECT CASE
															WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.NetMonthlyTotalAccrual), 0)
															WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.NetMonthlyTotalCash), 0)
															END
													 FROM Budget b
														INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
													   AND ap.EndDate <= @statementDate
													   AND b.GLAccountID = #AllInfo.GLAccountID), 0)
													   
	IF (1 =	(SELECT HideZeroValuesInFinancialReports 
				FROM Settings s
				WHERE s.AccountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))))
	BEGIN
		SELECT Parent1, Parent2, Parent3, OrderBy1, OrderBy2, OrderBy3, GLAccountNumber AS 'Number', GLAccountName AS 'Name', GLAccountType AS 'Type', GLAccountID AS 'GLAccountID',
				ISNULL(Balance, 0) AS 'Balance'
			FROM #AllInfo
			WHERE Balance <> 0
			ORDER BY OrderBy1, OrderBy2, OrderBy3, GLAccountNumber	
	END
	ELSE
	BEGIN													  
		SELECT Parent1, Parent2, Parent3, OrderBy1, OrderBy2, OrderBy3, GLAccountNumber AS 'Number', GLAccountName AS 'Name', GLAccountType AS 'Type', GLAccountID AS 'GLAccountID',
				ISNULL(Balance, 0) AS 'Balance'
			FROM #AllInfo
			ORDER BY OrderBy1, OrderBy2, OrderBy3, GLAccountNumber
	END
			
END
GO
