CREATE TABLE [dbo].[UserPermissionException]
(
[UserPermissionExceptionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UserID] [uniqueidentifier] NOT NULL,
[PermissionId] [int] NOT NULL,
[IsGranted] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UserPermissionException] ADD CONSTRAINT [PK_UserPermissionException] PRIMARY KEY CLUSTERED  ([UserPermissionExceptionID], [AccountID]) ON [PRIMARY]
GO
