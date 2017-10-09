CREATE TABLE [dbo].[PropertyAccountingPeriod]
(
[PropertyAccountingPeriodID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AccountingPeriodID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[LeaseExpirationLimit] [smallint] NULL,
[LeaseExpirationNotes] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Closed] [bit] NOT NULL,
[RecurringChargesPosted] [bit] NOT NULL,
[LateFeesAccessed] [bit] NOT NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NOT NULL,
[AutoPostedRecurringChargesErrors] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyAccountingPeriod] ADD CONSTRAINT [PK_PropertyAccountingPeriod] PRIMARY KEY CLUSTERED  ([PropertyAccountingPeriodID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PropertyAccountingPeriod_AP] ON [dbo].[PropertyAccountingPeriod] ([AccountingPeriodID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PropertyAccountingPeriod_Property] ON [dbo].[PropertyAccountingPeriod] ([PropertyID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyAccountingPeriod] WITH NOCHECK ADD CONSTRAINT [FK_PropertyAccountingPeriod_AccountingPeriod] FOREIGN KEY ([AccountingPeriodID], [AccountID]) REFERENCES [dbo].[AccountingPeriod] ([AccountingPeriodID], [AccountID])
GO
ALTER TABLE [dbo].[PropertyAccountingPeriod] NOCHECK CONSTRAINT [FK_PropertyAccountingPeriod_AccountingPeriod]
GO
