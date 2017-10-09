CREATE TABLE [dbo].[AccountingPeriod]
(
[AccountingPeriodID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AccountingPeriod] ADD CONSTRAINT [PK_AccountingPeriod_1] PRIMARY KEY CLUSTERED  ([AccountingPeriodID], [AccountID]) ON [PRIMARY]
GO
