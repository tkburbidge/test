CREATE TABLE [dbo].[AchFileBankTransaction]
(
[AchFileBankTransactionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AchFileID] [uniqueidentifier] NOT NULL,
[BankTransactionID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AchFileBankTransaction] ADD CONSTRAINT [PK_AchFileBankTransaction] PRIMARY KEY CLUSTERED  ([AchFileBankTransactionID], [AccountID]) ON [PRIMARY]
GO
