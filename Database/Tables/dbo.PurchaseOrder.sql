CREATE TABLE [dbo].[PurchaseOrder]
(
[PurchaseOrderID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NULL,
[InvoiceID] [uniqueidentifier] NULL,
[Number] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[VendorID] [uniqueidentifier] NOT NULL,
[CreatedByPersonID] [uniqueidentifier] NOT NULL,
[Total] [money] NOT NULL,
[Shipping] [money] NOT NULL,
[Discount] [money] NOT NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Date] [date] NULL,
[ParentPurchaseOrderID] [uniqueidentifier] NULL,
[ExpenseTypeID] [uniqueidentifier] NOT NULL,
[CurrentWorkflowGroupID] [uniqueidentifier] NULL,
[SentToVendorPersonNoteID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PurchaseOrder] ADD CONSTRAINT [PK_PurchaseOrder] PRIMARY KEY CLUSTERED  ([PurchaseOrderID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PurchaseOrder] WITH NOCHECK ADD CONSTRAINT [FK_PurchaseOrder_Invoice] FOREIGN KEY ([InvoiceID], [AccountID]) REFERENCES [dbo].[Invoice] ([InvoiceID], [AccountID])
GO
ALTER TABLE [dbo].[PurchaseOrder] NOCHECK CONSTRAINT [FK_PurchaseOrder_Invoice]
GO
