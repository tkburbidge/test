CREATE TABLE [dbo].[AffordableExpense]
(
[AffordableExpenseID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Type] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EndDate] [date] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableExpense] ADD CONSTRAINT [PK_AffordableExpense] PRIMARY KEY CLUSTERED  ([AffordableExpenseID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableExpense] ADD CONSTRAINT [FK_AffordableExpense_Person] FOREIGN KEY ([PersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
