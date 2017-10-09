CREATE TABLE [dbo].[RecurringReportBatch]
(
[RecurringReportBatchID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ReportBatchID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FromObjectID] [uniqueidentifier] NOT NULL,
[FromObjectType] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RecurringReportBatch] ADD CONSTRAINT [PK_RecurringReportBatch] PRIMARY KEY CLUSTERED  ([RecurringReportBatchID], [AccountID]) ON [PRIMARY]
GO
