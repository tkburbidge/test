CREATE TABLE [dbo].[AlternateBudget]
(
[AlternateBudgetID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[YearBudgetID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[PropertyAccountingPeriodID] [uniqueidentifier] NOT NULL,
[Amount] [money] NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AlternateBudget] ADD CONSTRAINT [PK_AlternateBudget] PRIMARY KEY CLUSTERED  ([AlternateBudgetID], [AccountID]) ON [PRIMARY]
GO
