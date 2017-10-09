CREATE TABLE [dbo].[PaymentInvoiceCreditTransaction]
(
[PaymentInvoiceCreditTransactionID] [uniqueidentifier] NOT NULL,
[PaymentID] [uniqueidentifier] NOT NULL,
[TransactionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PaymentInvoiceCreditTransaction] ADD CONSTRAINT [PK_PaymentInvoiceCreditTransaction] PRIMARY KEY CLUSTERED  ([PaymentInvoiceCreditTransactionID], [AccountID]) ON [PRIMARY]
GO
