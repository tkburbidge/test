CREATE TABLE [dbo].[EnvelopeDocument]
(
[AccountID] [bigint] NOT NULL,
[EnvelopeID] [uniqueidentifier] NOT NULL,
[DocumentID] [uniqueidentifier] NOT NULL,
[SignedDocumentID] [uniqueidentifier] NULL,
[SignaturePackageDocumentID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[EnvelopeDocument] ADD CONSTRAINT [PK_EnvelopeDocument] PRIMARY KEY CLUSTERED  ([AccountID], [EnvelopeID], [DocumentID]) ON [PRIMARY]
GO
