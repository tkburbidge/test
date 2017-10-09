SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


/****** Object:  StoredProcedure [dbo].[RPT_ACTG_TwelveMonthBudgetVariance]    Script Date: 09/11/2012 09:40:00 ******/
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 16, 2012
-- Description:	Gets the basic information for a variety of Financial Reports
-- =============================================
CREATE PROCEDURE [dbo].[RPT_ACTG_TwelveMonthBudgetVariance_OLD] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@reportName nvarchar(50) = null,
	@accountingBasis nvarchar(10) = null,
	@accountingPeriodID uniqueidentifier = null,
	@budgetsOnly bit = 1
AS

DECLARE @fiscalYearBegin tinyint
DECLARE @fiscalYearStartDate datetime
DECLARE @accountID bigint
DECLARE @endDate datetime

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
		JanBudget money null,
		JanActual money null,
		JanNotes nvarchar(MAX) null,
		FebBudget money null,
		FebActual money null,
		FebNotes nvarchar(MAX) null,
		MarBudget money null,
		MarActual money null,
		MarNotes nvarchar(MAX) null,
		AprBudget money null,
		AprActual money null,
		AprNotes nvarchar(MAX) null,
		MayBudget money null,
		MayActual money null,
		MayNotes nvarchar(MAX) null,
		JunBudget money null,
		JunActual money null,
		JunNotes nvarchar(MAX) null,
		JulBudget money null,
		JulActual money null,
		JulNotes nvarchar(MAX) null,
		AugBudget money null,
		AugActual money null,
		AugNotes nvarchar(MAX) null,
		SepBudget money null,
		SepActual money null,
		SepNotes nvarchar(MAX) null,
		OctBudget money null,
		OctActual money null,
		OctNotes nvarchar(MAX) null,
		NovBudget money null,
		NovActual money null,
		NovNotes nvarchar(MAX) null,
		DecBudget money null,
		DecActual money null,
		DecNotes nvarchar(4000) null																		
		)
		
	CREATE NONCLUSTERED INDEX [IX_#AllInfo_GLAccount] ON [#AllInfo] 
	(
		[GLAccountID] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
		
	IF (@reportName = 'Cash Flow Statement')
	BEGIN
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
					gla1.GLAccountType AS 'GLAccountType',
					0 AS 'JanBudget', 0 AS 'JanActual', null AS 'JanNotes',
					0 AS 'FebBudget', 0 AS 'FebActual', null AS 'FebNotes',
					0 AS 'MarBudget', 0 AS 'MarActual', null AS 'MarNotes',
					0 AS 'AprBudget', 0 AS 'AprActual', null AS 'AprNotes',
					0 AS 'MayBudget', 0 AS 'MayActual', null AS 'MayNotes',
					0 AS 'JunBudget', 0 AS 'JunActual', null AS 'JunNotes',
					0 AS 'JulBudget', 0 AS 'JulActual', null AS 'JulNotes',				
					0 AS 'AugBudget', 0 AS 'AugActual', null AS 'AugNotes',
					0 AS 'SepBudget', 0 AS 'SepActual', null AS 'SepNotes',																												
					0 AS 'OctBudget', 0 AS 'OctActual', null AS 'OctNotes',
					0 AS 'NovBudget', 0 AS 'NovActual', null AS 'NovNotes',
					0 AS 'DecBudget', 0 AS 'DecActual', null AS 'DecNotes'						
			FROM ReportGroup rg
				INNER JOIN GLAccountGroup glac1 on rg.ChildGLAccountGroupID = glac1.GLAccountGroupID AND rg.ParentGLAccountGroupID IS NULL
				INNER JOIN ReportGroup rg1 on glac1.GLAccountGroupID = rg1.ParentGLAccountGroupID
				INNER JOIN GLAccountGroup glac2 on rg1.ChildGLAccountGroupID = glac2.GLAccountGroupID AND rg1.ChildGLAccountGroupID IS NOT NULL
				INNER JOIN ReportGroup rg2 on glac2.GLAccountGroupID = rg2.ParentGLAccountGroupID
				INNER JOIN GLAccountGroup glac3n on rg2.ChildGLAccountGroupID = glac3n.GLAccountGroupID 
				INNER JOIN GLAccountGLAccountGroup glgroup1 on glac3n.GLAccountGroupID = glgroup1.GLAccountGroupID
				INNER JOIN GLAccount gla1 on glgroup1.GLAccountID = gla1.GLAccountID
				INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
			WHERE rg.ReportName = 'Income Statement'
			  AND rg.AccountID = ap.AccountID
			  
		DECLARE @maxParentOrderBy int
		SET @maxParentOrderBy = (SELECT MAX(OrderBy1) FROM #AllInfo)
			
		INSERT INTO #AllInfo
			SELECT DISTINCT 
					glac1.ReportLabel AS 'Parent1',
					glac2.ReportLabel AS 'Parent2',
					glac3n.ReportLabel AS 'Parent3',
					rg.OrderBy + @maxParentOrderBy AS 'OrderBy1',
					rg1.OrderBy AS 'OrderBy2',
					rg2.OrderBy AS 'OrderBy3',
					gla1.Number AS 'GLAccountNumber',
					gla1.Name AS 'GLAccountName',
					gla1.GLAccountID AS 'GLAccountID',
					gla1.GLAccountType AS 'GLAccountType',
					0 AS 'JanBudget', 0 AS 'JanActual', null AS 'JanNotes',
					0 AS 'FebBudget', 0 AS 'FebActual', null AS 'FebNotes',
					0 AS 'MarBudget', 0 AS 'MarActual', null AS 'MarNotes',
					0 AS 'AprBudget', 0 AS 'AprActual', null AS 'AprNotes',
					0 AS 'MayBudget', 0 AS 'MayActual', null AS 'MayNotes',
					0 AS 'JunBudget', 0 AS 'JunActual', null AS 'JunNotes',
					0 AS 'JulBudget', 0 AS 'JulActual', null AS 'JulNotes',				
					0 AS 'AugBudget', 0 AS 'AugActual', null AS 'AugNotes',
					0 AS 'SepBudget', 0 AS 'SepActual', null AS 'SepNotes',																												
					0 AS 'OctBudget', 0 AS 'OctActual', null AS 'OctNotes',
					0 AS 'NovBudget', 0 AS 'NovActual', null AS 'NovNotes',
					0 AS 'DecBudget', 0 AS 'DecActual', null AS 'DecNotes'						
			FROM ReportGroup rg
				INNER JOIN GLAccountGroup glac1 on rg.ChildGLAccountGroupID = glac1.GLAccountGroupID AND rg.ParentGLAccountGroupID IS NULL
				INNER JOIN ReportGroup rg1 on glac1.GLAccountGroupID = rg1.ParentGLAccountGroupID
				INNER JOIN GLAccountGroup glac2 on rg1.ChildGLAccountGroupID = glac2.GLAccountGroupID AND rg1.ChildGLAccountGroupID IS NOT NULL
				INNER JOIN ReportGroup rg2 on glac2.GLAccountGroupID = rg2.ParentGLAccountGroupID
				INNER JOIN GLAccountGroup glac3n on rg2.ChildGLAccountGroupID = glac3n.GLAccountGroupID 
				INNER JOIN GLAccountGLAccountGroup glgroup1 on glac3n.GLAccountGroupID = glgroup1.GLAccountGroupID
				INNER JOIN GLAccount gla1 on glgroup1.GLAccountID = gla1.GLAccountID
				INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
			WHERE rg.ReportName = @reportName
			  AND rg.AccountID = ap.AccountID			
	END
	ELSE
	BEGIN
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
					gla1.GLAccountType AS 'GLAccountType',
					0 AS 'JanBudget', 0 AS 'JanActual', null AS 'JanNotes',
					0 AS 'FebBudget', 0 AS 'FebActual', null AS 'FebNotes',
					0 AS 'MarBudget', 0 AS 'MarActual', null AS 'MarNotes',
					0 AS 'AprBudget', 0 AS 'AprActual', null AS 'AprNotes',
					0 AS 'MayBudget', 0 AS 'MayActual', null AS 'MayNotes',
					0 AS 'JunBudget', 0 AS 'JunActual', null AS 'JunNotes',
					0 AS 'JulBudget', 0 AS 'JulActual', null AS 'JulNotes',				
					0 AS 'AugBudget', 0 AS 'AugActual', null AS 'AugNotes',
					0 AS 'SepBudget', 0 AS 'SepActual', null AS 'SepNotes',																												
					0 AS 'OctBudget', 0 AS 'OctActual', null AS 'OctNotes',
					0 AS 'NovBudget', 0 AS 'NovActual', null AS 'NovNotes',
					0 AS 'DecBudget', 0 AS 'DecActual', null AS 'DecNotes'						
			FROM ReportGroup rg
				INNER JOIN GLAccountGroup glac1 on rg.ChildGLAccountGroupID = glac1.GLAccountGroupID AND rg.ParentGLAccountGroupID IS NULL
				INNER JOIN ReportGroup rg1 on glac1.GLAccountGroupID = rg1.ParentGLAccountGroupID
				INNER JOIN GLAccountGroup glac2 on rg1.ChildGLAccountGroupID = glac2.GLAccountGroupID AND rg1.ChildGLAccountGroupID IS NOT NULL
				INNER JOIN ReportGroup rg2 on glac2.GLAccountGroupID = rg2.ParentGLAccountGroupID
				INNER JOIN GLAccountGroup glac3n on rg2.ChildGLAccountGroupID = glac3n.GLAccountGroupID 
				INNER JOIN GLAccountGLAccountGroup glgroup1 on glac3n.GLAccountGroupID = glgroup1.GLAccountGroupID
				INNER JOIN GLAccount gla1 on glgroup1.GLAccountID = gla1.GLAccountID
				INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
			WHERE rg.ReportName = @reportName
			  AND rg.AccountID = ap.AccountID	
	END
		  
    SELECT @endDate = EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID	
    	
    IF (@budgetsOnly = 0)
    BEGIN  		  
		UPDATE #AllInfo SET JanActual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													WHERE t.TransactionDate >= ap.StartDate
													  AND t.TransactionDate <= ap.EndDate
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																						FROM AccountingPeriod 
																						WHERE DATEPART(month, EndDate) = 1
																						  AND EndDate <= @endDate
																						  AND AccountID = ap.AccountID
																						ORDER BY EndDate DESC)																					  
													  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
													  
		UPDATE #AllInfo SET JanActual = ISNULL(JanActual, 0) + ISNULL((SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																END
														 FROM Budget b
															INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
															INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
														   AND b.GLAccountID = #AllInfo.GLAccountID
														   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																							FROM AccountingPeriod 
																							WHERE DATEPART(month, EndDate) = 1
																							  AND EndDate <= @endDate
																							  AND AccountID = ap.AccountID
																							ORDER BY EndDate DESC)), 0)
	END
																			
	UPDATE #AllInfo SET JanBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
												END
										 FROM Budget b
											INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
											INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
										 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
										   AND b.GLAccountID = #AllInfo.GLAccountID
										   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																			FROM AccountingPeriod 
																			WHERE DATEPART(month, EndDate) = 1
																			  AND EndDate <= @endDate
																			  AND AccountID = ap.AccountID
																			ORDER BY EndDate DESC))	
																			
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
		UPDATE #AllInfo SET FebActual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													WHERE t.TransactionDate >= ap.StartDate
													  AND t.TransactionDate <= ap.EndDate
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																						FROM AccountingPeriod 
																						WHERE DATEPART(month, EndDate) = 2
																						  AND EndDate <= @endDate
																						  AND AccountID = ap.AccountID
																						ORDER BY EndDate DESC)																					  
													  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
													  
		UPDATE #AllInfo SET FebActual = ISNULL(FebActual, 0) + ISNULL((SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																END
														 FROM Budget b
															INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
															INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
														   AND b.GLAccountID = #AllInfo.GLAccountID
														   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																							FROM AccountingPeriod 
																							WHERE DATEPART(month, EndDate) = 2
																							  AND EndDate <= @endDate
																							  AND AccountID = ap.AccountID
																							ORDER BY EndDate DESC)), 0)
	END
																			
	UPDATE #AllInfo SET FebBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
												END
										 FROM Budget b
											INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
											INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
										 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
										   AND b.GLAccountID = #AllInfo.GLAccountID
										   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																			FROM AccountingPeriod 
																			WHERE DATEPART(month, EndDate) = 2
																			  AND EndDate <= @endDate
																			  AND AccountID = ap.AccountID
																			ORDER BY EndDate DESC))	
																			
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
		UPDATE #AllInfo SET MarActual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													WHERE t.TransactionDate >= ap.StartDate
													  AND t.TransactionDate <= ap.EndDate
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																						FROM AccountingPeriod 
																						WHERE DATEPART(month, EndDate) = 3
																						  AND EndDate <= @endDate
																						  AND AccountID = ap.AccountID
																						ORDER BY EndDate DESC)																					  
													  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
													  
		UPDATE #AllInfo SET MarActual = ISNULL(MarActual, 0) + ISNULL((SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																END
														 FROM Budget b
															INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
															INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
														   AND b.GLAccountID = #AllInfo.GLAccountID
														   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																							FROM AccountingPeriod 
																							WHERE DATEPART(month, EndDate) = 3
																							  AND EndDate <= @endDate
																							  AND AccountID = ap.AccountID
																							ORDER BY EndDate DESC)), 0)
	END
																			
	UPDATE #AllInfo SET MarBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
												END
										 FROM Budget b
											INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
											INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
										 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
										   AND b.GLAccountID = #AllInfo.GLAccountID
										   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																			FROM AccountingPeriod 
																			WHERE DATEPART(month, EndDate) = 3
																			  AND EndDate <= @endDate
																			  AND AccountID = ap.AccountID
																			ORDER BY EndDate DESC))	
																			
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
		UPDATE #AllInfo SET AprActual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													WHERE t.TransactionDate >= ap.StartDate
													  AND t.TransactionDate <= ap.EndDate
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																						FROM AccountingPeriod 
																						WHERE DATEPART(month, EndDate) = 4
																						  AND EndDate <= @endDate
																						  AND AccountID = ap.AccountID
																						ORDER BY EndDate DESC)																					  
													  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
													  
		UPDATE #AllInfo SET AprActual = ISNULL(AprActual, 0) + ISNULL((SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																END
														 FROM Budget b
															INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
															INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
														   AND b.GLAccountID = #AllInfo.GLAccountID
														   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																							FROM AccountingPeriod 
																							WHERE DATEPART(month, EndDate) = 4
																							  AND EndDate <= @endDate
																							  AND AccountID = ap.AccountID
																							ORDER BY EndDate DESC)), 0)	
	END
																			
	UPDATE #AllInfo SET AprBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
												END
										 FROM Budget b
											INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
											INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
										 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
										   AND b.GLAccountID = #AllInfo.GLAccountID
										   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																			FROM AccountingPeriod 
																			WHERE DATEPART(month, EndDate) = 4
																			  AND EndDate <= @endDate
																			  AND AccountID = ap.AccountID
																			ORDER BY EndDate DESC))	
																			
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
		UPDATE #AllInfo SET MayActual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													WHERE t.TransactionDate >= ap.StartDate
													  AND t.TransactionDate <= ap.EndDate
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																						FROM AccountingPeriod 
																						WHERE DATEPART(month, EndDate) = 5
																						  AND EndDate <= @endDate
																						  AND AccountID = ap.AccountID
																						ORDER BY EndDate DESC)																					  
													  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
													  
		UPDATE #AllInfo SET MayActual = ISNULL(MayActual, 0) + ISNULL((SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																END
														 FROM Budget b
															INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
															INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
														   AND b.GLAccountID = #AllInfo.GLAccountID
														   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																							FROM AccountingPeriod 
																							WHERE DATEPART(month, EndDate) = 5
																							  AND EndDate <= @endDate
																							  AND AccountID = ap.AccountID
																							ORDER BY EndDate DESC)), 0)
	END
																			
	UPDATE #AllInfo SET MayBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
												END
										 FROM Budget b
											INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
											INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
										 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
										   AND b.GLAccountID = #AllInfo.GLAccountID
										   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																			FROM AccountingPeriod 
																			WHERE DATEPART(month, EndDate) = 5
																			  AND EndDate <= @endDate
																			  AND AccountID = ap.AccountID
																			ORDER BY EndDate DESC))	
																													 
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
		UPDATE #AllInfo SET JunActual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													WHERE t.TransactionDate >= ap.StartDate
													  AND t.TransactionDate <= ap.EndDate
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																						FROM AccountingPeriod 
																						WHERE DATEPART(month, EndDate) = 6
																						  AND EndDate <= @endDate
																						  AND AccountID = ap.AccountID
																						ORDER BY EndDate DESC)																					  
													  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
													  
		UPDATE #AllInfo SET JunActual = ISNULL(JunActual, 0) + ISNULL((SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																END
														 FROM Budget b
															INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
															INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
														   AND b.GLAccountID = #AllInfo.GLAccountID
														   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																							FROM AccountingPeriod 
																							WHERE DATEPART(month, EndDate) = 6
																							  AND EndDate <= @endDate
																							  AND AccountID = ap.AccountID
																							ORDER BY EndDate DESC)), 0)
	END
																			
	UPDATE #AllInfo SET JunBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
												END
										 FROM Budget b
											INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
											INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
										 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
										   AND b.GLAccountID = #AllInfo.GLAccountID
										   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																			FROM AccountingPeriod 
																			WHERE DATEPART(month, EndDate) = 6
																			  AND EndDate <= @endDate
																			  AND AccountID = ap.AccountID
																			ORDER BY EndDate DESC))	
																			
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
		UPDATE #AllInfo SET JulActual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													WHERE t.TransactionDate >= ap.StartDate
													  AND t.TransactionDate <= ap.EndDate
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																						FROM AccountingPeriod 
																						WHERE DATEPART(month, EndDate) = 7
																						  AND EndDate <= @endDate
																						  AND AccountID = ap.AccountID
																						ORDER BY EndDate DESC)																					  
													  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
													  
		UPDATE #AllInfo SET JulActual = ISNULL(JulActual, 0) + ISNULL((SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																END
														 FROM Budget b
															INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
															INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
														   AND b.GLAccountID = #AllInfo.GLAccountID
														   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																							FROM AccountingPeriod 
																							WHERE DATEPART(month, EndDate) = 7
																							  AND EndDate <= @endDate
																							  AND AccountID = ap.AccountID
																							ORDER BY EndDate DESC)), 0)
	END
																			
	UPDATE #AllInfo SET JulBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
												END
										 FROM Budget b
											INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
											INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
										 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
										   AND b.GLAccountID = #AllInfo.GLAccountID
										   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																			FROM AccountingPeriod 
																			WHERE DATEPART(month, EndDate) = 7
																			  AND EndDate <= @endDate
																			  AND AccountID = ap.AccountID
																			ORDER BY EndDate DESC))	
																			
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
		UPDATE #AllInfo SET AugActual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													WHERE t.TransactionDate >= ap.StartDate
													  AND t.TransactionDate <= ap.EndDate
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																						FROM AccountingPeriod 
																						WHERE DATEPART(month, EndDate) = 8
																						  AND EndDate <= @endDate
																						  AND AccountID = ap.AccountID
																						ORDER BY EndDate DESC)																					  
													  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
													  
		UPDATE #AllInfo SET AugActual = ISNULL(AugActual, 0) + ISNULL((SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																END
														 FROM Budget b
															INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
															INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
														   AND b.GLAccountID = #AllInfo.GLAccountID
														   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																							FROM AccountingPeriod 
																							WHERE DATEPART(month, EndDate) = 8
																							  AND EndDate <= @endDate
																							  AND AccountID = ap.AccountID
																							ORDER BY EndDate DESC)), 0)
	END
																			
	UPDATE #AllInfo SET AugBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
												END
										 FROM Budget b
											INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
											INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
										 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
										   AND b.GLAccountID = #AllInfo.GLAccountID
										   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																			FROM AccountingPeriod 
																			WHERE DATEPART(month, EndDate) = 8
																			  AND EndDate <= @endDate
																			  AND AccountID = ap.AccountID
																			ORDER BY EndDate DESC))	
																			
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
		UPDATE #AllInfo SET SepActual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													WHERE t.TransactionDate >= ap.StartDate
													  AND t.TransactionDate <= ap.EndDate
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																						FROM AccountingPeriod 
																						WHERE DATEPART(month, EndDate) = 9
																						  AND EndDate <= @endDate
																						  AND AccountID = ap.AccountID
																						ORDER BY EndDate DESC)																					  
													  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
													  
		UPDATE #AllInfo SET SepActual = ISNULL(SepActual, 0) + ISNULL((SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																END
														 FROM Budget b
															INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
															INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
														   AND b.GLAccountID = #AllInfo.GLAccountID
														   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																							FROM AccountingPeriod 
																							WHERE DATEPART(month, EndDate) = 9
																							  AND EndDate <= @endDate
																							  AND AccountID = ap.AccountID
																							ORDER BY EndDate DESC)), 0)
	END
																			
	UPDATE #AllInfo SET SepBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
												END
										 FROM Budget b
											INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
											INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
										 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
										   AND b.GLAccountID = #AllInfo.GLAccountID
										   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																			FROM AccountingPeriod 
																			WHERE DATEPART(month, EndDate) = 9
																			  AND EndDate <= @endDate
																			  AND AccountID = ap.AccountID
																			ORDER BY EndDate DESC))	
																			
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
		UPDATE #AllInfo SET OctActual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													WHERE t.TransactionDate >= ap.StartDate
													  AND t.TransactionDate <= ap.EndDate
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																						FROM AccountingPeriod 
																						WHERE DATEPART(month, EndDate) = 10
																						  AND EndDate <= @endDate
																						  AND AccountID = ap.AccountID
																						ORDER BY EndDate DESC)																					  
													  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
													  
		UPDATE #AllInfo SET OctActual = ISNULL(OctActual, 0) + ISNULL((SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																END
														 FROM Budget b
															INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
															INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
														   AND b.GLAccountID = #AllInfo.GLAccountID
														   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																							FROM AccountingPeriod 
																							WHERE DATEPART(month, EndDate) = 10
																							  AND EndDate <= @endDate
																							  AND AccountID = ap.AccountID
																							ORDER BY EndDate DESC)), 0)	
	END
																			
	UPDATE #AllInfo SET OctBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
												END
										 FROM Budget b
											INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
											INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
										 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
										   AND b.GLAccountID = #AllInfo.GLAccountID
										   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																			FROM AccountingPeriod 
																			WHERE DATEPART(month, EndDate) = 10
																			  AND EndDate <= @endDate
																			  AND AccountID = ap.AccountID
																			ORDER BY EndDate DESC))	
																			
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
		UPDATE #AllInfo SET NovActual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													WHERE t.TransactionDate >= ap.StartDate
													  AND t.TransactionDate <= ap.EndDate
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																						FROM AccountingPeriod 
																						WHERE DATEPART(month, EndDate) = 11
																						  AND EndDate <= @endDate
																						  AND AccountID = ap.AccountID
																						ORDER BY EndDate DESC)																					  
													  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
													  
		UPDATE #AllInfo SET NovActual = ISNULL(NovActual, 0) + ISNULL((SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																END
														 FROM Budget b
															INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
															INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
														   AND b.GLAccountID = #AllInfo.GLAccountID
														   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																							FROM AccountingPeriod 
																							WHERE DATEPART(month, EndDate) = 11
																							  AND EndDate <= @endDate
																							  AND AccountID = ap.AccountID
																							ORDER BY EndDate DESC)), 0)	
	END
																			
	UPDATE #AllInfo SET NovBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
												END
										 FROM Budget b
											INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
											INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
										 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
										   AND b.GLAccountID = #AllInfo.GLAccountID
										   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																			FROM AccountingPeriod 
																			WHERE DATEPART(month, EndDate) = 11
																			  AND EndDate <= @endDate
																			  AND AccountID = ap.AccountID
																			ORDER BY EndDate DESC))	
																			
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
		UPDATE #AllInfo SET DecActual = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN PropertyAccountingPeriod pap ON t.PropertyID = pap.PropertyID AND pap.Closed = 0
														INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
													WHERE t.TransactionDate >= ap.StartDate
													  AND t.TransactionDate <= ap.EndDate
													  AND je.GLAccountID = #AllInfo.GLAccountID
													  AND je.AccountingBasis = @accountingBasis
													  AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																						FROM AccountingPeriod 
																						WHERE DATEPART(month, EndDate) = 12
																						  AND EndDate <= @endDate
																						  AND AccountID = ap.AccountID
																						ORDER BY EndDate DESC)																					  
													  AND t.PropertyID IN (SELECT Value FROM @propertyIDs))
													  
		UPDATE #AllInfo SET DecActual = ISNULL(DecActual, 0) + ISNULL((SELECT CASE
																WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalAccrual, 0)), 0)
																WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(ISNULL(b.NetMonthlyTotalCash, 0)), 0)
																END
														 FROM Budget b
															INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID AND pap.Closed = 1
															INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
														 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
														   AND b.GLAccountID = #AllInfo.GLAccountID
														   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																							FROM AccountingPeriod 
																							WHERE DATEPART(month, EndDate) = 12
																							  AND EndDate <= @endDate
																							  AND AccountID = ap.AccountID
																							ORDER BY EndDate DESC)), 0)
	END
																			
	UPDATE #AllInfo SET DecBudget = (SELECT CASE
												WHEN (@accountingBasis = 'Accrual') THEN ISNULL(SUM(b.AccrualBudget), 0)
												WHEN (@accountingBasis = 'Cash') THEN ISNULL(SUM(b.CashBudget), 0)
												END
										 FROM Budget b
											INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
											INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
										 WHERE pap.PropertyID IN (SELECT Value FROM @propertyIDs)
										   AND b.GLAccountID = #AllInfo.GLAccountID
										   AND ap.AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																			FROM AccountingPeriod 
																			WHERE DATEPART(month, EndDate) = 12
																			  AND EndDate <= @endDate
																			  AND AccountID = ap.AccountID
																			ORDER BY EndDate DESC))	
																			
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
																			
	IF (1 =	(SELECT HideZeroValuesInFinancialReports 
				FROM Settings s
					INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID AND s.AccountID = ap.AccountID))
	BEGIN
		SELECT  Parent1, Parent2, Parent3, OrderBy1, OrderBy2, OrderBy3, 
				GLAccountNumber, GLAccountName, GLAccountID, GLAccountType AS 'Type',
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
		 WHERE JanActual <> 0 OR JanBudget <> 0
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
		    OR DecActual <> 0 OR DecBudget <> 0	
		ORDER BY OrderBy1, OrderBy2, OrderBy3, GLAccountNumber
	END
	ELSE
	BEGIN
		SELECT  Parent1, Parent2, Parent3, OrderBy1, OrderBy2, OrderBy3, 
				GLAccountNumber, GLAccountName, GLAccountID, GLAccountType AS 'Type',
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
		 ORDER BY OrderBy1, OrderBy2, OrderBy3, GLAccountNumber
	 END
	 
END
GO
