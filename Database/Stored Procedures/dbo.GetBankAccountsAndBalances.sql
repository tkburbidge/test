SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan 23, 2013
-- Description:	Gets a list of default bank accounts for a list of properties
-- =============================================
CREATE PROCEDURE [dbo].[GetBankAccountsAndBalances] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@objectIDs GuidCollection READONLY,
	@objectType nvarchar(50) = null,			-- Must be PropertyGroup, Property, BankAccount
	@date date = null,
	@accountingBasis nvarchar(50) = null,
	@allPropertiesHaveDefaultAccount bit OUTPUT,
	@userID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	CREATE TABLE #BankAccountBalance (
		BankAccountID			uniqueidentifier	not null,
		GLAccountID				uniqueidentifier	not null,
		AccountName				nvarchar(50)		not null,
		AccountNumber			nvarchar(50)		not null,
		Balance					money				null)
		
	IF (@objectType = 'PropertyGroup')
	BEGIN
		INSERT INTO #BankAccountBalance
			SELECT DISTINCT	ba.BankAccountID, ba.GLAccountID, ba.AccountName, ba.AccountNumberDisplay, 0.00 AS 'Balance'
				FROM Property p
					INNER JOIN PropertyGroupProperty pgp ON p.PropertyID = pgp.PropertyID
					INNER JOIN PropertyGroup pg ON pgp.PropertyGroupID = pg.PropertyGroupID
					INNER JOIN BankAccount ba ON p.DefaultAPBankAccountID = ba.BankAccountID
					JOIN BankAccountSecurityRole basr on ba.BankAccountID = basr.BankAccountID
					JOIN SecurityRole sr on basr.SecurityRoleID = sr.SecurityRoleID
					JOIN [User] u on sr.SecurityRoleID = u.SecurityRoleID
				WHERE pg.PropertyGroupID = (SELECT Value FROM @objectIDs) and u.UserID = @userID and basr.HasAccess = 1	
				
		-- Return whether all properties have a default bank account defined				
		SET @allPropertiesHaveDefaultAccount = CASE WHEN((SELECT COUNT(*) 
														 FROM Property 
														 WHERE PropertyID IN ((SELECT PropertyID 
																			   FROM PropertyGroupProperty 
																			   WHERE PropertyGroupID IN (SELECT Value FROM @objectIDs)))
															AND DefaultAPBankAccountID IS NULL) = 0) 
													THEN 1
													ELSE 0
												END
						
	END
	ELSE IF (@objectType = 'Property')
	BEGIN
		INSERT INTO #BankAccountBalance
			SELECT DISTINCT	ba.BankAccountID, ba.GLAccountID, ba.AccountName, ba.AccountNumberDisplay, 0.00 AS 'Balance'
				FROM BankAccount ba
					INNER JOIN BankAccountProperty bap ON ba.BankAccountID = bap.BankAccountID
					JOIN BankAccountSecurityRole basr on bap.BankAccountID = basr.BankAccountID
					JOIN SecurityRole sr on basr.SecurityRoleID = sr.SecurityRoleID
					JOIN [User] u on sr.SecurityRoleID = u.SecurityRoleID
				WHERE bap.PropertyID = (SELECT Value FROM @objectIDs) and u.UserID = @userID  and basr.HasAccess = 1		
				
		SET @allPropertiesHaveDefaultAccount = CAST(1 as BIT)				
	END
	ELSE
	BEGIN IF (@objectType = 'BankAccounts')
		INSERT INTO #BankAccountBalance
			SELECT	ba.BankAccountID, ba.GLAccountID, ba.AccountName, ba.AccountNumberDisplay, 0.00 AS 'Balance'
				FROM BankAccount ba
					JOIN BankAccountSecurityRole basr on ba.BankAccountID = basr.BankAccountID
					JOIN SecurityRole sr on basr.SecurityRoleID = sr.SecurityRoleID
					JOIN [User] u on sr.SecurityRoleID = u.SecurityRoleID
				WHERE ba.BankAccountID IN (SELECT Value FROM @objectIDs) and u.UserID = @userID	 and basr.HasAccess = 1	
	
		SET @allPropertiesHaveDefaultAccount = CAST(1 as BIT)				
	END
			  
	IF (@date IS NULL)
	BEGIN
		SET @date = DATEADD(year, 2, GETDATE())
	END
	IF (@accountingBasis IS NULL)
	BEGIN
		SET @accountingBasis = (SELECT DefaultAccountingBasis FROM Settings WHERE AccountID = @accountID)
	END
	
	UPDATE #BankAccountBalance SET Balance = (SELECT ISNULL(SUM(Amount), 0)
												FROM (SELECT DISTINCT je.JournalEntryID, je.Amount
												FROM JournalEntry je
													INNER JOIN [Transaction] t ON je.TransactionID = t.TransactionID
													INNER JOIN BankAccountProperty bap ON bap.BankAccountID = #BankAccountBalance.BankAccountID AND bap.PropertyID = t.PropertyID													
												WHERE 
												  t.TransactionDate <= @date
												  AND je.GLAccountID = #BankAccountBalance.GLAccountID
												  AND je.AccountingBasis = @accountingBasis
												  AND je.AccountingBookID IS NULL) t)
	OPTION (RECOMPILE)
												  

				
	IF (@date IS NOT NULL)
	BEGIN									   
		UPDATE #BankAccountBalance SET Balance = ISNULL(Balance, 0) - ISNULL((SELECT SUM(pay.Amount)
																		   FROM Payment pay
																			   INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
																			   INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
																		   WHERE pay.[Date] <= @date
																			 AND pay.ReversedDate > @date
																			 AND t.Amount > 0
																			 AND t.ObjectID = #BankAccountBalance.BankAccountID), 0)																				   
	END
			  
	SELECT * FROM #BankAccountBalance 
	ORDER BY AccountName
	
END




GO
