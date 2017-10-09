CREATE TABLE [dbo].[BudgetTemplate]
(
[BudgetTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LastModified] [datetime] NOT NULL,
[LastModifiedByPersonID] [uniqueidentifier] NOT NULL,
[IsArchived] [bit] NOT NULL,
[SortingType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OtherIncomeGroupSortOrder] [int] NOT NULL,
[OtherExpenseGroupSortOrder] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BudgetTemplate] ADD CONSTRAINT [PK_BudgetTemplate] PRIMARY KEY CLUSTERED  ([BudgetTemplateID], [AccountID]) ON [PRIMARY]
GO
