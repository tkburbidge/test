CREATE TYPE [dbo].[PaymentInvoiceCreditTransactionCollection] AS TABLE
(
[PaymentInvoiceCreditTransactionID] [uniqueidentifier] NOT NULL,
[PaymentID] [uniqueidentifier] NOT NULL,
[TransactionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
)
GO
