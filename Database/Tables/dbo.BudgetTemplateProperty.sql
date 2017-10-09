CREATE TABLE [dbo].[BudgetTemplateProperty]
(
[BudgetTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BudgetTemplateProperty] ADD CONSTRAINT [PK_BudgetTemplateProperty] PRIMARY KEY CLUSTERED  ([BudgetTemplateID], [AccountID], [PropertyID]) ON [PRIMARY]
GO
