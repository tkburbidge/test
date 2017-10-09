CREATE TABLE [dbo].[Transaction]
(
[TransactionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[TransactionTypeID] [uniqueidentifier] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NULL,
[AppliesToTransactionID] [uniqueidentifier] NULL,
[ReversesTransactionID] [uniqueidentifier] NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NULL,
[TaxRateGroupID] [uniqueidentifier] NULL,
[NotVisible] [bit] NOT NULL,
[Origin] [nchar] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [money] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Note] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TransactionDate] [date] NOT NULL,
[TimeStamp] [datetime] NOT NULL,
[IsDeleted] [bit] NULL,
[PostingBatchID] [uniqueidentifier] NULL,
[ClosedDate] [date] NULL,
[TaxRateID] [uniqueidentifier] NULL,
[SalesTaxForTransactionID] [uniqueidentifier] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[Transaction] ADD CONSTRAINT [PK_Transaction] PRIMARY KEY CLUSTERED  ([TransactionID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Transaction_AppliesToTransactionID] ON [dbo].[Transaction] ([AppliesToTransactionID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Transaction_LedgerItemTypeID] ON [dbo].[Transaction] ([LedgerItemTypeID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Transaction_ObjectID] ON [dbo].[Transaction] ([ObjectID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Transaction_PersonID] ON [dbo].[Transaction] ([PersonID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Transaction_PostingBatchID] ON [dbo].[Transaction] ([PostingBatchID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Transaction_PropertyID] ON [dbo].[Transaction] ([PropertyID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Transaction_PropertyNameGroup] ON [dbo].[Transaction] ([PropertyID], [TransactionTypeID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Transaction_ReverseTransactionID] ON [dbo].[Transaction] ([ReversesTransactionID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Transaction_TransactionDate] ON [dbo].[Transaction] ([TransactionDate] DESC) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Transaction_TransactionTypeID] ON [dbo].[Transaction] ([TransactionTypeID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [[nci_wi_Transaction_C17CD092-869C-407C-8623-9F05C8D64E67]]] ON [dbo].[Transaction] ([TransactionTypeID], [AppliesToTransactionID], [PropertyID], [ReversesTransactionID], [Amount]) INCLUDE ([Description], [LedgerItemTypeID], [ObjectID], [Origin], [TransactionID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Transaction] WITH NOCHECK ADD CONSTRAINT [FK_Transaction_TransactionType] FOREIGN KEY ([TransactionTypeID], [AccountID]) REFERENCES [dbo].[TransactionType] ([TransactionTypeID], [AccountID])
GO
ALTER TABLE [dbo].[Transaction] NOCHECK CONSTRAINT [FK_Transaction_TransactionType]
GO
