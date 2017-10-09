CREATE TABLE [dbo].[PickListItemCategory]
(
[PickListItemCategoryID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Unqualified] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PickListItemCategory] ADD CONSTRAINT [PK_PickListItemCategory] PRIMARY KEY CLUSTERED  ([PickListItemCategoryID], [AccountID]) ON [PRIMARY]
GO
