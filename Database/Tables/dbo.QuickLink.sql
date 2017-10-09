CREATE TABLE [dbo].[QuickLink]
(
[QuickLinkID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Url] [nvarchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Order] [tinyint] NOT NULL,
[Target] [nvarchar] (16) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsReport] [bit] NOT NULL,
[IsAjax] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[QuickLink] ADD CONSTRAINT [PK_CustomLink] PRIMARY KEY CLUSTERED  ([QuickLinkID], [AccountID]) ON [PRIMARY]
GO
