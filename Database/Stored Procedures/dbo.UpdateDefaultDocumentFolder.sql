SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Trevor Burbidge
-- Create date: 07/18/2013
-- Description:	Updates the name and path of a DefaultDocumentFolder and also updates the path for any documents or folders that are contained within the DefaultDocumentFolder
-- =============================================
create PROCEDURE [dbo].[UpdateDefaultDocumentFolder] 
	-- Add the parameters for the stored procedure here
	@accountID bigint, 
	@defaultDocumentFolderID uniqueidentifier,
	@name nvarchar(100),
	@path nvarchar(500)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    DECLARE @oldPath nvarchar(500)
    DECLARE @objectType nvarchar(100)
    SELECT @oldPath = [Path], @objectType = ObjectType
		FROM DefaultDocumentFolder
		WHERE DefaultDocumentFolderID = @defaultDocumentFolderID AND AccountID = @accountID

	UPDATE Document 
		SET [Path] = @path + RIGHT([Path], LEN([Path]) - LEN(@oldPath))
		WHERE AccountID = @accountID AND 
			  ObjectType = @objectType AND 
			  ([Path] LIKE @oldPath + '/%' OR [Path] = @oldPath)
	
	UPDATE DefaultDocumentFolder
		SET [Path] = @path, 
			Name = @name
		WHERE DefaultDocumentFolderID = @defaultDocumentFolderID AND AccountID = @accountID
END
GO
