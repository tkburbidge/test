CREATE TABLE [dbo].[RecurringReportBatchParameter]
(
[RecurringReportBatchParameterID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RecurringReportBatchID] [uniqueidentifier] NOT NULL,
[ReportBatchReportID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Offset] [int] NOT NULL,
[Type] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RecurringReportBatchParameter] ADD CONSTRAINT [PK_RecurringReportBatchParameter] PRIMARY KEY CLUSTERED  ([RecurringReportBatchParameterID], [AccountID]) ON [PRIMARY]
GO
