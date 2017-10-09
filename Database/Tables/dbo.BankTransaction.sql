CREATE TABLE [dbo].[BankTransaction]
(
[BankTransactionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[BankTransactionCategoryID] [uniqueidentifier] NOT NULL,
[BankReconciliationID] [uniqueidentifier] NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ClearedDate] [date] NULL CONSTRAINT [DF_BankTransaction_ClearedDate] DEFAULT (NULL),
[ReferenceNumber] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[QueuedForPrinting] [bit] NOT NULL,
[CheckPrintedDate] [date] NULL,
[BankFileID] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BankTransaction] ADD CONSTRAINT [PK_BankTransaction] PRIMARY KEY CLUSTERED  ([BankTransactionID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_BankTransaction_BankTransactionCategoryID] ON [dbo].[BankTransaction] ([BankTransactionCategoryID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_BankTransaction_ClearedDate] ON [dbo].[BankTransaction] ([ClearedDate]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_BankTransaction_ObjectID] ON [dbo].[BankTransaction] ([ObjectID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_BankTransaction_ReferenceNumber] ON [dbo].[BankTransaction] ([ReferenceNumber]) ON [PRIMARY]
GO
