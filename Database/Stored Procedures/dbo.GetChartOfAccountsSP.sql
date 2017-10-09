SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Olsen
-- Create date: Jan 8, 2012
-- Description:	Lies on top of same table valued
--				function
-- =============================================
CREATE PROCEDURE [dbo].[GetChartOfAccountsSP]
	@accountID BIGINT,
	@userID uniqueidentifier = null,
	@overrideIncludeParents bit = 0,
	@glAccountTypes StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF @userID is not null
	BEGIN
	
		CREATE TABLE #PermittedGLAccounts (
			GLAccountID uniqueidentifier,
			Number nvarchar(100),
			Name nvarchar(500),
			GLAccountType nvarchar(100),
			DefaultExpenseTypeID uniqueidentifier,
			ParentGLAccountID uniqueidentifier,
			IsReplacementReserve bit,
			DefaultExpenseTypePriority int
		)

		INSERT INTO #PermittedGLAccounts
			EXEC GetPermittedChartOfAccounts @accountID, @userID, null, null, null, @overrideIncludeParents

			SELECT
				coa.*, 
				ISNULL(gla.IsActive, 1) [IsActive]
			FROM GetChartOfAccounts(@accountID, @glAccountTypes) coa
				JOIN GLAccount gla ON coa.GLAccountID = gla.GLAccountID
				JOIN #PermittedGLAccounts #pgl on coa.GLAccountID = #pgl.GLAccountID
			ORDER BY [OrderByPath]
			END
	ELSE 
	BEGIN
		SELECT
			coa.*, 
			ISNULL(gla.IsActive, 1) [IsActive]
		FROM GetChartOfAccounts(@accountID, @glAccountTypes) coa
			JOIN GLAccount gla ON coa.GLAccountID = gla.GLAccountID
		ORDER BY [OrderByPath]
	END
END

GO
