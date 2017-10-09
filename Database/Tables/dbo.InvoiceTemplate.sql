CREATE TABLE [dbo].[InvoiceTemplate]
(
[InvoiceTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RecurringItemID] [uniqueidentifier] NOT NULL,
[VendorID] [uniqueidentifier] NOT NULL,
[Total] [money] NOT NULL,
[Credit] [bit] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Notes] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[ExpenseTypeID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[InvoiceTemplate] ADD CONSTRAINT [PK_InvoiceTemplate] PRIMARY KEY CLUSTERED  ([InvoiceTemplateID], [AccountID]) ON [PRIMARY]
GO
