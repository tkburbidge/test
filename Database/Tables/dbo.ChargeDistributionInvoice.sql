CREATE TABLE [dbo].[ChargeDistributionInvoice]
(
[ChargeDistributionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[InvoiceID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ChargeDistributionInvoice] ADD CONSTRAINT [PK_ChargeDistributionInvoice] PRIMARY KEY CLUSTERED  ([ChargeDistributionID], [AccountID], [InvoiceID]) ON [PRIMARY]
GO
