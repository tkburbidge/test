CREATE TABLE [dbo].[CollectionAgreementDocument]
(
[CollectionAgreementDocumentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CollectionAgreementID] [uniqueidentifier] NOT NULL,
[DocumentID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CollectionAgreementDocument] ADD CONSTRAINT [PK_CollectionAgreementDocument] PRIMARY KEY CLUSTERED  ([CollectionAgreementDocumentID], [AccountID]) ON [PRIMARY]
GO
