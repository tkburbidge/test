CREATE TABLE [dbo].[RecurringReportBatchItem]
(
[RecurringReportBatchItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RecurringReportBatchID] [uniqueidentifier] NOT NULL,
[RecurringItemID] [uniqueidentifier] NOT NULL,
[PropertyOrGroupID] [uniqueidentifier] NOT NULL,
[Time] [time] NOT NULL,
[Recipients] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RecurringReportBatchItem] ADD CONSTRAINT [PK_RecurringReportBatchItem] PRIMARY KEY CLUSTERED  ([RecurringReportBatchItemID], [AccountID]) ON [PRIMARY]
GO
