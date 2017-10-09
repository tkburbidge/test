SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[DeleteReportGroup]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@reportName nvarchar(100)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @GroupIDs AS TABLE (
		GLAccountGroupID uniqueidentifier
	)
	
	INSERT INTO @GroupIDs
		SELECT ParentGLAccountGroupID FROM ReportGroup WHERE ReportName = @reportName
		
	INSERT INTO @GroupIDs
		SELECT ChildGLAccountGroupID FROM ReportGroup WHERE ReportName = @reportName

	DELETE FROM ReportGroup 
	WHERE AccountID = @accountID
		AND ReportName = @reportName
	
    DELETE GLAccountGroup
    FROM GLAccountGroup	glg
	WHERE glg.AccountID = @accountID
		AND glg.Name IS NULL
		AND glg.GLAccountGroupID IN (SELECT GLAccountGroupID FROM @GroupIDs)
		AND NOT EXISTS (SELECT * FROM GLAccountGLAccountGroup ggg WHERE ggg.GLAccountGroupID = glg.GLAccountGroupID)						
END
GO
