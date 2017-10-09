SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Dec. 29, 2015
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_BSR_REOSchedule] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startDate datetime,
	@endDate datetime,
	@accountingPeriodID uniqueidentifier = null
AS

DECLARE @accountID bigint = 1070
DECLARE @propertyID uniqueidentifier

DECLARE @ctr int = 1
DECLARE @maxCtr int

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #REOSchedule (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(100) null,
		City nvarchar(50) null,
		[State] nvarchar(25) null,
		BSROwnershipPercentage decimal(7, 4) null,
		UnitCount int null,
		DateAcquired date null,
		LoanMaturity date null,
		LoanType nvarchar(20) null,
		InterestRate decimal(7, 4) null,
		YearBuilt nvarchar(10) null,
		PropertyRevenues money null,
		OperatingExpenses money null,
		AnnualDebtService money null,
		Lender nvarchar(500) null,
		TypeOfLoan nvarchar(500) null,
		MonthlyReserveRequirement money null,
		ReserveDeposits money null,
		LoanBalance money null,
		Occupancy decimal(7, 4) null)

	CREATE TABLE #LeasesAndUnits (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(50) null,
		OccupiedUnitLeaseGroupID uniqueidentifier null,
		OccupiedLastLeaseID uniqueidentifier null,
		OccupiedMoveInDate date null,
		OccupiedNTVDate date null,
		OccupiedMoveOutDate date null,
		OccupiedIsMovedOut bit null,
		PendingUnitLeaseGroupID uniqueidentifier null,
		PendingLeaseID uniqueidentifier null,
		PendingApplicationDate date null,
		PendingMoveInDate date null)

	CREATE TABLE #PropertiesAndDates (
		[Sequence] int identity,
		PropertyID uniqueidentifier not null,
		FiscalYearStartDate date null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #DebtServiceGLAccounts (
		GLAccountID uniqueidentifier not null)


	INSERT #PropertiesAndDates
		SELECT pIDs.Value, null, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	SET @accountID = (SELECT AccountID FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)

	--UPDATE #PropertiesAndDates SET FiscalYearStartDate = dbo.GetFiscalYearStartDate(@accountID, @accountingPeriodID, PropertyID)

	INSERT #DebtServiceGLAccounts
		SELECT GLAccountID
			FROM GLAccount
			WHERE Number IN ('6820', '6821', '6823', '6835', '6850', '6855', '2321', '2323', '6840', '6890')

	
	INSERT #REOSchedule
		SELECT	#pad.PropertyID,
				prop.Name,
				addr.City,
				addr.[State],
				(SELECT cfv.Value
					FROM CustomFieldValue cfv
						INNER JOIN CustomField cf ON cfv.CustomFieldID = cf.CustomFieldID AND cfv.ObjectID = prop.PropertyID AND cf.[Type] = 'Property' AND cf.Name = 'BSR Ownership Percentage'),
				null AS 'UnitCount',
				prop.DateAcquired,
				(SELECT cfv.Value
					FROM CustomFieldValue cfv
						INNER JOIN CustomField cf ON cfv.CustomFieldID = cf.CustomFieldID AND cfv.ObjectID = prop.PropertyID AND cf.[Type] = 'Property' AND cf.Name = 'Loan Maturity'),
				(SELECT cfv.Value
					FROM CustomFieldValue cfv
						INNER JOIN CustomField cf ON cfv.CustomFieldID = cf.CustomFieldID AND cfv.ObjectID = prop.PropertyID AND cf.[Type] = 'Property' AND cf.Name = 'Loan Type'),
				(SELECT cfv.Value
					FROM CustomFieldValue cfv
						INNER JOIN CustomField cf ON cfv.CustomFieldID = cf.CustomFieldID AND cfv.ObjectID = prop.PropertyID AND cf.[Type] = 'Property' AND cf.Name = 'Interest Rate'),
				prop.YearBuilt,
				null AS 'PropertyRevenues',
				null AS 'OperatingExpenses',
				null AS 'AnnualDebtService',
				(SELECT cfv.Value
					FROM CustomFieldValue cfv
						INNER JOIN CustomField cf ON cfv.CustomFieldID = cf.CustomFieldID AND cfv.ObjectID = prop.PropertyID AND cf.[Type] = 'Property' AND cf.Name = 'Lender'),
				(SELECT cfv.Value
					FROM CustomFieldValue cfv
						INNER JOIN CustomField cf ON cfv.CustomFieldID = cf.CustomFieldID AND cfv.ObjectID = prop.PropertyID AND cf.[Type] = 'Property' AND cf.Name = 'Type of Loan'),
				(SELECT cfv.Value
					FROM CustomFieldValue cfv
						INNER JOIN CustomField cf ON cfv.CustomFieldID = cf.CustomFieldID AND cfv.ObjectID = prop.PropertyID AND cf.[Type] = 'Property' AND cf.Name = 'Monthly Reserve Requirement'),
				null AS 'ReserveDeposits',
				null AS 'LoanBalance',
				null AS 'Occupancy'
			FROM #PropertiesAndDates #pad
				INNER JOIN Property prop ON #pad.PropertyID = prop.PropertyID
				INNER JOIN [Address] addr ON prop.AddressID = addr.AddressID

	-- Since "Income" accounts credit based accounts, we negate the amount in the sum, so that we have a positive number.
	UPDATE #REOSchedule SET PropertyRevenues = (SELECT SUM(-je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
														INNER JOIN GLAccount gla ON je.GLAccountID = gla.GLAccountID AND gla.GLAccountType = 'Income'
													WHERE je.AccountingBasis = 'Accrual'
													  AND t.TransactionDate >= #pad.StartDate
													  --AND t.TransactionDate >= #pad.FiscalYearStartDate
													  AND t.TransactionDate <= #pad.EndDate
													  AND t.Origin NOT IN ('Y', 'E')
													  AND je.AccountingBookID IS NULL
													  AND t.PropertyID = #REOSchedule.PropertyID)

	UPDATE #REOSchedule SET OperatingExpenses = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
														INNER JOIN GLAccount gla ON je.GLAccountID = gla.GLAccountID AND gla.GLAccountType = 'Expense'
													WHERE je.AccountingBasis = 'Accrual'
													  --AND t.TransactionDate >= #pad.FiscalYearStartDate
													  AND t.TransactionDate >= #pad.StartDate
													  AND t.TransactionDate <= #pad.EndDate
													  AND t.Origin NOT IN ('Y', 'E')
													  AND je.AccountingBookID IS NULL
													  AND t.PropertyID = #REOSchedule.PropertyID)

	UPDATE #REOSchedule SET AnnualDebtService = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
														INNER JOIN #DebtServiceGLAccounts #dsgla ON je.GLAccountID = #dsgla.GLAccountID
													WHERE je.AccountingBasis = 'Accrual'

													  --AND t.TransactionDate >= #pad.FiscalYearStartDate
													  AND t.TransactionDate >= #pad.StartDate
													  AND t.TransactionDate <= #pad.EndDate
													  AND je.AccountingBookID IS NULL
													  AND t.PropertyID = #REOSchedule.PropertyID)

	CREATE TABLE #TempGLAccountIDs (
		GLAccountID uniqueidentifier not null)

	INSERT INTO #TempGLAccountIDs
		SELECT GLAccountID FROM GLAccount WHERE Number = '1320'
		UNION
		SELECT GLAccountID FROM GLAccount WHERE ParentGLAccountID IN (SELECT GLAccountID FROM GLAccount WHERE Number = '1320')

	UPDATE #REOSchedule SET ReserveDeposits = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
														--INNER JOIN GLAccount gla ON je.GLAccountID = gla.GLAccountID AND gla.Number = '1320'
														INNER JOIN #TempGLAccountIDs #glIDs ON #glIDs.GLaccountID = je.GLAccountID
													WHERE je.AccountingBasis = 'Accrual'
													  --AND t.TransactionDate >= #pad.FiscalYearStartDate

													  AND t.TransactionDate <= #pad.EndDate
													  AND je.AccountingBookID IS NULL
													  AND t.PropertyID = #REOSchedule.PropertyID)

	DELETE FROM #TempGLAccountIDs
	
	INSERT INTO #TempGLAccountIDs
		SELECT GLAccountID FROM GLAccount WHERE Number = '2320'
		UNION
		SELECT GLAccountID FROM GLAccount WHERE ParentGLAccountID IN (SELECT GLAccountID FROM GLAccount WHERE Number = '2320')

	UPDATE #REOSchedule SET LoanBalance = (SELECT SUM(-je.Amount)
											  FROM JournalEntry je
												  INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
												  INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
												  INNER JOIN #TempGLAccountIDs #glIDs ON #glIDs.GLaccountID = je.GLAccountID
											  WHERE je.AccountingBasis = 'Accrual'
												--AND t.TransactionDate >= #pad.FiscalYearStartDate
												AND t.TransactionDate <= #pad.EndDate
												AND je.AccountingBookID IS NULL
												AND t.PropertyID = #REOSchedule.PropertyID)

	--SET @maxCtr = (SELECT MAX(Sequence) FROM #PropertiesAndDates)

	--WHILE (@ctr <= @maxCtr)
	--BEGIN
	--	SELECT @propertyID = PropertyID, @endDate = EndDate FROM #PropertiesAndDates WHERE [Sequence] = @ctr
		INSERT #LeasesAndUnits
			EXEC GetConsolodatedOccupancyNumbers 1070, @endDate, @accountingPeriodID, @propertyIDs

	--	SET @ctr = @ctr + 1
	--END

	UPDATE #REOSchedule SET UnitCount = (SELECT COUNT(DISTINCT #lau.UnitID)
											FROM #LeasesAndUnits #lau
											WHERE #lau.PropertyID = #REOSchedule.PropertyID)

	UPDATE #REOSchedule SET Occupancy = (SELECT CAST(COUNT(DISTINCT #lau.UnitID) AS decimal(7, 4))
											FROM #LeasesAndUnits #lau
											WHERE #lau.PropertyID = #REOSchedule.PropertyID
											  AND #lau.OccupiedUnitLeaseGroupID IS NULL)

	UPDATE #REOSchedule SET Occupancy = 100 * ((CAST(UnitCount AS decimal(7, 4)) - Occupancy)/CAST(UnitCount AS decimal(7, 4)))
	WHERE UnitCount <> 0

	SELECT * FROM #REOSchedule

END






GO
