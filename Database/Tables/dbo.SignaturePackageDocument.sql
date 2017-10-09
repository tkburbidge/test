CREATE TABLE [dbo].[SignaturePackageDocument]
(
[SignaturePackageDocumentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SignaturePackageID] [uniqueidentifier] NOT NULL,
[SourceType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DocumentType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DocuSignTemplateID] [uniqueidentifier] NULL,
[Signers] [int] NULL,
[RequirementRule] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OrderBy] [tinyint] NOT NULL,
[FormID] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SignaturePackageDocument] ADD CONSTRAINT [PK_SignaturePackageDocument] PRIMARY KEY CLUSTERED  ([SignaturePackageDocumentID], [AccountID]) ON [PRIMARY]
GO
