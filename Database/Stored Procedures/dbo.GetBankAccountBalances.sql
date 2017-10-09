SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Craig Perkins
-- Create date: Jun 25, 2013
-- Description:	Gets the balances of the bank accounts 
--				associated with the properties passed in
-- =============================================
CREATE PROCEDURE [dbo].[GetBankAccountBalances] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 		
	@date datetime = null,
	@propertyIDs guidcollection readonly,
	@userID uniqueidentifier,
	@includeClosed bit = 1,
	@today datetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @accountingBasis nvarchar(10) = (SELECT DefaultAccountingBasis FROM Settings WHERE AccountID = @accountID)
	
	CREATE TABLE #bankAccounts
	(
		BankAccountID uniqueidentifier not null,
		GLAccountID uniqueidentifier not null,
		AccountName nvarchar(500) not null,
		AccountNumber nvarchar(500) not null,
		Balance money not null,
		AccountType nvarchar(20) not null,
		LastReconciliation date null,
		CreditLimit money null
	)

	-- Add bank accounts to the table
	INSERT INTO #bankAccounts
	SELECT DISTINCT 
		ba.BankAccountID, 
		ba.GLAccountID, 
		ba.AccountName, 
		ba.AccountNumber, 
		0, 
		ba.[Type], 
		null,
		ba.CreditLimit
	FROM BankAccount ba
		INNER JOIN BankAccountProperty bap ON bap.BankAccountID = ba.BankAccountID
		JOIN BankAccountSecurityRole basr ON ba.BankAccountID = basr.BankAccountID
		JOIN SecurityRole sr ON basr.SecurityRoleID = sr.SecurityRoleID
		JOIN [User] u ON sr.SecurityRoleID = u.SecurityRoleID
	WHERE bap.PropertyID IN (SELECT Value FROM @propertyIDs) 
		AND u.UserID = @userID 
		AND basr.HasAccess = 1
		AND (@includeClosed = 1 OR (ba.CloseDate IS NULL OR ba.CloseDate >= @today))
	
	-- Update the balance of each bank account
	UPDATE #bankAccounts SET Balance = (SELECT ISNULL(SUM(je.Amount), 0)
										FROM JournalEntry je 
										INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
										WHERE je.GLAccountID = #bankAccounts.GLAccountID
											AND je.AccountingBasis = @accountingBasis
											AND je.AccountingBookID IS NULL
											AND t.TransactionDate <= @date
											-- Get journal entries that are posted to the 
											-- properties associated with this bank account
											AND t.PropertyID IN (SELECT PropertyID 
																 FROM BankAccountProperty 
																 WHERE BankAccountID = #bankAccounts.BankAccountID))

	-- Update the last reconciled date of each bank account
	UPDATE #bankAccounts SET LastReconciliation = (SELECT TOP 1 bar.StatementDate
												   FROM BankAccountReconciliation bar
												   WHERE bar.BankAccountID = #bankAccounts.BankAccountID
													 AND bar.DateCompleted IS NOT NULL
													 --AND bar.DateCompleted <= @date
												   ORDER BY StatementDate DESC)
																 
	SELECT * FROM #bankAccounts	
	ORDER BY AccountName	
END




GO
