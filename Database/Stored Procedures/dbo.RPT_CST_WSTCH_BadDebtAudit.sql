SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 4, 2016
-- Description:	Gets the bad debt write offs for Wasatch
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_WSTCH_BadDebtAudit] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS

DECLARE @accountID bigint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #WriteOffables (
		LedgerItemTypeID uniqueidentifier not null)

	CREATE TABLE #CreditsToWriteOffOurWriteOffables (
		LedgerItemTypeID uniqueidentifier not null,
		GLAccountID uniqueidentifier null)

	CREATE TABLE #AllOurCredits (
		PropertyID uniqueidentifier not null,
		GLAccountID uniqueidentifier null,
		Amount money null)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)

	INSERT #PropertiesAndDates
		SELECT Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT PropertyID FROM #PropertiesAndDates))

	INSERT #WriteOffables
		SELECT	LedgerItemTypeID
			FROM LedgerItemType
			WHERE IsWriteOffable = 1
			  AND AccountID = @accountID

	INSERT #CreditsToWriteOffOurWriteOffables
		SELECT	lita.LedgerItemTypeID, litApplied.GLAccountID
			FROM #WriteOffables #woff
				INNER JOIN LedgerItemTypeApplication lita ON #woff.LedgerItemTypeID = lita.AppliesToLedgerItemTypeID AND lita.CanBeApplied = 1
				INNER JOIN LedgerItemType litApplied On lita.LedgerItemTypeID = litApplied.LedgerItemTypeID

	INSERT #AllOurCredits
		SELECT	t.PropertyID,
				#cwoffs.GLAccountID,
				SUM(ta.Amount)
			FROM [Transaction] t
				INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
				INNER JOIN #WriteOffables #woff ON t.LedgerItemTypeID = #woff.LedgerItemTypeID
				INNER JOIN #CreditsToWriteOffOurWriteOffables #cwoffs ON ta.LedgerItemTypeID = #cwoffs.LedgerItemTypeID
				INNER JOIN #PropertiesAndDates #pads ON t.PropertyID = #pads.PropertyID
				INNER JOIN PaymentTransaction pt ON ta.TransactionID = pt.TransactionID
				INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID
				LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
			WHERE #pads.StartDate <= pay.[Date]
			  AND #pads.EndDate >= pay.[Date]
			  AND tar.TransactionID IS NULL
			GROUP BY t.PropertyID, #cwoffs.GLAccountID

	SELECT	prop.PropertyID,
			prop.Name AS 'PropertyName',
			gla.GLAccountID,
			gla.Number AS 'GLAccountNumber',
			gla.Name AS 'GLAccountName',
			#aCred.Amount AS 'Amount'
		FROM #AllOurCredits #aCred
			INNER JOIN Property prop ON #aCred.PropertyID = prop.PropertyID
			INNER JOIN GLAccount gla ON #aCred.GLAccountID = gla.GLAccountID
		ORDER BY prop.Name, gla.Number
			

END
GO
