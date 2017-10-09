CREATE TABLE [dbo].[SecurityRole]
(
[SecurityRoleID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MaskGLAccountsOnReports] [bit] NOT NULL,
[Timeout] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SecurityRole] ADD CONSTRAINT [PK_SecurityRole] PRIMARY KEY CLUSTERED  ([SecurityRoleID], [AccountID]) ON [PRIMARY]
GO
