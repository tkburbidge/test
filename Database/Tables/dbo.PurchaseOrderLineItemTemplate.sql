CREATE TABLE [dbo].[PurchaseOrderLineItemTemplate]
(
[PurchaseOrderLineItemTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PurchaseOrderTemplateID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ObjectName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OrderBy] [int] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Quantity] [decimal] (8, 2) NOT NULL,
[UnitPrice] [money] NOT NULL,
[Total] [money] NOT NULL,
[GLTotal] [money] NOT NULL,
[TaxRateGroupID] [uniqueidentifier] NULL,
[SalesTaxAmount] [money] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[IsReplacementReserve] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PurchaseOrderLineItemTemplate] ADD CONSTRAINT [PK_PurchaseOrderLineItemTemplate] PRIMARY KEY CLUSTERED  ([PurchaseOrderLineItemTemplateID], [AccountID]) ON [PRIMARY]
GO
