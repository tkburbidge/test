CREATE TABLE [dbo].[ReportBatch]
(
[ReportBatchID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsQuickReport] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ReportBatch] ADD CONSTRAINT [PK_ReportBatch] PRIMARY KEY CLUSTERED  ([ReportBatchID], [AccountID]) ON [PRIMARY]
GO
