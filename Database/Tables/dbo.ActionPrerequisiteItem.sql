CREATE TABLE [dbo].[ActionPrerequisiteItem]
(
[AccountID] [bigint] NOT NULL,
[ActionPrerequisiteItemID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsSystem] [bit] NOT NULL,
[OrderBy] [tinyint] NOT NULL,
[IsDeleted] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ActionPrerequisiteItem] ADD CONSTRAINT [PK_ActionPrerequisiteItem] PRIMARY KEY CLUSTERED  ([AccountID], [ActionPrerequisiteItemID]) ON [PRIMARY]
GO
