SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Trevor Burbidge
-- Create date: July 10, 2012
-- Description:	Updates GL Account Groups
-- =============================================
CREATE PROCEDURE [dbo].[UpdateGLAccountGroup] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@glAccountGroupID uniqueidentifier = null,
	@name nvarchar(50) = null,
	@reportLabel nvarchar(50) = null,
	@glAccountIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	UPDATE GLAccountGroup SET Name = @name, ReportLabel = @reportLabel WHERE GLAccountGroupID = @glAccountGroupID AND AccountID = @accountID
	
	DELETE GLAccountGLAccountGroup WHERE GLAccountGroupID = @glAccountGroupID AND AccountID = @accountID
	
	INSERT INTO GLAccountGlAccountGroup
		SELECT newid(), Value, @glAccountGroupID, @accountID FROM @glAccountIDs 

END
GO
