SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Joshua Grigg
-- Create date: July 16, 2015
-- Description:	Updates a WorkflowGroup (updates users and group name)
-- =============================================
CREATE PROCEDURE [dbo].[UpdateWorkflowGroup] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@workflowGroupID uniqueidentifier,
	@workflowGroupName nvarchar(50),
	@userIDs guidcollection readonly
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	--remove all users from workflow group
	UPDATE [User] SET WorkflowGroupID = NULL WHERE WorkflowGroupID = @workflowGroupID
	
	--add userlist to workflow group
	UPDATE [User] SET WorkflowGroupID = @workflowGroupID WHERE UserID IN (SELECT Value FROM @userIDs)

	--update workflow group name
	UPDATE [WorkflowGroup] SET Name = @workflowGroupName WHERE WorkflowGroupID = @workflowGroupID
	
END


GO
