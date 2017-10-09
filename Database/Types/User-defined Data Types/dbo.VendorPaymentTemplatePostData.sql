CREATE TYPE [dbo].[VendorPaymentTemplatePostData] AS TABLE
(
[RecurringItemID] [uniqueidentifier] NULL,
[Memo] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CheckNumber] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)
GO
