SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Nov. 15, 2016
-- Description:	Custom Report: Woodsmere - Project Alocation by Property
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_WHC_ProjectAllocationByYear]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startAccountingPeriodID uniqueidentifier = null,
	@endAccountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS

DECLARE @accountID bigint = 0

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Allocations (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(100) null,
		PeriodName nvarchar(50) null,
		PeriodStartDate date null,
		AccountingPeriodID uniqueidentifier null,
		UnitCount int null,
		Notes nvarchar(MAX) null,
		PropertyValue money null,
		MortgageBalance money null,
		RentalIncome money null,
		MiscIncome money null,
		MortgagePrinciple money null,
		MortgageInterest money null,
		PropertyTaxes money null,
		PropertyInsurance money null,
		ResidentManagerSalary money null,
		Advertising money null,
		OnSiteAdmin money null,
		RepairsAndMaintenance money null,
		UtilitiesAndGarbage money null,
		TotalExpenses money null,						-- Including Principal
		ProfitLost money null							-- Including Principal
		)

	CREATE TABLE #GLAccountMortgages (
		PropertyID uniqueidentifier not null,
		GLAccountID uniqueidentifier not null)

	CREATE TABLE #PropertiesAndDates1 (
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #GLAccountIDsAndTypes (
		GLAccountID uniqueidentifier not null,
		[Type] nvarchar(5) null)


	IF (@endAccountingPeriodID IS NOT NULL)
	BEGIN
		INSERT #PropertiesAndDates1 
			SELECT pIDs.Value, papS.StartDate, papE.EndDate
				FROM @propertyIDs pIDs
					INNER JOIN PropertyAccountingPeriod papE ON pIDs.Value = papE.PropertyID AND papE.AccountingPeriodID = @endAccountingPeriodID
					INNER JOIN PropertyAccountingPeriod papS On pIDs.Value = papS.PropertyID AND papS.AccountingPeriodID = @startAccountingPeriodID
		--SET @accountID = (SELECT TOP 1 PropertyID FROM #PropertiesAndDates1)
		--UPDATE #PropertiesAndDates1 SET StartDate = (SELECT dbo.GetFiscalYearStartDate(@accountID, @accountingPeriodID, #PropertiesAndDates1.PropertyID))
	END
	ELSE
	BEGIN
		INSERT #PropertiesAndDates1
			SELECT pIDs.Value, @startDate, @endDate
				FROM @propertyIDs pIDs
	END

	INSERT #PropertiesAndDates
		SELECT	#pad1.PropertyID, pap.AccountingPeriodID, pap.StartDate, pap.EndDate
			FROM #PropertiesAndDates1 #pad1
				INNER JOIN PropertyAccountingPeriod pap ON #pad1.PropertyID = pap.PropertyID
			WHERE pap.StartDate < #pad1.EndDate
			  AND pap.EndDate > #pad1.StartDate

	--INSERT #PropertiesAndDates
	--	SELECT pIDs.Value, null, null, null
	--		FROM @propertyIDs pIDs

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT PropertyID FROM #PropertiesAndDates1))

	INSERT #GLAccountIDsAndTypes
		SELECT GLAccountID, 'RentI'	
			FROM GLAccount
			WHERE Number IN ('40100', '40110', '40120')
			  AND AccountID = @accountID

	INSERT #GLAccountIDsAndTypes
		SELECT GLAccountID, 'MiscI'
			FROM GLAccount
			WHERE Number IN ('40500', '40510', '40520', '40530', '40540', '40550', '42000', '41010' , '41000')
			  AND AccountID = @accountID

	--INSERT #GLAccountIDsAndTypes
	--	SELECT GLAccountID, 'MortP'
	--		FROM GLAccount
	--		WHERE Number IN ('26010', '26200')
	--		  AND AccountID = @accountID

	INSERT #GLAccountIDsAndTypes
		SELECT GLAccountID, 'MortI'
			FROM GLAccount
			WHERE Number IN ('50900')
			  AND AccountID = @accountID

	INSERT #GLAccountIDsAndTypes
		SELECT GLAccountID, 'PrpTx'
			FROM GLAccount
			WHERE Number IN ('50100')
			  AND AccountID = @accountID

	INSERT #GLAccountIDsAndTypes
		SELECT GLAccountID, 'PrpIn'
			FROM GLAccount
			WHERE Number IN ('50200')
			  AND AccountID = @accountID

	INSERT #GLAccountIDsAndTypes
		SELECT GLAccountID, 'Mngr$'
			FROM GLAccount
			WHERE ParentGLAccountID = (SELECT GLAccountID
										   FROM GLAccount
										   WHERE Number = '53000'
										     AND AccountID = @accountID)

	INSERT #GLAccountIDsAndTypes
		SELECT GLAccountID, 'AdVer'
			FROM GLAccount
			WHERE ParentGLAccountID = (SELECT GLAccountID
										   FROM GLAccount
										   WHERE Number = '54000'
										     AND AccountID = @accountID)

	INSERT #GLAccountIDsAndTypes
		SELECT GLAccountID, 'OSAdm'
			FROM GLAccount
			WHERE ParentGLAccountID = (SELECT GLAccountID
										   FROM GLAccount
										   WHERE Number = '55000'
										     AND AccountID = @accountID)

	INSERT #GLAccountIDsAndTypes
		SELECT GLAccountID, 'RepMn'
			FROM GLAccount
			WHERE ParentGLAccountID = (SELECT GLAccountID
										   FROM GLAccount
										   WHERE Number = '56000'
										     AND AccountID = @accountID)

	INSERT #GLAccountIDsAndTypes
		SELECT GLAccountID, 'UtGar'
			FROM GLAccount
			WHERE ParentGLAccountID = (SELECT GLAccountID
										   FROM GLAccount
										   WHERE Number = '58000'
										     AND AccountID = @accountID)

	-- Bridgewood Apts.
	INSERT #GLAccountMortgages
		SELECT 'd27e46be-b29b-4c4b-be06-3fd8a341a8cc', GLAccountID
			FROM GLAccount
			WHERE Number IN ('26010')
			  AND AccountID = @accountID

	-- Britnell Place
	INSERT #GLAccountMortgages
		SELECT 'f7fe58f9-18c9-4690-b32a-2ced25482b90', GLAccountID
			FROM GLAccount
			WHERE Number IN ('26140')
			  AND AccountID = @accountID

	-- Clarewood Apts.
	INSERT #GLAccountMortgages
		SELECT '087a9636-7a76-4ab2-ab81-04a186d03a97', GLAccountID
			FROM GLAccount
			WHERE Number IN ('26030')
			  AND AccountID = @accountID

	-- Cresent Heights Manor
	INSERT #GLAccountMortgages
		SELECT '48dfe0ea-06de-457f-aada-fad457f32546', GLAccountID
			FROM GLAccount
			WHERE Number IN ('26025')
			  AND AccountID = @accountID

	-- Gateway Apts.
	INSERT #GLAccountMortgages
		SELECT '9f6b06ae-49fe-4ca4-a60b-c4d69d21be62', GLAccountID
			FROM GLAccount
			WHERE Number IN ('26040')
			  AND AccountID = @accountID

	-- Lakewood Apts.
	INSERT #GLAccountMortgages
		SELECT '7b997996-167c-40e9-aceb-fc65d396aebb', GLAccountID
			FROM GLAccount
			WHERE Number IN ('26050', '26060')
			  AND AccountID = @accountID

	-- Mission Heights Manor
	INSERT #GLAccountMortgages
		SELECT '06408235-d258-4940-8b35-e54e526e0173', GLAccountID
			FROM GLAccount
			WHERE Number IN ('26070')
			  AND AccountID = @accountID

	-- Woodsmere Close
	INSERT #GLAccountMortgages
		SELECT '814bb767-de17-40ad-a4b6-e2e5267a2211', GLAccountID
			FROM GLAccount
			WHERE Number IN ('26085')
			  AND AccountID = @accountID

	-- Woodsmere Manor
	INSERT #GLAccountMortgages
		SELECT '3ff853b7-5fb6-4985-a444-dd3859f5a24e', GLAccountID
			FROM GLAccount
			WHERE Number IN ('26090', '26100')
			  AND AccountID = @accountID

	-- Woodsmere Park
	INSERT #GLAccountMortgages
		SELECT '58b7020b-4afb-4442-b4cd-96a385ba0e34', GLAccountID
			FROM GLAccount
			WHERE Number IN ('26110')
			  AND AccountID = @accountID

	-- Woodsmere Place
	INSERT #GLAccountMortgages
		SELECT '6c3dc6f6-0712-459c-9300-61a7b51fab7c', GLAccountID
			FROM GLAccount
			WHERE Number IN ('26120', '26130')
			  AND AccountID = @accountID

	INSERT #Allocations
		SELECT	#pad.PropertyID,
				p.Name,
				ap.Name,
				ap.StartDate,
				ap.AccountingPeriodID,
				null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null					-- 17 nulls
			FROM #PropertiesAndDates #pad
				INNER JOIN Property p ON #pad.PropertyID = p.PropertyID
				INNER JOIN AccountingPeriod ap ON #pad.AccountingPeriodID = ap.AccountingPeriodID

	UPDATE #Allocations SET UnitCount = (SELECT COUNT(DISTINCT u.UnitID)
											 FROM Unit u
												 INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
												 INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
											 WHERE ut.PropertyID = #Allocations.PropertyID
											   AND u.IsHoldingUnit = 0
											   AND (u.DateRemoved IS NULL OR u.DateRemoved > #pad.EndDate))

	UPDATE #Allocations SET MortgageBalance = (SELECT SUM(-je.Amount)
												   FROM JournalEntry je
													   INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													   INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
																AND t.TransactionDate <= #pad.EndDate
													   INNER JOIN #GLAccountMortgages #glam ON je.GLAccountID = #glam.GLAccountID AND t.PropertyID = #glam.PropertyID
													   INNER JOIN Settings s ON t.AccountID = s.AccountID
												   WHERE t.PropertyID = #Allocations.PropertyID
												     AND #pad.AccountingPeriodID = #Allocations.AccountingPeriodID
													 AND t.Origin NOT IN ('Y', 'E')
													 AND je.AccountingBookID IS NULL
												     AND je.AccountingBasis = s.DefaultAccountingBasis)

	UPDATE #Allocations SET RentalIncome = (SELECT SUM(-je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													INNER JOIN Settings s ON t.AccountID = s.AccountID
													INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																		AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
													INNER JOIN #GLAccountIDsAndTypes #glaTypes ON je.GLAccountID = #glaTypes.GLAccountID AND #glaTypes.[Type] = 'RentI'
												WHERE t.PropertyID = #Allocations.PropertyID
												  AND #pad.AccountingPeriodID = #Allocations.AccountingPeriodID
												  AND t.Origin NOT IN ('Y', 'E')
												  AND je.AccountingBookID IS NULL
												  AND je.AccountingBasis = s.DefaultAccountingBasis)

	UPDATE #Allocations SET MiscIncome = (SELECT SUM(-je.Amount)
											FROM JournalEntry je
												INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
												INNER JOIN Settings s ON t.AccountID = s.AccountID
												INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																	AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
												INNER JOIN #GLAccountIDsAndTypes #glaTypes ON je.GLAccountID = #glaTypes.GLAccountID AND #glaTypes.[Type] = 'MiscI'
											WHERE t.PropertyID = #Allocations.PropertyID
											  AND #pad.AccountingPeriodID = #Allocations.AccountingPeriodID
											  AND t.Origin NOT IN ('Y', 'E')
											  AND je.AccountingBookID IS NULL
											  AND je.AccountingBasis = s.DefaultAccountingBasis)

	UPDATE #Allocations SET MortgagePrinciple = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN Settings s ON t.AccountID = s.AccountID
														INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																			AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
														INNER JOIN #GLAccountMortgages #GLAAM ON je.GLAccountID = #GLAAM.GLAccountID AND t.PropertyID = #GLAAM.PropertyID
													WHERE t.PropertyID = #Allocations.PropertyID
													  AND t.Origin NOT IN ('Y', 'E')
													  AND je.Amount > 0
													  AND t.Description NOT LIKE '%Reverse%' -- Don't include reversing entries from conversion
													  AND je.AccountingBookID IS NULL
													  AND #pad.AccountingPeriodID = #Allocations.AccountingPeriodID
													  AND je.AccountingBasis = s.DefaultAccountingBasis)

	UPDATE #Allocations SET MortgageInterest = (SELECT SUM(je.Amount)
													FROM JournalEntry je
														INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
														INNER JOIN Settings s ON t.AccountID = s.AccountID
														INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																			AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
														INNER JOIN #GLAccountIDsAndTypes #glaTypes ON je.GLAccountID = #glaTypes.GLAccountID AND #glaTypes.[Type] = 'MortI'
													WHERE t.PropertyID = #Allocations.PropertyID
													  AND t.Origin NOT IN ('Y', 'E')
													  AND je.AccountingBookID IS NULL
													  AND #pad.AccountingPeriodID = #Allocations.AccountingPeriodID
													  AND je.AccountingBasis = s.DefaultAccountingBasis)

	UPDATE #Allocations SET PropertyTaxes = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													INNER JOIN Settings s ON t.AccountID = s.AccountID
													INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																		AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
													INNER JOIN #GLAccountIDsAndTypes #glaTypes ON je.GLAccountID = #glaTypes.GLAccountID AND #glaTypes.[Type] = 'PrpTx'
												WHERE t.PropertyID = #Allocations.PropertyID
												  AND t.Origin NOT IN ('Y', 'E')
												  AND je.AccountingBookID IS NULL
												  AND #pad.AccountingPeriodID = #Allocations.AccountingPeriodID
												  AND je.AccountingBasis = s.DefaultAccountingBasis)

	UPDATE #Allocations SET PropertyInsurance = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													INNER JOIN Settings s ON t.AccountID = s.AccountID
													INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																		AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
													INNER JOIN #GLAccountIDsAndTypes #glaTypes ON je.GLAccountID = #glaTypes.GLAccountID AND #glaTypes.[Type] = 'PrpIn'
												WHERE #pad.PropertyID = #Allocations.PropertyID
												  AND t.Origin NOT IN ('Y', 'E')
												  AND je.AccountingBookID IS NULL
												  AND #pad.AccountingPeriodID = #Allocations.AccountingPeriodID
												  AND je.AccountingBasis = s.DefaultAccountingBasis)

	UPDATE #Allocations SET ResidentManagerSalary = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN Settings s ON t.AccountID = s.AccountID
															INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																				AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
															INNER JOIN #GLAccountIDsAndTypes #glaTypes ON je.GLAccountID = #glaTypes.GLAccountID AND #glaTypes.[Type] = 'Mngr$'
														WHERE t.PropertyID = #Allocations.PropertyID
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND #pad.AccountingPeriodID = #Allocations.AccountingPeriodID
														  AND je.AccountingBasis = s.DefaultAccountingBasis)

	UPDATE #Allocations SET Advertising = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													INNER JOIN Settings s ON t.AccountID = s.AccountID
													INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																		AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
													INNER JOIN #GLAccountIDsAndTypes #glaTypes ON je.GLAccountID = #glaTypes.GLAccountID AND #glaTypes.[Type] = 'AdVer'
												WHERE t.PropertyID = #Allocations.PropertyID
												  AND t.Origin NOT IN ('Y', 'E')
												  AND je.AccountingBookID IS NULL
												  AND #pad.AccountingPeriodID = #Allocations.AccountingPeriodID
												  AND je.AccountingBasis = s.DefaultAccountingBasis)

	UPDATE #Allocations SET OnSiteAdmin = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													INNER JOIN Settings s ON t.AccountID = s.AccountID
													INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																		AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
													INNER JOIN #GLAccountIDsAndTypes #glaTypes ON je.GLAccountID = #glaTypes.GLAccountID AND #glaTypes.[Type] = 'OsAdm'
												WHERE t.PropertyID = #Allocations.PropertyID
												  AND t.Origin NOT IN ('Y', 'E')
												  AND je.AccountingBookID IS NULL
												  AND #pad.AccountingPeriodID = #Allocations.AccountingPeriodID
												  AND je.AccountingBasis = s.DefaultAccountingBasis)

	UPDATE #Allocations SET RepairsAndMaintenance = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN Settings s ON t.AccountID = s.AccountID
															INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																				AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
															INNER JOIN #GLAccountIDsAndTypes #glaTypes ON je.GLAccountID = #glaTypes.GLAccountID AND #glaTypes.[Type] = 'RepMn'
														WHERE t.PropertyID = #Allocations.PropertyID
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND #pad.AccountingPeriodID = #Allocations.AccountingPeriodID
														  AND je.AccountingBasis = s.DefaultAccountingBasis)

	UPDATE #Allocations SET UtilitiesAndGarbage = (SELECT SUM(je.Amount)
														FROM JournalEntry je
															INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
															INNER JOIN Settings s ON t.AccountID = s.AccountID
															INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																				AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
															INNER JOIN #GLAccountIDsAndTypes #glaTypes ON je.GLAccountID = #glaTypes.GLAccountID AND #glaTypes.[Type] = 'UtGar'
														WHERE t.PropertyID = #Allocations.PropertyID
														  AND t.Origin NOT IN ('Y', 'E')
														  AND je.AccountingBookID IS NULL
														  AND #pad.AccountingPeriodID = #Allocations.AccountingPeriodID
														  AND je.AccountingBasis = s.DefaultAccountingBasis)

	UPDATE #Allocations SET PropertyValue = (SELECT CAST(cfv.Value AS money)
												 FROM CustomFieldProperty cfp
													 INNER JOIN CustomFieldValue cfv ON cfp.CustomFieldID = cfv.CustomFieldID AND cfv.ObjectID = cfp.PropertyID
													 INNER JOIN CustomField cf ON cfp.CustomFieldID = cf.CustomFieldID 
												 WHERE cf.Name = 'Property Values'
												   AND cfp.PropertyID = #Allocations.PropertyID)

	UPDATE #Allocations SET Notes = (SELECT cfv.Value
										 FROM CustomFieldProperty cfp
											 INNER JOIN CustomFieldValue cfv ON cfp.CustomFieldID = cfv.CustomFieldID AND cfv.ObjectID = cfp.PropertyID
											 INNER JOIN CustomField cf ON cfp.CustomFieldID = cf.CustomFieldID 
										 WHERE cf.Name = 'Project Allocation Notes'
										   AND cfp.PropertyID = #Allocations.PropertyID)

	SELECT	PropertyID,
			PropertyName,
			PeriodName,
			PeriodStartDate,
			AccountingPeriodID,
			UnitCount,
			Notes,
			ISNULL(PropertyValue, 0.00) AS 'PropertyValue',
			ISNULL(MortgageBalance, 0.00) AS 'MortgageBalance',
			ISNULL(RentalIncome, 0.00) AS 'RentalIncome',
			ISNULL(MiscIncome, 0.00) AS 'MiscIncome',
			ISNULL(MortgagePrinciple, 0.00) AS 'MortgagePrinciple',
			ISNULL(MortgageInterest, 0.00) AS 'MortgageInterest',
			ISNULL(PropertyTaxes, 0.00) AS 'PropertyTaxes',
			ISNULL(PropertyInsurance, 0.00) AS 'PropertyInsurance',
			ISNULL(ResidentManagerSalary, 0.00) AS 'ResidentManagerSalary',
			ISNULL(Advertising, 0.00) AS 'Advertising',
			ISNULL(OnSiteAdmin, 0.00) AS 'OnSiteAdmin',
			ISNULL(RepairsAndMaintenance, 0.00) AS 'RepairsAndMaintenance',
			ISNULL(UtilitiesAndGarbage, 0.00) AS 'UtilitiesAndGarbage',
			ISNULL(TotalExpenses, 0.00) AS 'TotalExpenses',
			ISNULL(ProfitLost, 0.00) AS 'ProfitLost'
		FROM #Allocations
		ORDER BY PropertyName, PeriodStartDate


END
GO
