CREATE TABLE [dbo].[PositivePayFileBankAccount]
(
[PositivePayFileBankAccountID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PositivePayFileID] [uniqueidentifier] NOT NULL,
[BankAccountID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PositivePayFileBankAccount] ADD CONSTRAINT [PK_PositivePayFileBankAccount] PRIMARY KEY CLUSTERED  ([PositivePayFileBankAccountID], [AccountID]) ON [PRIMARY]
GO
