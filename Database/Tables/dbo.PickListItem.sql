CREATE TABLE [dbo].[PickListItem]
(
[PickListItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Type] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ObjectID] [uniqueidentifier] NULL,
[OrderBy] [int] NULL,
[IsSystem] [bit] NOT NULL,
[IsDeleted] [bit] NOT NULL,
[Abbreviation] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsNotOccupant] [bit] NULL,
[PickListItemCategoryID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PickListItem] ADD CONSTRAINT [PK_PickListItem] PRIMARY KEY CLUSTERED  ([PickListItemID], [AccountID]) ON [PRIMARY]
GO
