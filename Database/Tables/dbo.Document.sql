CREATE TABLE [dbo].[Document]
(
[DocumentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Uri] [nvarchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ThumbnailUri] [nvarchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Size] [bigint] NOT NULL,
[DateAttached] [smalldatetime] NOT NULL,
[AttachedByPersonID] [uniqueidentifier] NOT NULL,
[FileType] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContentType] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Path] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ShowInResidentPortal] [bit] NOT NULL,
[ObjectType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OrderBy] [tinyint] NULL,
[IsExternal] [bit] NOT NULL,
[AltObjectID] [uniqueidentifier] NULL,
[AltObjectType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Document] ADD CONSTRAINT [PK_Document] PRIMARY KEY CLUSTERED  ([DocumentID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Document_AttachedByPersonID] ON [dbo].[Document] ([AttachedByPersonID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Document_ObjectID] ON [dbo].[Document] ([ObjectID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Document_PropertyID] ON [dbo].[Document] ([PropertyID]) ON [PRIMARY]
GO
