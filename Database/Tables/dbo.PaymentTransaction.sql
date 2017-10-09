CREATE TABLE [dbo].[PaymentTransaction]
(
[TransactionID] [uniqueidentifier] NOT NULL,
[PaymentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PaymentTransaction] ADD CONSTRAINT [PK_PaymentTransaction] PRIMARY KEY CLUSTERED  ([TransactionID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PaymentTransaction_PaymentID] ON [dbo].[PaymentTransaction] ([PaymentID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PaymentTransaction] WITH NOCHECK ADD CONSTRAINT [FK_PaymentTransaction_Payment] FOREIGN KEY ([PaymentID], [AccountID]) REFERENCES [dbo].[Payment] ([PaymentID], [AccountID])
GO
ALTER TABLE [dbo].[PaymentTransaction] WITH NOCHECK ADD CONSTRAINT [FK_PaymentTransaction_Transaction] FOREIGN KEY ([TransactionID], [AccountID]) REFERENCES [dbo].[Transaction] ([TransactionID], [AccountID])
GO
ALTER TABLE [dbo].[PaymentTransaction] NOCHECK CONSTRAINT [FK_PaymentTransaction_Payment]
GO
ALTER TABLE [dbo].[PaymentTransaction] NOCHECK CONSTRAINT [FK_PaymentTransaction_Transaction]
GO
