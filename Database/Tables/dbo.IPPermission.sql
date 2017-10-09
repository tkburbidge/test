CREATE TABLE [dbo].[IPPermission]
(
[IPPermissionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SecurityRoleID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RangeStart] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[RangeEnd] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IPPermission] ADD CONSTRAINT [PK_IPPermission] PRIMARY KEY CLUSTERED  ([IPPermissionID], [AccountID]) ON [PRIMARY]
GO
