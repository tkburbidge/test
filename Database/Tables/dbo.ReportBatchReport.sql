CREATE TABLE [dbo].[ReportBatchReport]
(
[ReportBatchReportID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ReportBatchID] [uniqueidentifier] NOT NULL,
[ReportName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OrderBy] [smallint] NOT NULL,
[QuickReportReportBatchID] [uniqueidentifier] NULL,
[DisplayName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CustomReportID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ReportBatchReport] ADD CONSTRAINT [PK_ReportBatchReport] PRIMARY KEY CLUSTERED  ([ReportBatchReportID], [AccountID]) ON [PRIMARY]
GO
