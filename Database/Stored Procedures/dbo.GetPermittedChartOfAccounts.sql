SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		   Rick Bertelsen
-- Create date:    Jan 13, 2014
-- Modified:       David Mecham
-- Modified Date:  Sept 1, 2014 
-- Description:	Gets a list of GLAccounts that the given user has permission to.

-- Edited on 11/23/2016 by Mike Root, factored in the DoNotAllowPostingToParentGLAccounts property
-- =============================================
CREATE PROCEDURE [dbo].[GetPermittedChartOfAccounts] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null, 
	@userID uniqueidentifier = null,
	@propertyID uniqueidentifier = null,
	@term VARCHAR(50) = null,
	@includeArchived bit = 0,
	@overrideIncludeParents bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #GLAccountsIHaveAccessTo (
		GLAccountID uniqueidentifier not null)
	
	DECLARE @isNumeric bit = ISNUMERIC(@term),
			@noParents bit = (SELECT DoNotAllowPostingToParentGLAccounts FROM Settings WHERE AccountID = @accountID)
		

	IF (@overrideIncludeParents = 1)
	BEGIN
		SET @noParents = 0
	END

	INSERT INTO #GLAccountsIHaveAccessTo
		SELECT gla.GLAccountID	
			FROM GLAccount gla
				INNER JOIN [User] u ON u.UserID = @userID
				INNER JOIN SecurityRole sr ON u.SecurityRoleID = sr.SecurityRoleID 
				INNER JOIN SecurityGLAccountType sglatGroup ON sr.SecurityRoleID = sglatGroup.ObjectID AND sglatGroup.ObjectType = 'SecurityGroup'
								AND sglatGroup.HasAccess = 1 AND sglatGroup.GLAccountType = gla.GLAccountType 
		WHERE gla.AccountID = @accountID
			AND u.AccountID = @accountID
			AND (@includeArchived = 1 OR gla.IsActive = 1)
			AND (@term IS NULL OR (@isNumeric = 1 AND gla.Number like @term + '%') OR (@isNumeric = 0 AND gla.Number + ' - ' + gla.Name like '%' + @term + '%'))
								
	INSERT INTO #GLAccountsIHaveAccessTo
		SELECT gla.GLAccountID	
			FROM GLAccount gla
				INNER JOIN [User] u ON u.UserID = @userID
				INNER JOIN SecurityRole sr ON u.SecurityRoleID = sr.SecurityRoleID 
				INNER JOIN SecurityGLAccountType sglatUser ON u.UserID = sglatUser.ObjectID AND sglatUser.ObjectType = 'User'
								AND sglatUser.HasAccess = 1 AND sglatUser.GLAccountType = gla.GLAccountType
		WHERE gla.AccountID = @accountID
			AND u.AccountID = @accountID
			AND (@includeArchived = 1 OR gla.IsActive = 1)
			AND (@term IS NULL OR (@isNumeric = 1 AND gla.Number like @term + '%') OR (@isNumeric = 0 AND gla.Number + ' - ' + gla.Name like '%' + @term + '%'))								
		
	DELETE #GLAIHAT
		FROM #GLAccountsIHaveAccessTo #GLAIHAT
			INNER JOIN [User] u ON u.UserID = @userID
			INNER JOIN SecurityRole sr ON u.SecurityRoleID = sr.SecurityRoleID 
			INNER JOIN SecurityGLAccount sglaGroup ON #GLAIHAT.GLAccountID = sglaGroup.GLAccountID AND sglaGroup.HasAccess = 0 AND sglaGroup.ObjectID = sr.SecurityRoleID
										AND sglaGroup.ObjectType = 'SecurityGroup'
		WHERE u.AccountID = @accountID
										
	DELETE #GLAIHAT
		FROM #GLAccountsIHaveAccessTo #GLAIHAT
			INNER JOIN [User] u ON u.UserID = @userID
			INNER JOIN SecurityRole sr ON u.SecurityRoleID = sr.SecurityRoleID 
			INNER JOIN SecurityGLAccount sglaUser ON #GLAIHAT.GLAccountID = sglaUser.GLAccountID AND sglaUser.HasAccess = 0 AND sglaUser.ObjectID = u.UserID
										AND sglaUser.ObjectType = 'User'
	IF(@propertyID IS NOT NULL)
		BEGIN									
		DELETE #GLAIHAT
			FROM #GLAccountsIHaveAccessTo #GLAIHAT
			WHERE EXISTS(SELECT * FROM GLAccountPropertyRestriction glapr WHERE #GLAIHAT.GLAccountID = glapr.GLAccountID AND glapr.PropertyID = @propertyID AND glapr.AccountID = @accountID)
			--WHERE EXISTS(SELECT * FROM GLAccountProperty glap WHERE #GLAIHAT.GLAccountID = glap.GLAccountID AND glap.AccountID = @accountID) AND
			--	  NOT EXISTS(SELECT * FROM GLAccountProperty glap WHERE #GLAIHAT.GLAccountID = glap.GLAccountID	AND glap.PropertyID = @propertyID AND glap.AccountID = @accountID)
	END																			
	
	IF(@noParents = 1)
	BEGIN
		DELETE #GLAIHAT
			FROM #GLAccountsIHaveAccessTo #GLAIHAT
			-- Find all of the accounts that have children and delete them
			WHERE (SELECT COUNT(*) FROM GLAccount gla2 WHERE gla2.ParentGLAccountID = #GLAIHAT.GLAccountID) > 0
	END

	SELECT DISTINCT #glaihat.GLAccountID, gla.Number, gla.Name, gla.GLAccountType AS 'Type', gla.DefaultExpenseTypeID, gla.ParentGLAccountID, gla.IsReplacementReserve, et.[Priority] AS 'DefaultExpenseTypePriority' 
		FROM #GLAccountsIHaveAccessTo #glaihat
			INNER JOIN GLAccount gla ON #glaihat.GLAccountID = gla.GLAccountID
			LEFT JOIN ExpenseType et ON gla.DefaultExpenseTypeID = et.ExpenseTypeID
		WHERE gla.AccountID = @accountID			
END
GO
