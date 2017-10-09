CREATE TABLE [dbo].[BankTransactionCategory]
(
[BankTransactionCategoryID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[TransactionTypeID] [uniqueidentifier] NOT NULL,
[Category] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Visible] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BankTransactionCategory] ADD CONSTRAINT [PK_BankTransactionCategory] PRIMARY KEY CLUSTERED  ([BankTransactionCategoryID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_BankTransactionCategory_TransactionTypeID] ON [dbo].[BankTransactionCategory] ([TransactionTypeID]) ON [PRIMARY]
GO
