CREATE TABLE [dbo].[BudgetFormula]
(
[BudgetFormulaID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[YearBudgetID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BudgetFormula] ADD CONSTRAINT [PK_BudgetFormula] PRIMARY KEY CLUSTERED  ([BudgetFormulaID], [AccountID]) ON [PRIMARY]
GO
