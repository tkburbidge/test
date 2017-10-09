CREATE TABLE [dbo].[PersonNoteDocument]
(
[PersonNoteDocumentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonNoteID] [uniqueidentifier] NOT NULL,
[DocumentID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PersonNoteDocument] ADD CONSTRAINT [PK_PersonNoteDocument] PRIMARY KEY CLUSTERED  ([PersonNoteDocumentID], [AccountID]) ON [PRIMARY]
GO
