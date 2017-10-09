SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 24, 2012
-- Description:	Updates users in a given group to the given group
-- =============================================
CREATE PROCEDURE [dbo].[UpdateSecurityRoleMembership] 
	-- Add the parameters for the stored procedure here
	@securityRoleID uniqueidentifier = null, 
	@userIDsInRole GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	UPDATE [User] SET SecurityRoleID = null WHERE SecurityRoleID = @securityRoleID
	
	UPDATE [User] SET SecurityRoleID = @securityRoleID 
		WHERE UserID IN (SELECT Value FROM @userIDsInRole)
		
END
GO
