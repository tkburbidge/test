SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[RPT_JRNLE_JournalEntryAuditLog]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@startDate date,
	@endDate date,
	@accountingBasis nvarchar(100),
	@accountingBookIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	CREATE TABLE #AccountingBookIDs ( AccountingBookID uniqueidentifier )

	INSERT INTO #PropertyIDs 
		SELECT Value FROM @propertyIDs

	INSERT INTO #AccountingBookIDs
		SELECT Value FROM @accountingBookIDs
		
    -- Insert statements for procedure here
	SELECT 
		je.JournalEntryID,
		t.TransactionID,
		pro.Name AS 'Property',
		tt.Name AS 'TransactionType',
		tt.[Group] AS 'Journal',
		ISNULL(p.FirstName + ' ' + p.LastName, '') AS 'PostingPerson',
		t.TransactionDate AS 'Date',
		t.Timestamp,		
		ISNULL(t.Description, '') AS 'Description',
		t.Origin,
		gl.Number AS 'GLAccountNumber',
		gl.Name AS 'GLAccountName',
		(CASE WHEN je.Amount > 0 THEN je.Amount
			  ELSE NULL
		 END) AS 'Debit',
		 (CASE WHEN je.Amount < 0 THEN ABS(je.Amount)
			  ELSE NULL
		 END) AS 'Credit',
		 je.Amount AS 'Amount'
	FROM JournalEntry je
		INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
		LEFT JOIN Person p ON p.PersonID = t.PersonID
		INNER JOIN TransactionType tt ON tt.TransactionTypeID = t.TransactionTypeID
		INNER JOIN Property pro ON pro.PropertyID = t.PropertyID
		INNER JOIN GLAccount gl ON gl.GLAccountID = je.GLAccountID
		INNER JOIN #PropertyIDs #pad ON t.PropertyID = #pad.PropertyID		
		INNER JOIN #AccountingBookIDs #abIDs ON ISNULL(je.AccountingBookID, '55555555-5555-5555-5555-555555555555') = #abIDs.AccountingBookID
	WHERE t.TransactionDate >= @startDate
		AND t.TransactionDate <= @endDate		
		AND je.AccountingBasis = @accountingBasis
	ORDER BY pro.Name, t.TransactionDate, t.Timestamp
		
END
GO
