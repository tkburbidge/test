SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Jordan Betteridge
-- Create date: March 30, 2015
-- Description:	Generates the data for the Journal Entry Register Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_JRNLE_JournalEntries] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null,
	@accountingBasis nvarchar(10) = null,
	@postingPersonIDs GuidCollection READONLY,
	@accountingBookIDs GuidCollection READONLY
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate [Date] NOT NULL,
		EndDate [Date] NOT NULL)
		
	CREATE TABLE #JournalEntries (
		TransactionGroupParentID uniqueidentifier NOT NULL,
		TransactionGroupID uniqueidentifier NOT NULL,
		PropertyID uniqueidentifier NOT NULL,
		[User] nvarchar(210) NOT NULL,
		[Date] date NOT NULL,
		[Description] nvarchar(500) NOT NULL,
		AccountingBasis nvarchar(50) NOT NULL,
		AccountingBook nvarchar(50) NOT NULL
	)
	
	CREATE TABLE #JournalEntryItems (
		TransactionGroupID uniqueidentifier NOT NULL,
		PropertyID uniqueidentifier NOT NULL,
		PropertyAbbreviation nvarchar(8) NOT NULL,
		TransactionID uniqueidentifier NOT NULL,
		JournalEntryID uniqueidentifier NOT NULL,
		[TimeStamp] datetime NOT NULL,
		GLAccountID uniqueidentifier NOT NULL,
		GLAccount nvarchar(70) NOT NULL,
		[Description] nvarchar(500) NOT NULL,
		Amount money NOT NULL,  
	)

	CREATE TABLE #AccountingBooks (
		AccountingBookID uniqueidentifier not null)
		
	CREATE TABLE #PersonIDs (
		PersonID uniqueidentifier
	)

	INSERT INTO #PersonIDs 
		SELECT Value FROM @postingPersonIDs

	INSERT INTO #AccountingBooks 
		SELECT Value FROM @accountingBookIDs

	IF (@accountingPeriodID IS NOT NULL)
	BEGIN		
		INSERT #PropertyAndDates
			SELECT pids.Value, pap.StartDate, pap.EndDate
				FROM @propertyIDs pids
					INNER JOIN PropertyAccountingPeriod pap ON pids.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	END
	ELSE
	BEGIN
		INSERT #PropertyAndDates
			SELECT pids.Value, @startDate, @endDate
				FROM @propertyIDs pids
	END
	
	INSERT #JournalEntries
		SELECT DISTINCT
			tgp.TransactionGroupParentID,
			tgp.TransactionGroupID,
			tgp.PropertyID,
			per.PreferredName + ' ' + per.LastName,
			tgp.[Date],
			tgp.[Description],
			tgp.AccountingBasis,
			CASE WHEN tgp.AccountingBookID IS NULL THEN 'Default'
				 ELSE ab.Name END
		FROM TransactionGroupParent tgp
			INNER JOIN #PropertyAndDates #pad ON #pad.PropertyID = tgp.PropertyID
			INNER JOIN Person per on tgp.PersonID = per.PersonID
			INNER JOIN #PersonIDs #pids ON #pids.PersonID = per.PersonID
			INNER JOIN #AccountingBooks #abids ON ISNULL(tgp.AccountingBookID, '55555555-5555-5555-5555-555555555555') = #abids.AccountingBookID
			LEFT JOIN AccountingBook ab ON tgp.AccountingBookID = ab.AccountingBookID
		WHERE tgp.AccountID = @accountID
		  AND tgp.[Date] >= #pad.StartDate 
		  AND tgp.[Date] <= #pad.EndDate
		  AND (@accountingBasis = 'Both' OR (tgp.AccountingBasis = @accountingBasis OR tgp.AccountingBasis = 'Both'))
		  
	
	
	INSERT #JournalEntryItems
		SELECT DISTINCT
			je.TransactionGroupID,
			t.PropertyID,
			p.Abbreviation,
			t.TransactionID,
			je2.JournalEntryID,
			t.[TimeStamp],
			gla.GLAccountID,
			gla.Number + ' - ' + gla.Name,
			t.[Description],
			t.Amount
		FROM #JournalEntries je
			INNER JOIN TransactionGroup tg on je.TransactionGroupID = tg.TransactionGroupID
			INNER JOIN [Transaction] t on tg.TransactionID = t.TransactionID
			INNER JOIN JournalEntry je2 on t.TransactionID = je2.TransactionID
			INNER JOIN GLAccount gla on je2.GLAccountID = gla.GLAccountID
			INNER JOIN Property p on t.PropertyID = p.PropertyID
		WHERE (je.AccountingBasis = je2.AccountingBasis OR (je.AccountingBasis = 'Both' AND je2.AccountingBasis = 'Accrual'))
		ORDER BY [TimeStamp]
			
	SELECT * FROM #JournalEntries ORDER BY [Date], [Description]
	SELECT * FROM #JournalEntryItems

END





GO
