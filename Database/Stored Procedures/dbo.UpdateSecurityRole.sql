SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[UpdateSecurityRole] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@securityRoleID uniqueidentifier = null,
	@name nvarchar(50) = null,
	@description nvarchar(200) = null,
	@timeout int = null,
	@rolePermissionIDs IntCollection READONLY,
	@userIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	-- update security role data
	UPDATE SecurityRole SET Name = @name, [Description] = @description, [Timeout] = @timeout WHERE SecurityRoleID = @securityRoleID AND AccountID = @accountID
	-- delete existing role permissions
	DELETE RolePermission WHERE SecurityRoleID = @securityRoleID AND AccountID = @accountID
	-- add new role permissions
	INSERT INTO RolePermission
		SELECT newid(), @accountID, @securityRoleID, Value, null FROM @rolePermissionIDs
	
	-- remove userpermissionexceptions for any users that are not going to be part of
	-- the group anymore
	DELETE UserPermissionException 
	FROM UserPermissionException upe join 
			[User] u on upe.UserID = u.UserID
	WHERE u.SecurityRoleID = @securityRoleID and
		   u.UserID not in (SELECT Value FROM @userIDs)
		   	
	-- remove users that are no longer in the group	
	UPDATE [User] SET [SecurityRoleID] = null 
	WHERE [SecurityRoleID] = @securityRoleID AND
			AccountID = @accountID AND
			Username <> 'admin' AND
			UserID not in (select Value from @userIDs)
			
	-- remove any security exceptions that someone not already in the group may have
	DELETE UserPermissionException
	FROM UserPermissionException upe inner join 
			[User] u on upe.UserID = u.UserID 
	WHERE u.SecurityRoleID <> @securityRoleID and -- not already part of the group
				u.UserID in (Select Value from @userIDs) -- and included in the group
	
	-- remove any securityexceptions that existing users have that are
	-- part of the groups permissions and were granted via an exception
	-- or
	-- ones that are no longer part of the groups permissions and were removed via an exception
	delete UserPermissionException 
	from UserPermissionException upe
		join [User] u on upe.UserID = u.UserID
		where u.SecurityRoleID = @securityRoleID and
		(upe.PermissionId in (Select Value from @rolePermissionIDs) and
		upe.IsGranted = 1) or (upe.PermissionId not in (Select Value from @rolePermissionIDs) and
		upe.IsGranted = 0)
	
	-- add the users that are not already part of the group to security role
	UPDATE [User] 
	SET [SecurityRoleID] = @securityRoleID 
	WHERE UserID IN (SELECT Value FROM @userIDs) AND AccountID = @accountID
	-- and SecurityRoleID <> @securityRoleID 
END
GO
