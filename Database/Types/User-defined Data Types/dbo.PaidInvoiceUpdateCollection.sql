CREATE TYPE [dbo].[PaidInvoiceUpdateCollection] AS TABLE
(
[InvoiceLineItemID] [uniqueidentifier] NULL,
[OrderBy] [int] NULL,
[GLAccountID] [uniqueidentifier] NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Report1099] [bit] NULL,
[IsReplacementReserve] [bit] NULL
)
GO
