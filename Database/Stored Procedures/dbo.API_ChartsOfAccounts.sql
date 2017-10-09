SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Craig Bertelsen
-- Create date: Mar 09, 2015
-- Description:	Gets a list of GL Accounts for an API request.
-- =============================================
CREATE PROCEDURE [dbo].[API_ChartsOfAccounts] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null, 
	@propertyID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #GLAccountsIHaveAccessTo (
		GLAccountID uniqueidentifier not null)
			
	INSERT INTO #GLAccountsIHaveAccessTo
		SELECT gla.GLAccountID	
			FROM GLAccount gla
			WHERE gla.AccountID = @accountID
				AND gla.IsActive = 1
								
	DELETE #GLAIHAT
		FROM #GLAccountsIHaveAccessTo #GLAIHAT
		WHERE EXISTS(SELECT * 
					  FROM GLAccountPropertyRestriction glapr
					  WHERE #GLAIHAT.GLAccountID = glapr.GLAccountID
					    AND glapr.PropertyID = @propertyID
					    AND glapr.AccountID = @accountID)
		--WHERE EXISTS(SELECT *
		--				FROM GLAccountProperty glap
		--				WHERE #GLAIHAT.GLAccountID = glap.GLAccountID
		--					AND glap.AccountID = @accountID)
		--	AND NOT EXISTS(SELECT * 
		--					FROM GLAccountProperty glap
		--					WHERE #GLAIHAT.GLAccountID = glap.GLAccountID
		--						AND glap.PropertyID = @propertyID
		--						AND glap.AccountID = @accountID)
	
	SELECT DISTINCT
		#glaihat.GLAccountID,
		gla.Number, gla.Name,
		gla.GLAccountType AS 'Type',
		gla.[Description]
		FROM #GLAccountsIHaveAccessTo #glaihat
			INNER JOIN GLAccount gla ON #glaihat.GLAccountID = gla.GLAccountID
		WHERE gla.AccountID = @accountID			
	ORDER BY gla.Number	
END

GO
