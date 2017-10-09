CREATE TABLE [dbo].[DownloadDocument]
(
[DownloadDocumentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Detail] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Status] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateCreated] [datetime] NULL,
[CreatedByPersonID] [uniqueidentifier] NULL,
[DocumentID] [uniqueidentifier] NULL,
[Size] [bigint] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[DownloadDocument] ADD CONSTRAINT [PK_DocumentDownload] PRIMARY KEY CLUSTERED  ([DownloadDocumentID], [AccountID]) ON [PRIMARY]
GO
