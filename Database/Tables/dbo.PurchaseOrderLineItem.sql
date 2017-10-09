CREATE TABLE [dbo].[PurchaseOrderLineItem]
(
[PurchaseOrderLineItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PurchaseOrderID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OrderBy] [int] NOT NULL,
[Description] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
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
ALTER TABLE [dbo].[PurchaseOrderLineItem] ADD CONSTRAINT [PK_PurchaseOrderItem] PRIMARY KEY CLUSTERED  ([PurchaseOrderLineItemID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PurchaseOrderLineItem] WITH NOCHECK ADD CONSTRAINT [FK_PurchaseOrderItem_PurchaseOrder] FOREIGN KEY ([PurchaseOrderID], [AccountID]) REFERENCES [dbo].[PurchaseOrder] ([PurchaseOrderID], [AccountID])
GO
ALTER TABLE [dbo].[PurchaseOrderLineItem] NOCHECK CONSTRAINT [FK_PurchaseOrderItem_PurchaseOrder]
GO
