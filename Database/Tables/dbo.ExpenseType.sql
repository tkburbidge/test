CREATE TABLE [dbo].[ExpenseType]
(
[ExpenseTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsDeleted] [bit] NOT NULL,
[Priority] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ExpenseType] ADD CONSTRAINT [PK_ExpenseType] PRIMARY KEY CLUSTERED  ([ExpenseTypeID], [AccountID]) ON [PRIMARY]
GO
