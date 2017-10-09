SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 17, 2017
-- Description:	Gets the Rentlytics GL Account List
-- =============================================
CREATE PROCEDURE [dbo].[TSK_RENTLYTICS_GeneralLedgerEntries]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS

DECLARE @accountID bigint
DECLARE @i int = 1
DECLARE @accountingBasis nvarchar(20)
DECLARE @accountingPeriodID uniqueidentifier
DECLARE @glAccountIDs GuidCollection
DECLARE @accountingBookIDs GuidCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	CREATE TABLE #GeneralTsosLedger (
		property_code nvarchar(500) not null,
		account_code nvarchar(50) null,
		name nvarchar(250) null,
		period date null,
		actual money null,
		budget money null)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		Name nvarchar(200) null,
		AccountingPeriodID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #BalancePeriod (
		PropertyID uniqueidentifier not null,
		GLAccountID uniqueidentifier not null,
		Number nvarchar(50) null,
		Name nvarchar(50) null,
		GLAccountType nvarchar(50) null,
		BeginningBalance money null,
		Amount money null)

	CREATE TABLE #AccountingPeriods (
		[Sequence] int identity,
		AccountingPeriodID uniqueidentifier not null,
		EndDate date not null)

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))
	SET @accountingBasis = (SELECT DefaultAccountingBasis FROM Settings WHERE AccountID = @accountID)
	INSERT @accountingBookIDs VALUES ('55555555-5555-5555-5555-555555555555')

	INSERT #AccountingPeriods
		SELECT TOP 3 AccountingPeriodID, EndDate
			FROM AccountingPeriod
			WHERE EndDate <= (SELECT EndDate
								  FROM AccountingPeriod
								  WHERE StartDate <= @date
								    AND EndDate >= @date
									AND AccountID = @accountID)
			  AND AccountID = @accountID
			ORDER BY EndDate DESC

	INSERT #PropertiesAndDates
		SELECT	pIDs.Value, p.Abbreviation, pap.AccountingPeriodID, pap.StartDate, pap.EndDate
			FROM @propertyIDs pIDs
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.StartDate <= @date AND pap.EndDate >= @date
				INNER JOIN Property p ON pIDs.Value = p.PropertyID

	INSERT #PropertiesAndDates
		SELECT	#pad.PropertyID,
				#pad.Name,
				[Other2].AccountingPeriodID,
				[Other2].StartDate,
				[Other2].EndDate
			FROM #PropertiesAndDates #pad
				INNER JOIN 
					(SELECT TOP 2 ap.AccountingPeriodID, ap.StartDate, ap.EndDate
						FROM AccountingPeriod ap
						WHERE ap.EndDate < @date
						ORDER BY ap.EndDate DESC) [Other2] ON 1 = 1
				
	WHILE (@i <= 3)
	BEGIN
		SET @accountingPeriodID = (SELECT AccountingPeriodID FROM #AccountingPeriods WHERE [Sequence] = @i)

		INSERT #BalancePeriod
			EXEC RPT_ACTG_TrialBalance @propertyIDs, @accountingBasis, null, null, null, 1, @accountingPeriodID, @glAccountIDs, @accountingBookIDs

		INSERT #GeneralTsosLedger
			SELECT	#pad.Name,
					#bp.Number,
					#bp.Name,
					pap.EndDate,
					ISNULL(#bp.Amount, 0),
					CASE
						WHEN (@accountingBasis = 'Cash') THEN ISNULL(bud.CashBudget, 0)
						ELSE ISNULL(bud.AccrualBudget, 0)
						END
				FROM #BalancePeriod #bp
					INNER JOIN #PropertiesAndDates #pad ON #bp.PropertyID = #pad.PropertyID AND #pad.AccountingPeriodID = @accountingPeriodID
					INNER JOIN PropertyAccountingPeriod pap ON #pad.PropertyID = pap.PropertyID AND #pad.AccountingPeriodID = pap.AccountingPeriodID
					LEFT JOIN Budget bud ON pap.PropertyAccountingPeriodID = bud.PropertyAccountingPeriodID AND #bp.GLAccountID = bud.GLAccountID					

		TRUNCATE TABLE #BalancePeriod
		SET @i = @i + 1
	END

	SELECT	DISTINCT
			property_code,
			account_code,
			name,
			CONVERT(varchar(10), period, 120) AS 'period',
			ISNULL(actual, 0.00) AS 'actual',
			ISNULL(budget, 0.00) AS 'budget'
		FROM #GeneralTsosLedger

END
GO
