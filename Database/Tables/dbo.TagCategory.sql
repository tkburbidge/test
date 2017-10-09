CREATE TABLE [dbo].[TagCategory]
(
[TagCategoryID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Category] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TagCategory] ADD CONSTRAINT [PK__TagCateg__DB57E11CE0197E61] PRIMARY KEY CLUSTERED  ([TagCategoryID]) ON [PRIMARY]
GO
