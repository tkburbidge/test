CREATE TABLE [dbo].[BudgetTemplateGroup]
(
[BudgetTemplateGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[BudgetTemplateID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Type] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsSystem] [bit] NOT NULL,
[SystemName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OrderBy] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BudgetTemplateGroup] ADD CONSTRAINT [PK_BudgetTemplateGroup] PRIMARY KEY CLUSTERED  ([BudgetTemplateGroupID], [AccountID]) ON [PRIMARY]
GO
