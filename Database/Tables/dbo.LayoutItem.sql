CREATE TABLE [dbo].[LayoutItem]
(
[LayoutItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LayoutID] [uniqueidentifier] NOT NULL,
[OrderBy] [int] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LayoutItem] ADD CONSTRAINT [PK_LayoutItem] PRIMARY KEY CLUSTERED  ([LayoutItemID], [AccountID]) ON [PRIMARY]
GO
