CREATE TABLE [dbo].[Budget]
(
[BudgetID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[PropertyAccountingPeriodID] [uniqueidentifier] NOT NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AccrualBudget] [money] NULL,
[CashBudget] [money] NULL,
[NetMonthlyTotalAccrual] [money] NULL,
[NetMonthlyTotalCash] [money] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Budget] ADD CONSTRAINT [PK_Budget] PRIMARY KEY CLUSTERED  ([BudgetID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Budget_GLAccount] ON [dbo].[Budget] ([GLAccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Budget_GLA_PAP] ON [dbo].[Budget] ([GLAccountID], [PropertyAccountingPeriodID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Budget_PropAcc] ON [dbo].[Budget] ([PropertyAccountingPeriodID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Budget] WITH NOCHECK ADD CONSTRAINT [FK_Budget_GLAccount] FOREIGN KEY ([GLAccountID], [AccountID]) REFERENCES [dbo].[GLAccount] ([GLAccountID], [AccountID])
GO
ALTER TABLE [dbo].[Budget] NOCHECK CONSTRAINT [FK_Budget_GLAccount]
GO
