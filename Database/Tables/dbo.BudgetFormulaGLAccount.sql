CREATE TABLE [dbo].[BudgetFormulaGLAccount]
(
[BudgetFormulaGLAccountID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[BudgetFormulaID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[Percent] [decimal] (18, 0) NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BudgetFormulaGLAccount] ADD CONSTRAINT [PK_BudgetFormulaGLAccount] PRIMARY KEY CLUSTERED  ([BudgetFormulaGLAccountID], [AccountID]) ON [PRIMARY]
GO
