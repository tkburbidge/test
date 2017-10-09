SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Craig Perkins
-- Create date: 11/18/2014
-- Description:	Creates a new Alternate Chart of Accounts, copying 
-- =============================================
CREATE PROCEDURE [dbo].[CopyAlternateChartOfAccounts] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@alternateChartOfAccountsID uniqueidentifier,
	@name nvarchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    
	DECLARE @alternateNameDelimiter nvarchar(100) = 'A&&**^^!'
	DECLARE @alternateNumberDelimieter nvarchar(100) = 'A##@@##!'
	DECLARE @newAlternateChartOfAccountsID uniqueidentifier = NEWID()

	INSERT AlternateChartOfAccounts
				SELECT @newAlternateChartOfAccountsID, @accountID, @name

	INSERT AlternateGLAccount 
				SELECT NEWID(), @accountID, @newAlternateChartOfAccountsID, GLAccountType, @alternateNameDelimiter+Name, [Description], @alternateNumberDelimieter+Number, Statistic, null, SummaryParent
					FROM AlternateGLAccount
					WHERE AlternateChartOfAccountsID = @alternateChartOfAccountsID


	INSERT GLAccountAlternateGLAccount
				SELECT agl.AlternateGLAccountID, baseglagl.GLAccountID, @accountID
					FROM AlternateGLAccount baseagl
						INNER JOIN GLAccountAlternateGLAccount baseglagl ON baseglagl.AlternateGLAccountID = baseagl.AlternateGLAccountID
						INNER JOIN AlternateGLAccount agl ON @alternateNumberDelimieter+baseagl.Number = agl.Number
					WHERE baseagl.AlternateChartOfAccountsID = @alternateChartOfAccountsID
						AND agl.AlternateChartOfAccountsID =  @newAlternateChartOfAccountsID

	UPDATE agl SET agl.ParentAlternateGLAccountID = (SELECT DISTINCT newParentGL.AlternateGLAccountID
														FROM AlternateGLAccount baseGL
															INNER JOIN AlternateGLAccount baseParentGL ON baseParentGL.AlternateGLAccountID = baseGL.ParentAlternateGLAccountID
															INNER JOIN AlternateGLAccount newParentGL ON newParentGL.Number = @alternateNumberDelimieter+baseParentGL.Number
														WHERE @alternateNumberDelimieter+baseGL.Number = agl.Number
															AND baseGL.AlternateChartOfAccountsID = @alternateChartOfAccountsID
															AND baseParentGL.AlternateChartOfAccountsID = @alternateChartOfAccountsID
															AND newParentGL.AlternateChartOfAccountsID = @newAlternateChartOfAccountsID)
		FROM AlternateGLAccount agl
		WHERE agl.AlternateChartOfAccountsID = @newAlternateChartOfAccountsID
			
	UPDATE AlternateGLAccount SET Name = REPLACE(Name, @alternateNameDelimiter, '') WHERE AlternateChartOfAccountsID = @newAlternateChartOfAccountsID
	UPDATE AlternateGLAccount SET Number = REPLACE(Number, @alternateNumberDelimieter, '') WHERE AlternateChartOfAccountsID = @newAlternateChartOfAccountsID

	SELECT @newAlternateChartOfAccountsID
	
END
GO
