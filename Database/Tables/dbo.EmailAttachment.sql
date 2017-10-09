CREATE TABLE [dbo].[EmailAttachment]
(
[EmailAttachmentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DocumentID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[EmailAttachment] ADD CONSTRAINT [PK_EmailAttachment] PRIMARY KEY CLUSTERED  ([EmailAttachmentID], [AccountID]) ON [PRIMARY]
GO
