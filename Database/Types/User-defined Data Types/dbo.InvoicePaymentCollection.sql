CREATE TYPE [dbo].[InvoicePaymentCollection] AS TABLE
(
[VendorID] [uniqueidentifier] NULL,
[InvoiceID] [uniqueidentifier] NULL,
[AmountToPay] [money] NULL,
[SummaryVendor] [bit] NULL
)
GO
