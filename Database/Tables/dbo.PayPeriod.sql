CREATE TABLE [dbo].[PayPeriod]
(
[PayPeriodID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NOT NULL,
[Closed] [bit] NOT NULL,
[Notes] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PayPeriod] ADD CONSTRAINT [PK_PayPeriod] PRIMARY KEY CLUSTERED  ([PayPeriodID], [AccountID]) ON [PRIMARY]
GO
