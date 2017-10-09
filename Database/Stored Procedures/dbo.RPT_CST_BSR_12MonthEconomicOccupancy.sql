SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO







-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Nov. 23, 2015
-- Description:	12 month economic occupancy report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_BSR_12MonthEconomicOccupancy] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null
AS

DECLARE @accountID bigint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Portfolio (
		PropertyID uniqueidentifier null,
		RegionalManagerPersonID uniqueidentifier null,
		RegionalManagerName nvarchar(100) null,
		UnitCount int null)

	CREATE TABLE #TheNumbers (
		PropertyID uniqueidentifier null,
		AccountingPeriodSequence int null,
		MonthXNumerator money null,
		MonthXDenominator money null)

	CREATE TABLE #OrderedAccountingPeriods (
		[Sequence] int identity,
		AccountingPeriodID uniqueidentifier null)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier null,
		PeriodNumber int null,
		PropertyAccountingPeriodID uniqueidentifier null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #NumeratorGLAccounts (
		GLAccountID uniqueidentifier null,
		Number nvarchar(50) null)

	INSERT #NumeratorGLAccounts
		SELECT gla.GLAccountID, gla.Number
			FROM GLAccount gla
				INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID AND gla.AccountID = ap.AccountID
			WHERE Number IN ('5115', '5125', '5220', '5234', '5240', '5245', '5250', '6320', '6321')

	INSERT #OrderedAccountingPeriods
		SELECT TOP 12 AccountingPeriodID
			FROM 
				(SELECT TOP 12 AccountingPeriodID, EndDate	
					FROM AccountingPeriod
					WHERE EndDate <= (SELECT EndDate 
										FROM AccountingPeriod
										WHERE AccountingPeriodID = @accountingPeriodID)
					ORDER BY EndDate DESC) AS [MyPeriods]
			ORDER BY EndDate

	INSERT #PropertiesAndDates
		SELECT pap.PropertyID, #oaps.[Sequence], pap.PropertyAccountingPeriodID, pap.StartDate, pap.EndDate
			FROM @propertyIDs pIDs 
				INNER JOIN PropertyAccountingPeriod pap	ON pIDs.Value = pap.PropertyID
				INNER JOIN #OrderedAccountingPeriods #oaps ON #oaps.AccountingPeriodID = pap.AccountingPeriodID

	INSERT #TheNumbers
		SELECT PropertyID, PeriodNumber, null, null
			FROM #PropertiesAndDates

	INSERT #Portfolio
		SELECT pIDs.Value, per.PersonID, per.PreferredName + ' ' + per.LastName, null 
			FROM @propertyIDs pIDs
				INNER JOIN Property prop ON pIDs.Value = prop.PropertyID
				INNER JOIN Person per ON prop.RegionalManagerPersonID = per.PersonID

	UPDATE #Portfolio SET UnitCount = (SELECT COUNT(u.UnitID)
											FROM Unit u
												INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
											WHERE #Portfolio.PropertyID = ut.PropertyID
											  AND u.ExcludedFromOccupancy = 0
											  AND u.DateRemoved IS NULL)
											  
	UPDATE #TheNumbers SET MonthXNumerator = (SELECT SUM(-je.Amount)


												  FROM JournalEntry je
													  INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													  INNER JOIN #NumeratorGLAccounts #nGLAs ON je.GLAccountID = #nGLAs.GLAccountID
													  INNER JOIN GLAccount gla ON #nGLAs.GLAccountID = gla.GLAccountID
													  INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate


												  WHERE je.AccountingBasis = 'Accrual'
													AND t.Origin NOT IN ('Y', 'E')
													AND je.AccountingBookID IS NULL
												    AND #TheNumbers.PropertyID = #pad.PropertyID
												    AND #TheNumbers.AccountingPeriodSequence = #pad.PeriodNumber)

	UPDATE #TheNumbers SET MonthXDenominator = (SELECT SUM(-je.Amount)


													  FROM JournalEntry je
														  INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														  INNER JOIN #NumeratorGLAccounts #nGLAs ON je.GLAccountID = #nGLAs.GLAccountID AND #nGLAs.Number IN ('5115')
														  INNER JOIN GLAccount gla ON #nGLAs.GLAccountID = gla.GLAccountID
														  INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate


													  WHERE je.AccountingBasis = 'Accrual'
														AND t.Origin NOT IN ('Y', 'E')
														AND je.AccountingBookID IS NULL
														AND #TheNumbers.PropertyID = #pad.PropertyID
														AND #TheNumbers.AccountingPeriodSequence = #pad.PeriodNumber)

	SELECT	DISTINCT
			#port.PropertyID,
			prop.Name AS 'PropertyName',
			#port.RegionalManagerPersonID AS 'RegionalManagerPersonID',
			#port.RegionalManagerName AS 'RegionalManagerName',
			#port.UnitCount,
			(SELECT MonthXNumerator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 1) AS 'Month1Numerator',
			(SELECT MonthXNumerator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 2) AS 'Month2Numerator',
			(SELECT MonthXNumerator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 3) AS 'Month3Numerator',
			(SELECT MonthXNumerator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 4) AS 'Month4Numerator',
			(SELECT MonthXNumerator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 5) AS 'Month5Numerator',
			(SELECT MonthXNumerator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 6) AS 'Month6Numerator',
			(SELECT MonthXNumerator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 7) AS 'Month7Numerator',
			(SELECT MonthXNumerator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 8) AS 'Month8Numerator',
			(SELECT MonthXNumerator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 9) AS 'Month9Numerator',
			(SELECT MonthXNumerator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 10) AS 'Month10Numerator',
			(SELECT MonthXNumerator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 11) AS 'Month11Numerator',
			(SELECT MonthXNumerator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 12) AS 'Month12Numerator',
			(SELECT MonthXDenominator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 1) AS 'Month1Denominator',
			(SELECT MonthXDenominator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 2) AS 'Month2Denominator',
			(SELECT MonthXDenominator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 3) AS 'Month3Denominator',
			(SELECT MonthXDenominator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 4) AS 'Month4Denominator',
			(SELECT MonthXDenominator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 5) AS 'Month5Denominator',
			(SELECT MonthXDenominator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 6) AS 'Month6Denominator',
			(SELECT MonthXDenominator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 7) AS 'Month7Denominator',
			(SELECT MonthXDenominator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 8) AS 'Month8Denominator',
			(SELECT MonthXDenominator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 9) AS 'Month9Denominator',
			(SELECT MonthXDenominator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 10) AS 'Month10Denominator',
			(SELECT MonthXDenominator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 11) AS 'Month11Denominator',
			(SELECT MonthXDenominator FROM #TheNumbers WHERE PropertyID = #port.PropertyID AND AccountingPeriodSequence = 12) AS 'Month12Denominator'
		FROM #Portfolio #port
			INNER JOIN Property prop ON #port.PropertyID = prop.PropertyID
			INNER JOIN #TheNumbers #tn ON #port.PropertyID = #tn.PropertyID



END

GO
