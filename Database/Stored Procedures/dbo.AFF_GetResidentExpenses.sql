SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[AFF_GetResidentExpenses] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@personIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Expenses
	(
		AffordableExpenseID uniqueidentifier not null,
		AffordableExpenseAmountID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		PersonName nvarchar(81) not null,
		[Type] nvarchar(10) not null,
		EndDate date null,
		Amount money null,
		AmountEffectiveDate date null,
		[Period] nvarchar(100) not null,
		DateVerified date null,
		VerifiedPersonName nvarchar(81) null, 
		HasDocument bit not null,
		VerificationSources nvarchar(500) null
	)

	INSERT INTO #Expenses
		SELECT
			ae.AffordableExpenseID AS 'AffordableExpenseID',
			[effectiveExpenseAmount].AffordableExpenseAmountID AS 'AffordableExpenseAmountID',
			p.PersonID AS 'PersonID',
			p.FirstName + ' ' + p.LastName AS 'PersonName',
			ae.[Type] AS 'Type',
			ae.EndDate AS 'EndDate',
			[effectiveExpenseAmount].Amount AS 'Amount',
			[effectiveExpenseAmount].EffectiveDate AS 'AmountEffectiveDate',
			[effectiveExpenseAmount].Period AS 'Period',
			[effectiveExpenseAmount].DateVerified AS 'DateVerified',
			[effectiveExpenseAmount].FirstName + ' ' + [effectiveExpenseAmount].LastName AS 'VerifiedPersonName',
			CASE WHEN (doc.DocumentID IS NOT NULL) THEN CAST(1 AS bit)
				 ELSE CAST(0 AS bit) END AS 'HasDocument',
			[effectiveExpenseAmount].VerificationSources AS 'VerificationSources'
		FROM AffordableExpense ae
			INNER JOIN Person p ON ae.PersonID = p.PersonID
			LEFT JOIN Document doc ON ae.AffordableExpenseID = doc.AltObjectID
			LEFT JOIN
				(SELECT aea.AffordableExpenseID, aea.AffordableExpenseAmountID, aea.DateVerified, aea.Amount, aea.EffectiveDate, aea.Period, pv.FirstName, pv.LastName, aea.VerificationSources
					FROM AffordableExpenseAmount aea
						LEFT JOIN Person pv ON aea.VerifiedByPersonID = pv.PersonID) [effectiveExpenseAmount] ON ae.AffordableExpenseID = [effectiveExpenseAmount].AffordableExpenseID
		WHERE ae.AccountID = @accountID
			AND ae.PersonID IN (SELECT Value FROM @personIDs)

	SELECT * FROM #Expenses

END
GO
