CREATE TABLE [dbo].[RolePermission]
(
[RolePermissionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SecurityRoleID] [uniqueidentifier] NOT NULL,
[PermissionID] [int] NOT NULL,
[Name] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RolePermission] ADD CONSTRAINT [PK_RolePermission] PRIMARY KEY CLUSTERED  ([RolePermissionID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RolePermission] WITH NOCHECK ADD CONSTRAINT [FK_Permission_SecurityRole] FOREIGN KEY ([SecurityRoleID], [AccountID]) REFERENCES [dbo].[SecurityRole] ([SecurityRoleID], [AccountID])
GO
ALTER TABLE [dbo].[RolePermission] NOCHECK CONSTRAINT [FK_Permission_SecurityRole]
GO
