CREATE TYPE [dbo].[PaymentTransactionCollection] AS TABLE
(
[TransactionID] [uniqueidentifier] NOT NULL,
[PaymentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
)
GO
