SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[DeleteAlternateChartOfAccounts]
	@accountID bigint,
	@alternateChartOfAccountsID uniqueidentifier
AS
BEGIN
	SET NOCOUNT ON;

	DELETE GLAccountAlternateGLAccount
	WHERE AccountID = @accountID
		AND AlternateGLAccountID IN
		(
			SELECT AlternateGLAccountID
			FROM AlternateGLAccount
			WHERE AccountID = @accountID
				AND AlternateChartOfAccountsID = @alternateChartOfAccountsID
		)

	DELETE AlternateGLAccount
	WHERE AccountID = @accountID
		AND AlternateChartOfAccountsID = @alternateChartOfAccountsID
	  
	DELETE AlternateChartOfAccounts
	WHERE AccountID = @accountID
		AND AlternateChartOfAccountsID = @alternateChartOfAccountsID

END
GO
