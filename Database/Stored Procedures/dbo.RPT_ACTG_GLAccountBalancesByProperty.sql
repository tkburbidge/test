SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_ACTG_GLAccountBalancesByProperty] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@glAccountIDs GuidCollection READONLY,
	@accountingBookIDs GuidCollection READONLY,
	@accountingBasis nvarchar(50) = null,
	@alternateChartOfAccountsID uniqueidentifier = null,
	@accountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS

DECLARE @accountID bigint = null
DECLARE @reportGLAccountTypes StringCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here

	CREATE TABLE #GLAccountInfo (
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
		UnitCount int null,
		ActualAmount money null default 0,
		YTDAmount money null default 0
		)

	CREATE TABLE #GLAccountIDs (
		GLAccountID uniqueidentifier not null
		)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date not null,
		EndDate date not null,
		FiscalYearStartDate date null,
		AccountingPeriodID uniqueidentifier null
		)

	IF (0 = (SELECT COUNT(*) FROM @glAccountIDs))
	BEGIN
		INSERT #GLAccountIDs
			SELECT GLAccountID
				FROM GLAccount
				WHERE AccountID = @accountID
	END
	ELSE
	BEGIN
		INSERT #GLAccountIDs
			SELECT Value
				FROM @glAccountIDs
	END

	INSERT #PropertiesAndDates
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate), null, @accountingPeriodID
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	UPDATE #PropertiesAndDates SET AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
															 FROM PropertyAccountingPeriod
															 WHERE PropertyID = #PropertiesAndDates.PropertyID
															   AND StartDate <= #PropertiesAndDates.StartDate
															   AND EndDate >= #PropertiesAndDates.StartDate)
		WHERE AccountingPeriodID IS NULL

	UPDATE #PropertiesAndDates SET FiscalYearStartDate = dbo.GetFiscalYearStartDate(@accountID, #PropertiesAndDates.AccountingPeriodID, #PropertiesAndDates.PropertyID)

	INSERT @reportGLAccountTypes 
		SELECT DISTINCT GLAccountType
			FROM GLAccount
			WHERE GLAccountID IN (SELECT GLAccountID FROM #GLAccountIDs)

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT PropertyID FROM #PropertiesAndDates))

	INSERT #GLAccountInfo 
		SELECT	#pads.PropertyID,
				#gla.GLAccountID,
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
				0
			FROM GetChartOfAccounts(@accountID, @reportGLAccountTypes) [ChartOfAccounts]
				INNER JOIN #GLAccountIDs #gla ON [ChartOfAccounts].GLAccountID = #gla.GLAccountID
				INNER JOIN #PropertiesAndDates #pads ON 1=1

	UPDATE #GLAccountInfo SET UnitCount = (SELECT COUNT(DISTINCT u.UnitID)
											   FROM Unit u
												   INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
												   INNER JOIN #PropertiesAndDates #pads ON ut.PropertyID = #pads.PropertyID
											   WHERE u.IsHoldingUnit = 0
											     AND u.ExcludedFromOccupancy = 0
												 AND (u.DateRemoved IS NULL OR u.DateRemoved > #pads.EndDate)
												 AND ut.PropertyID = #GLAccountInfo.PropertyID)

	UPDATE #GLAccountInfo SET ActualAmount = (SELECT SUM(je.Amount)
												  FROM JournalEntry je
													  INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													  INNER JOIN #PropertiesAndDates #pads ON t.PropertyID = #pads.PropertyID
												  WHERE t.TransactionDate >= #pads.StartDate													
													AND t.TransactionDate <= #pads.EndDate
													-- Don't include closing the year entries
													AND t.Origin NOT IN ('Y', 'E')
													AND je.AccountingBookID IS NULL
													AND je.GLAccountID = #GLAccountInfo.GLAccountID
													AND t.PropertyID = #GLAccountInfo.PropertyID
													AND je.AccountingBasis = @accountingBasis)

	UPDATE #GLAccountInfo SET YTDAmount = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													INNER JOIN #PropertiesAndDates #pads ON t.PropertyID = #pads.PropertyID
												WHERE t.TransactionDate >= #pads.FiscalYearStartDate													
												  AND t.TransactionDate <= #pads.EndDate
												  -- Don't include closing the year entries
												  AND t.Origin NOT IN ('Y', 'E')
												  AND je.AccountingBookID IS NULL
												  AND je.GLAccountID = #GLAccountInfo.GLAccountID
												  AND t.PropertyID = #GLAccountInfo.PropertyID
												  AND je.AccountingBasis = @accountingBasis)

	SELECT	#gla.PropertyID,
			prop.Name as 'PropertyName',
			prop.Abbreviation as 'PropertyAbbreviation',
			#gla.GLAccountID,
			#gla.Number as 'GLAccountNumber',
			#gla.Name as 'GLAccountName',
			#gla.[Description],
			#gla.GLAccountType,
			#gla.ParentGLAccountID,
			#gla.[Depth],
			#gla.IsLeaf,
			#gla.SummaryParent,
			#gla.[OrderByPath],
			#gla.[Path],
			#gla.SummaryParentPath,
			#gla.UnitCount,
			ISNULL(#gla.ActualAmount, 0) as 'ActualAmount',
			ISNULL(#gla.YTDAmount, 0) as 'YTDAmount'
		FROM #GLAccountInfo #gla
			INNER JOIN Property prop ON #gla.PropertyID = prop.PropertyID
		ORDER BY prop.Name, #gla.Number

END
GO
