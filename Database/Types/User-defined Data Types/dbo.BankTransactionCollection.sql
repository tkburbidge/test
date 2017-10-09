CREATE TYPE [dbo].[BankTransactionCollection] AS TABLE
(
[BankTransactionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[BankTransactionCategoryID] [uniqueidentifier] NOT NULL,
[BankReconciliationID] [uniqueidentifier] NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (12) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ClearedDate] [date] NULL,
[ReferenceNumber] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[QueuedForPrinting] [bit] NOT NULL,
[CheckPrintedDate] [date] NULL
)
GO
