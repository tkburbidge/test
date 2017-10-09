CREATE TABLE [dbo].[InventoryItem]
(
[InventoryItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LedgerItemID] [uniqueidentifier] NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[CategoryPickListItemID] [uniqueidentifier] NULL,
[PurchaseInvoiceLineItemID] [uniqueidentifier] NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Notes] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SerialNumber] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Make] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Model] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ColorFinish] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Size] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Cost] [money] NULL,
[PuchaseDate] [date] NULL,
[RetiredDate] [date] NULL,
[RetiredPickListItemID] [uniqueidentifier] NULL,
[RetiredByPersonID] [uniqueidentifier] NULL,
[WarrantyExpirationDate] [date] NULL,
[GLAccountID] [uniqueidentifier] NULL,
[VendorID] [uniqueidentifier] NULL,
[IsNew] [bit] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[InventoryItem] ADD CONSTRAINT [PK_InventoryItem] PRIMARY KEY CLUSTERED  ([InventoryItemID], [AccountID]) ON [PRIMARY]
GO
