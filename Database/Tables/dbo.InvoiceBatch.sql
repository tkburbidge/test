CREATE TABLE [dbo].[InvoiceBatch]
(
[InvoiceID] [uniqueidentifier] NOT NULL,
[BatchID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[InvoiceBatch] ADD CONSTRAINT [PK_InvoiceBatch] PRIMARY KEY CLUSTERED  ([InvoiceID], [BatchID], [AccountID]) ON [PRIMARY]
GO
