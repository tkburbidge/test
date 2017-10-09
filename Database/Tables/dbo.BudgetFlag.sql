CREATE TABLE [dbo].[BudgetFlag]
(
[BudgetFlagID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[BudgetID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Note] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateResolved] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BudgetFlag] ADD CONSTRAINT [PK_BudgetFlag] PRIMARY KEY CLUSTERED  ([BudgetFlagID], [AccountID]) ON [PRIMARY]
GO
