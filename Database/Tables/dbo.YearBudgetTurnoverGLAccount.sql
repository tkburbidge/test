CREATE TABLE [dbo].[YearBudgetTurnoverGLAccount]
(
[YearBudgetTurnoverGLAccountID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[YearBudgetID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[CostPerTurnType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CostPerTurnOverride] [money] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[YearBudgetTurnoverGLAccount] ADD CONSTRAINT [PK_YearBudgetTurnoverGLAccount] PRIMARY KEY CLUSTERED  ([YearBudgetTurnoverGLAccountID], [AccountID]) ON [PRIMARY]
GO
