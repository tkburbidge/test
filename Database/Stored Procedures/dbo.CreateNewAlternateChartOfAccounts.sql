SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: June 13, 2014
-- Description:	Creates an Alternate Chart of Accounts of a given name, based off the orginal chart of accounts
-- =============================================
CREATE PROCEDURE [dbo].[CreateNewAlternateChartOfAccounts] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@name nvarchar(50) = null,
	@alternateNameDelimiter nvarchar(15) = null,
	@alternateNumberDelimieter nvarchar(15) = null
AS
DECLARE @defaultAltName nvarchar(10) = '&&**^^!'
DECLARE @defaultAltNumber nvarchar(10) = '##@@##!'
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	IF (@alternateNameDelimiter IS NULL OR @alternateNameDelimiter = '')
	BEGIN
		SET @alternateNameDelimiter = @defaultAltName
	END
	IF (@alternateNumberDelimieter IS NULL OR @alternateNumberDelimieter = '')
	BEGIN
		SET @alternateNumberDelimieter = @defaultAltNumber
	END
	
	IF (0 < (SELECT COUNT(*) FROM AlternateChartOfAccounts WHERE Name = @name))
	BEGIN
		SELECT '00000000-0000-0000-0000-000000000000'
	END
	ELSE
	BEGIN
	
		DECLARE @newAltChartID uniqueidentifier = NEWID()

		INSERT AlternateChartOfAccounts VALUES (@newAltChartID, @accountID, @name)

		INSERT AlternateGLAccount 
			SELECT NEWID(), @accountID, @newAltChartID, GLAccountType, @alternateNameDelimiter+Name, [Description], @alternateNumberDelimieter+Number, Statistic, null, SummaryParent
				FROM GLAccount
				WHERE AccountID = @accountID
				AND IsActive = 1

--insert AlternateGLAccount
--	select NEWID(), 1, @newAltChartID, GLAccountType, 'ALT-'+Name, [Description], 'A'+Number, Statistic, null, SummaryParent
--		from GLAccount 

		INSERT GLAccountAlternateGLAccount
			SELECT agl.AlternateGLAccountID, gl.GLAccountID, @accountID
				FROM GLAccount gl
					INNER JOIN AlternateGLAccount agl ON @alternateNumberDelimieter+gl.Number = agl.Number
				WHERE gl.AccountID = @accountID
		
--insert GLAccountAlternateGLAccount 
--	select agl.AlternateGLAccountID, gl.GLAccountID, 1
--		from GLAccount gl
--			inner join AlternateGLAccount agl ON 'A'+gl.Number = agl.Number
			
		
--update agl SET agl.ParentAlternateGLAccountID = (SELECT distinct agl1.AlternateGLAccountID 
--													FROM AlternateGLAccount agl1 
--														INNER JOIN GLAccount gl1 ON 'ALT-'+gl1.Name = agl1.Name AND 'A'+gl1.Number = agl1.Number
--														INNER JOIN GLAccount pgl1 ON gl1.GLAccountID = pgl1.ParentGLAccountID
--														INNER JOIN AlternateGLAccount pagl1 ON pagl1.Name = 'ALT-'+pgl1.Name AND pagl1.Number = 'A'+pgl1.Name
--													WHERE agl.AlternateGLAccountID = pagl1.AlternateGLAccountID)
--	from AlternateGLAccount agl

		UPDATE agl SET agl.ParentAlternateGLAccountID = (SELECT DISTINCT agl1.AlternateGLAccountID
															FROM AlternateGLAccount agl1
																INNER JOIN GLAccount gl1 ON @alternateNameDelimiter+gl1.Name = agl1.Name
																					AND @alternateNumberDelimieter+gl1.Number = agl1.Number
																INNER JOIN GLAccount pgl1 ON gl1.GLAccountID = pgl1.ParentGLAccountID
																INNER JOIN AlternateGLAccount pagl1 ON pagl1.Name = @alternateNameDelimiter+pgl1.Name
																					AND pagl1.Number = @alternateNumberDelimieter+pgl1.Number
															WHERE agl.AlternateGLAccountID = pagl1.AlternateGLAccountID)
			FROM AlternateGLAccount agl
			WHERE agl.AlternateChartOfAccountsID = @newAltChartID
			
		UPDATE AlternateGLAccount SET Name = REPLACE(Name, @defaultAltName, '') WHERE AccountID = @accountID
		UPDATE AlternateGLAccount SET Number = REPLACE(Number, @defaultAltNumber, '') WHERE AccountID = @accountID

		SELECT @newAltChartID
	END

END
GO
