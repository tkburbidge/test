CREATE TABLE [dbo].[InvoiceLineItemTemplate]
(
[InvoiceLineItemTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[InvoiceTemplateID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Quantity] [decimal] (18, 0) NOT NULL,
[UnitPrice] [money] NOT NULL,
[Total] [money] NOT NULL,
[Taxable] [bit] NOT NULL,
[TaxRateGroupID] [uniqueidentifier] NULL,
[SalesTaxAmount] [money] NOT NULL,
[OrderBy] [int] NOT NULL,
[ObjectName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Report1099] [bit] NOT NULL,
[IsReplacementReserve] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[InvoiceLineItemTemplate] ADD CONSTRAINT [PK_InvoiceLineItemTemplate] PRIMARY KEY CLUSTERED  ([InvoiceLineItemTemplateID], [AccountID]) ON [PRIMARY]
GO
