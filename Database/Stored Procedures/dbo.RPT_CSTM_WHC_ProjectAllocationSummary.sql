SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Nov. 15, 2016
-- Description:	Woodsmere Custom Report: Project Allocation Summary
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_WHC_ProjectAllocationSummary] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null,
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
		StreetAddress nvarchar(500) null,
		City nvarchar(50) null,
		[State] nvarchar(50) null,
		Income money null,
		Expenses money null,
		Principal money null)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #GLAccountIDsAndTypes (
		GLAccountID uniqueidentifier not null,
		[Type] nvarchar(5) null)

	CREATE TABLE #GLAccountMortgages (
		PropertyID uniqueidentifier not null,
		GLAccountID uniqueidentifier not null)

	INSERT #PropertiesAndDates
		SELECT	pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT PropertyID FROM #PropertiesAndDates))

	INSERT #Allocations
		SELECT	#pad.PropertyID,
				p.Name,
				adder.StreetAddress,
				adder.City,
				adder.[State] AS [Address],
				null,
				null,
				null
			FROM #PropertiesAndDates #pad
				INNER JOIN Property p ON #pad.PropertyID = p.PropertyID
				INNER JOIN [Address] adder ON p.AddressID = adder.AddressID

	INSERT #GLAccountIDsAndTypes
		SELECT GLAccountID, 'Inc'	
			FROM GLAccount
			WHERE Number IN ('40100', '40110', '40120', '40500', '40510', '40520', '40530', '40540', '40550', '42000', '41010' , '41000')
			  AND AccountID = @accountID

	INSERT #GLAccountIDsAndTypes
		SELECT GLAccountID, 'Exp'
			FROM GLAccount
			WHERE ParentGLAccountID IN (SELECT GLAccountID
											FROM GLAccount
											WHERE Number IN ('54000', '55000', '56000', '58000', '53000')
											  AND AccountID = @accountID)

	INSERT #GLAccountIDsAndTypes
		SELECT GLAccountID, 'Exp'	
			FROM GLAccount
			WHERE Number IN ('50900', '50100', '50200')
			  AND AccountID = @accountID

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


	UPDATE #Allocations SET Income = (SELECT SUM(-je.Amount)
										  FROM JournalEntry je
											  INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
											  INNER JOIN Settings s ON t.AccountID = s.AccountID
											  INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																			AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
											  INNER JOIN #GLAccountIDsAndTypes #glaTypes ON je.GLAccountID = #glaTypes.GLAccountID AND #glaTypes.[Type] = 'Inc'
											  LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID AND tr.TransactionDate <= #pad.EndDate
										  WHERE t.PropertyID = #Allocations.PropertyID
										    AND t.Origin NOT IN ('Y', 'E')
											AND je.AccountingBookID IS NULL
											AND je.AccountingBasis = s.DefaultAccountingBasis)

	UPDATE #Allocations SET Expenses = (SELECT SUM(je.Amount)
											FROM JournalEntry je
												INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
												INNER JOIN Settings s ON t.AccountID = s.AccountID
												INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																	AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
												INNER JOIN #GLAccountIDsAndTypes #glaTypes ON je.GLAccountID = #glaTypes.GLAccountID AND #glaTypes.[Type] = 'Exp'
												LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID AND tr.TransactionDate <= #pad.EndDate
											WHERE t.PropertyID = #Allocations.PropertyID
											  AND t.Origin NOT IN ('Y', 'E')
											  AND je.AccountingBookID IS NULL
											  AND je.AccountingBasis = s.DefaultAccountingBasis)


	UPDATE #Allocations SET Principal = (SELECT SUM(je.Amount)
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													INNER JOIN Settings s ON t.AccountID = s.AccountID
													INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID 
																		AND t.TransactionDate >= #pad.StartDate AND t.TransactionDate <= #pad.EndDate
													INNER JOIN #GLAccountMortgages #GLAM ON je.GLAccountID = #GLAM.GLAccountID AND t.PropertyID = #GLAM.PropertyID
													LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID AND tr.TransactionDate <= #pad.EndDate
												WHERE t.PropertyID = #Allocations.PropertyID
												  AND t.Origin NOT IN ('Y', 'E')
												  AND je.Amount > 0
												  AND t.Description NOT LIKE '%Reverse%'
												  AND je.AccountingBookID IS NULL
												  AND je.AccountingBasis = s.DefaultAccountingBasis)

	SELECT 
		PropertyID,
		PropertyName,
		StreetAddress,
		City,
		[State],
		ISNULL(Income, 0.00) AS 'Income',
		(ISNULL(Expenses, 0.00) + ISNULL(Principal, 0.00)) AS 'Expenses',
		ISNULL(Principal, 0.00) AS 'Principal'
		FROM #Allocations
		ORDER BY PropertyName

END
GO
