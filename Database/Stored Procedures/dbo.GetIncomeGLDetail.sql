SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 2, 2014
-- Description:	Gets the GL expense detail
-- =============================================
CREATE PROCEDURE [dbo].[GetIncomeGLDetail] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@glAccountIDs GuidCollection READONLY,
	@accountingBasis nvarchar(50) = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Currently a hack but we are only ever calling this with a single PropertyID
	DECLARE @propertyID uniqueidentifier = (SELECT TOP 1 Value FROM @propertyIDs)

	CREATE TABLE #GLExpenseDetail (
		GLExpenseDetailID uniqueidentifier not null,
		PropertyID uniqueidentifier null,
		GLAccountID uniqueidentifier null,
		VendorID uniqueidentifier null,
		MonthSequence int null,
		MonthValue money null)		
		
	CREATE TABLE #MyProperties (
		PropertyID uniqueidentifier null)
		
	CREATE TABLE #MyGLAccounts (
		GLAccountID uniqueidentifier null)
		
	CREATE TABLE #MyAccountingPeriods (
		Sequence int identity,
		AccountingPeriodID uniqueidentifier not null,
		StartDate date not null,
		EndDate date not null)

	DECLARE @endDateByACPeriod date = (SELECT EndDate FROM PropertyAccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID AND PropertyID = @propertyID)
	DECLARE @startMonth int = (SELECT DATEPART(MONTH, @endDateByACPeriod))
	DECLARE @startYear int = (SELECT DATEPART(YEAR, @endDateByACPeriod))
	IF (@startMonth = 12)
	BEGIN
		SET @startMonth = 1
		SET @startYear = @startYear + 1				-- This makes the math work when we set startDate a couple of lines later
	END
	ELSE
	BEGIN
		SET @startMonth = @startMonth + 1
	END
	
	DECLARE @startDate date = (SELECT TOP 1 StartDate 
								  FROM PropertyAccountingPeriod
								  WHERE DATEPART(MONTH, StartDate) = @startMonth
								    AND DATEPART(YEAR, StartDate) = @startYear - 1
									AND PropertyID = @propertyID
									AND AccountID = @accountID
								ORDER BY StartDate)
	--The query above may not find an accounting period if the accounting period we passed in does not have 12 accounting periods defined before it.
	-- In that case we will just find the first accounting period ever.
	IF(@startDate IS NULL)
	BEGIN
		SET @startDate = (SELECT TOP 1 StartDate
							 FROM PropertyAccountingPeriod
							 WHERE PropertyID = @propertyID
							   AND AccountID = @accountID
							 ORDER BY StartDate)

		DECLARE @periodsMissingCount int = 12 - (SELECT COUNT(*)
													FROM PropertyAccountingPeriod
													WHERE StartDate >= @startDate
													  AND EndDate <= @endDateByACPeriod
													  AND AccountID = @accountID
													  AND PropertyID = @propertyID)

		--Doesn't matter what the dates are for the undefined accounting periods, as long as the dates are before the start date of the first period.
		--There cannot be any transactions before that date anyways.
		DECLARE @undefinedAccountingPeriodDate date = DATEADD(YEAR, -1, @startDate)

		WHILE (@periodsMissingCount > 0)
		BEGIN
			INSERT #MyAccountingPeriods (AccountingPeriodID, StartDate, EndDate)
				VALUES ('00000000-0000-0000-0000-000000000000', @undefinedAccountingPeriodDate, @undefinedAccountingPeriodDate)

			SET @periodsMissingCount = @periodsMissingCount - 1
		END
	END
								  
	INSERT #MyAccountingPeriods 
		SELECT AccountingPeriodID, StartDate, EndDate
			FROM PropertyAccountingPeriod
			WHERE StartDate >= @startDate
			  AND EndDate <= @endDateByACPeriod
			  AND AccountID = @accountID
			  AND PropertyID = @propertyID
			ORDER BY StartDate

	INSERT #MyProperties SELECT Value FROM @propertyIDs
	
	IF (0 < (SELECT COUNT(*) FROM @glAccountIDs))
	BEGIN
		INSERT #MyGLAccounts SELECT Value FROM @glAccountIDs
	END
	ELSE
	BEGIN
		INSERT #MyGLAccounts SELECT GLAccountID FROM GLAccount WHERE AccountID = @accountID
	END

	
	INSERT #GLExpenseDetail
		SELECT	NEWID(), #myP.PropertyID, #myGLA.GLAccountID, null, #myAP.Sequence, 0.00
			FROM #MyProperties #myP
				INNER JOIN #MyGLAccounts #myGLA ON 1=1
				--INNER JOIN #MyVendors #myV ON 1=1
				INNER JOIN #MyAccountingPeriods #myAP ON 1=1
		
						
	-- Get non-invoice and non-payment													
	UPDATE #GLExpenseDetail SET MonthValue = ISNULL(MonthValue, 0) + ISNULL((SELECT ISNULL(-SUM(je.Amount), 0)
																			FROM #GLExpenseDetail #gled
																				INNER JOIN #MyAccountingPeriods #myAP ON #gled.MonthSequence = #myAP.Sequence
																				INNER JOIN JournalEntry je ON #gled.GLAccountID = je.GLAccountID AND je.AccountingBasis = @accountingBasis
																				INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID AND #gled.PropertyID = t.PropertyID
																									AND t.TransactionDate >= #myAP.StartDate AND t.TransactionDate <= #myAP.EndDate
																												
																			WHERE 
																			  #gled.VendorID IS NULL
																			  AND #gled.GLExpenseDetailID = #GLExpenseDetail.GLExpenseDetailID
																			  AND t.Origin NOT IN ('Y', 'E')
																			  AND je.AccountingBookID IS NULL
																			GROUP BY #gled.GLExpenseDetailID), 0)
		WHERE VendorID IS NULL
		
	
	INSERT #GLExpenseDetail
		SELECT	NEWID(), pap.PropertyID, #myGLA.GLAccountID, 'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF', #myAP.Sequence, 
				CASE 
					WHEN (@accountingBasis = 'Accrual') THEN b.AccrualBudget
					ELSE b.CashBudget END
			FROM #MyGLAccounts #myGLA
				INNER JOIN Budget b ON #myGLA.GLAccountID = b.GLAccountID
				INNER JOIN PropertyAccountingPeriod pap ON b.PropertyAccountingPeriodID = pap.PropertyAccountingPeriodID
				INNER JOIN #MyAccountingPeriods #myAP ON pap.AccountingPeriodID = #myAP.AccountingPeriodID
				INNER JOIN #MyProperties #mp ON #mp.PropertyID = pap.PropertyID
		   
	SELECT	DISTINCT
			#gled.PropertyID AS 'PropertyID',
			#gled.GLAccountID AS 'GLAccountID',
			gla.Number AS 'GLAccountNumber',
			gla.GLAccountType AS 'GLAccountType',
			gla.Name AS 'GLAccountName',
			null AS 'VendorID',
			CASE 
				WHEN (#gled.VendorID IS NULL) THEN 'Other'
				WHEN (#gled.VendorID = 'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF') THEN 'Budget'
				ELSE '' END AS 'VendorName',
			CASE WHEN (#gled.MonthSequence = 1) THEN ISNULL(MonthValue, 0) ELSE 0 END AS 'Month1Amount',
			CASE WHEN (#gled.MonthSequence = 2) THEN ISNULL(MonthValue, 0) ELSE 0 END AS 'Month2Amount',
			CASE WHEN (#gled.MonthSequence = 3) THEN ISNULL(MonthValue, 0) ELSE 0 END AS 'Month3Amount',
			CASE WHEN (#gled.MonthSequence = 4) THEN ISNULL(MonthValue, 0) ELSE 0 END AS 'Month4Amount',
			CASE WHEN (#gled.MonthSequence = 5) THEN ISNULL(MonthValue, 0) ELSE 0 END AS 'Month5Amount',
			CASE WHEN (#gled.MonthSequence = 6) THEN ISNULL(MonthValue, 0) ELSE 0 END AS 'Month6Amount',
			CASE WHEN (#gled.MonthSequence = 7) THEN ISNULL(MonthValue, 0) ELSE 0 END AS 'Month7Amount',
			CASE WHEN (#gled.MonthSequence = 8) THEN ISNULL(MonthValue, 0) ELSE 0 END AS 'Month8Amount',
			CASE WHEN (#gled.MonthSequence = 9) THEN ISNULL(MonthValue, 0) ELSE 0 END AS 'Month9Amount',
			CASE WHEN (#gled.MonthSequence = 10) THEN ISNULL(MonthValue, 0) ELSE 0 END AS 'Month10Amount',
			CASE WHEN (#gled.MonthSequence = 11) THEN ISNULL(MonthValue, 0) ELSE 0 END AS 'Month11Amount',
			CASE WHEN (#gled.MonthSequence = 12) THEN ISNULL(MonthValue, 0) ELSE 0 END AS 'Month12Amount'
		FROM #GLExpenseDetail #gled
			INNER JOIN GLAccount gla ON #gled.GLAccountID = gla.GLAccountID
		WHERE ISNULL(MonthValue, 0) <> 0
		ORDER BY #gled.PropertyID, gla.Number

END



GO
