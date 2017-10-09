SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE PROCEDURE [dbo].[RPT_CSTM_GEN_TwelveMonthBudgetVarianceComparison] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 1,
	@propertyIDs GuidCollection READONLY, 
	@accountingBasis nvarchar(15) = null,
	@accountingPeriodID uniqueidentifier = null,		-- The second, or later period to compare.
	@budgetsOnly bit = 0,
	@byProperty bit = 0,
	@glAccountIDs GuidCollection READONLY,
	@includeDefaultAccountingBook bit = 1,
	@accountingBookIDs GuidCollection READONLY
AS

DECLARE @earlyAccountingPeriodID uniqueidentifier = null

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	CREATE TABLE #EarlyPeriodResults (
		EarlyPropertyID uniqueidentifier null,
		EarlyGLAccountID uniqueidentifier null,
		EarlyGLNumber nvarchar(20) null,
		EarlyGLName nvarchar(100) null,
		EarlyGLAccountType nvarchar(50) null,
		EarlyMonth1Amount money null,
		EarlyMonth1Budget money null,
		EarlyMonth1Balance money null,
		EarlyMonth2Amount money null,
		EarlyMonth2Budget money null,
		EarlyMonth2Balance money null,
		EarlyMonth3Amount money null,
		EarlyMonth3Budget money null,
		EarlyMonth3Balance money null,
		EarlyMonth4Amount money null,
		EarlyMonth4Budget money null,
		EarlyMonth4Balance money null,
		EarlyMonth5Amount money null,
		EarlyMonth5Budget money null,
		EarlyMonth5Balance money null,
		EarlyMonth6Amount money null,
		EarlyMonth6Budget money null,
		EarlyMonth6Balance money null,
		EarlyMonth7Amount money null,
		EarlyMonth7Budget money null,
		EarlyMonth7Balance money null,
		EarlyMonth8Amount money null,
		EarlyMonth8Budget money null,
		EarlyMonth8Balance money null,
		EarlyMonth9Amount money null,
		EarlyMonth9Budget money null,
		EarlyMonth9Balance money null,
		EarlyMonth10Amount money null,
		EarlyMonth10Budget money null,
		EarlyMonth10Balance money null,
		EarlyMonth11Amount money null,
		EarlyMonth11Budget money null,
		EarlyMonth11Balance money null,
		EarlyMonth12Amount money null,
		EarlyMonth12Budget money null,
		EarlyMonth12Balance money null,
		EarlyTotalAmount money null,
		EarlyTotalBudget money null
	)

	CREATE TABLE #LaterPeriodResults (
		LaterPropertyID uniqueidentifier null,
		LaterGLAccountID uniqueidentifier null,
		LaterGLNumber nvarchar(20) null,
		LaterGLName nvarchar(100) null,
		LaterGLAccountType nvarchar(50) null,
		LaterMonth1Amount money null,
		LaterMonth1Budget money null,
		LaterMonth1Balance money null,
		LaterMonth2Amount money null,
		LaterMonth2Budget money null,
		LaterMonth2Balance money null,
		LaterMonth3Amount money null,
		LaterMonth3Budget money null,
		LaterMonth3Balance money null,
		LaterMonth4Amount money null,
		LaterMonth4Budget money null,
		LaterMonth4Balance money null,
		LaterMonth5Amount money null,
		LaterMonth5Budget money null,
		LaterMonth5Balance money null,
		LaterMonth6Amount money null,
		LaterMonth6Budget money null,
		LaterMonth6Balance money null,
		LaterMonth7Amount money null,
		LaterMonth7Budget money null,
		LaterMonth7Balance money null,
		LaterMonth8Amount money null,
		LaterMonth8Budget money null,
		LaterMonth8Balance money null,
		LaterMonth9Amount money null,
		LaterMonth9Budget money null,
		LaterMonth9Balance money null,
		LaterMonth10Amount money null,
		LaterMonth10Budget money null,
		LaterMonth10Balance money null,
		LaterMonth11Amount money null,
		LaterMonth11Budget money null,
		LaterMonth11Balance money null,
		LaterMonth12Amount money null,
		LaterMonth12Budget money null,
		LaterMonth12Balance money null,
		LaterTotalAmount money null,
		LaterTotalBudget money null
	)


	SET @earlyAccountingPeriodID = (SELECT TOP 1 AccountingPeriodID 
										FROM (SELECT TOP 13 *
												FROM AccountingPeriod
												WHERE StartDate <= (SELECT StartDate
																		FROM AccountingPeriod
																		WHERE AccountingPeriodID = @accountingPeriodID)
												ORDER BY StartDate DESC) [OrderedAPs]
										ORDER BY StartDate ASC)

	INSERT INTO #EarlyPeriodResults
		EXEC RPT_CSTM_GEN_TwelveMonthBudgetVariance @accountID, @propertyIDs, @accountingBasis, @earlyAccountingPeriodID, @budgetsOnly,
							@byProperty, @glAccountIDs, @includeDefaultAccountingBook, @accountingBookIDs


	INSERT #LaterPeriodResults
		EXEC [dbo].[RPT_CSTM_GEN_TwelveMonthBudgetVariance] @accountID, @propertyIDs, @accountingBasis, @accountingPeriodID, @budgetsOnly,
							@byProperty, @glAccountIDs, @includeDefaultAccountingBook, @accountingBookIDs

	SELECT *
		FROM #EarlyPeriodResults #epr
			INNER JOIN #LaterPeriodResults #lpr ON #epr.EarlyGLAccountID = #lpr.LaterGLAccountID 
					AND ISNULL(#epr.EarlyPropertyID, '99999999-9999-9999-9999-999999999999') = ISNULL(#lpr.LaterPropertyID, '99999999-9999-9999-9999-999999999999')
		ORDER BY #epr.EarlyGLNumber


END
GO
