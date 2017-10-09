CREATE TABLE [dbo].[Invoice]
(
[InvoiceID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[VendorID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NULL,
[BatchID] [uniqueidentifier] NULL,
[Number] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[InvoiceDate] [date] NOT NULL,
[DueDate] [date] NOT NULL,
[ReceivedDate] [date] NOT NULL,
[AccountingDate] [date] NOT NULL,
[Notes] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Total] [money] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PaymentStatus] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SummaryVendorID] [uniqueidentifier] NULL,
[Credit] [bit] NOT NULL,
[PostingBatchID] [uniqueidentifier] NULL,
[IntegrationPartnerID] [int] NULL,
[HoldDate] [date] NULL,
[ExpenseTypeID] [uniqueidentifier] NOT NULL,
[CreatedByPersonID] [uniqueidentifier] NOT NULL,
[CurrentWorkflowGroupID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Invoice] ADD CONSTRAINT [PK_Invoice] PRIMARY KEY CLUSTERED  ([InvoiceID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Invoice_AccountingDate] ON [dbo].[Invoice] ([AccountingDate]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Invoice_BatchID] ON [dbo].[Invoice] ([BatchID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Invoice_PostingBatchID] ON [dbo].[Invoice] ([PostingBatchID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Invoice_PropertyID] ON [dbo].[Invoice] ([PropertyID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Invoice_SummaryVendor] ON [dbo].[Invoice] ([SummaryVendorID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Invoice_VendorID] ON [dbo].[Invoice] ([VendorID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Invoice] WITH NOCHECK ADD CONSTRAINT [FK_Invoice_Vendor] FOREIGN KEY ([VendorID], [AccountID]) REFERENCES [dbo].[Vendor] ([VendorID], [AccountID])
GO
ALTER TABLE [dbo].[Invoice] NOCHECK CONSTRAINT [FK_Invoice_Vendor]
GO
