CREATE TYPE [dbo].[InvoiceTemplatePostData] AS TABLE
(
[RecurringItemID] [uniqueidentifier] NULL,
[InvoiceNumber] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)
GO
