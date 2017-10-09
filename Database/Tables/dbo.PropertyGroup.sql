CREATE TABLE [dbo].[PropertyGroup]
(
[PropertyGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsDeleted] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyGroup] ADD CONSTRAINT [PK_PropertyGroup] PRIMARY KEY CLUSTERED  ([PropertyGroupID], [AccountID]) ON [PRIMARY]
GO
