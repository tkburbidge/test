CREATE TABLE [dbo].[BankAccountProperty]
(
[BankAccountPropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[BankAccountID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BankAccountProperty] ADD CONSTRAINT [PK_BankAccountProperty] PRIMARY KEY CLUSTERED  ([BankAccountPropertyID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BankAccountProperty] WITH NOCHECK ADD CONSTRAINT [FK_BankAccountProperty_BankAccount] FOREIGN KEY ([BankAccountID], [AccountID]) REFERENCES [dbo].[BankAccount] ([BankAccountID], [AccountID])
GO
ALTER TABLE [dbo].[BankAccountProperty] NOCHECK CONSTRAINT [FK_BankAccountProperty_BankAccount]
GO
