SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 10, 2012
-- Description:	Add GLAccountGroupGLAccount records
-- =============================================
CREATE PROCEDURE [dbo].[AddGLAccountGroups] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@glAccountID uniqueidentifier = null,
	@GLAccountGroupIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DELETE GLAccountGLAccountGroup 
		WHERE GLAccountID = @glAccountID
		  AND GLAccountGroupID IN (SELECT Value FROM @GLAccountGroupIDs)
		  AND AccountID = @accountID
		  
	INSERT GLAccountGLAccountGroup (GLAccountGLAccountGroupID, AccountID, GLAccountID, GLAccountGroupID)
		VALUES (NEWID(), @accountID, @glAccountID, (SELECT DISTINCT Value FROM @GLAccountGroupIDs))
END
GO
