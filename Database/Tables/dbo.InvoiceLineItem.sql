CREATE TABLE [dbo].[InvoiceLineItem]
(
[InvoiceLineItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[TransactionID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ObjectID] [uniqueidentifier] NULL,
[InvoiceID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[OrderBy] [tinyint] NOT NULL,
[Quantity] [decimal] (8, 2) NOT NULL,
[UnitPrice] [money] NOT NULL,
[PaymentStatus] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Taxable] [bit] NOT NULL,
[TaxRateGroupID] [uniqueidentifier] NULL,
[SalesTaxAmount] [money] NOT NULL,
[Report1099] [bit] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[IsReplacementReserve] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[InvoiceLineItem] ADD CONSTRAINT [PK_InvoiceLineItem] PRIMARY KEY CLUSTERED  ([InvoiceLineItemID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_InvoiceLineItem_GLAccount] ON [dbo].[InvoiceLineItem] ([GLAccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_InvoiceLineItem_ObjectID] ON [dbo].[InvoiceLineItem] ([ObjectID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_InvoiceLineItem_Transaction] ON [dbo].[InvoiceLineItem] ([TransactionID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[InvoiceLineItem] WITH NOCHECK ADD CONSTRAINT [FK_InvoiceLineItem_Invoice] FOREIGN KEY ([InvoiceID], [AccountID]) REFERENCES [dbo].[Invoice] ([InvoiceID], [AccountID])
GO
ALTER TABLE [dbo].[InvoiceLineItem] NOCHECK CONSTRAINT [FK_InvoiceLineItem_Invoice]
GO
