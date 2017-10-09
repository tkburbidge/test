CREATE TABLE [dbo].[CssCategory]
(
[CssCategoryID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IconClass] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CssCategory] ADD CONSTRAINT [PK__CssCateg__1C455657353C33EA] PRIMARY KEY CLUSTERED  ([CssCategoryID]) ON [PRIMARY]
GO
