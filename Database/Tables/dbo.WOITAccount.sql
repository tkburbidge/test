CREATE TABLE [dbo].[WOITAccount]
(
[WOITAccountID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Notes] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsTransactionable] [bit] NOT NULL,
[IsInvoiceable] [bit] NOT NULL,
[IsWorkOrderable] [bit] NOT NULL,
[BillingAccountID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WOITAccount] ADD CONSTRAINT [PK_WOITAccount] PRIMARY KEY CLUSTERED  ([WOITAccountID], [AccountID]) ON [PRIMARY]
GO
