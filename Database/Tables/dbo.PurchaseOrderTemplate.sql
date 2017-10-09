CREATE TABLE [dbo].[PurchaseOrderTemplate]
(
[PurchaseOrderTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RecurringItemID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NULL,
[VendorID] [uniqueidentifier] NOT NULL,
[CreatedByPersonID] [uniqueidentifier] NOT NULL,
[Total] [money] NOT NULL,
[Shipping] [money] NOT NULL,
[Discount] [money] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Notes] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AutoGeneratePurchaseOrderNumber] [bit] NULL,
[ExpenseTypeID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PurchaseOrderTemplate] ADD CONSTRAINT [PK_PurchaseOrderTemplate] PRIMARY KEY CLUSTERED  ([PurchaseOrderTemplateID], [AccountID]) ON [PRIMARY]
GO
