CREATE TABLE [dbo].[BankTransactionTransaction]
(
[BankTransactionTransactionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[BankTransactionID] [uniqueidentifier] NOT NULL,
[TransactionID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BankTransactionTransaction] ADD CONSTRAINT [PK_BankTransactionTransaction] PRIMARY KEY CLUSTERED  ([BankTransactionTransactionID], [AccountID]) ON [PRIMARY]
GO
