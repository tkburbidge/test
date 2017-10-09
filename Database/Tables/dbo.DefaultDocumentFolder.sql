CREATE TABLE [dbo].[DefaultDocumentFolder]
(
[DefaultDocumentFolderID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Path] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DefaultDocumentFolder] ADD CONSTRAINT [PK_DefaultDocumentFolder] PRIMARY KEY CLUSTERED  ([DefaultDocumentFolderID], [AccountID]) ON [PRIMARY]
GO
