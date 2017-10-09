CREATE TABLE [dbo].[BudgetTemplateGroupGLAccount]
(
[BudgetTemplateGroupGLAccountID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[BudgetTemplateGroupID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[IsEditable] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BudgetTemplateGroupGLAccount] ADD CONSTRAINT [PK_BudgetTemplateGroupGLAccount] PRIMARY KEY CLUSTERED  ([BudgetTemplateGroupGLAccountID], [AccountID]) ON [PRIMARY]
GO
