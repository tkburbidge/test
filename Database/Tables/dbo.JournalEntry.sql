CREATE TABLE [dbo].[JournalEntry]
(
[JournalEntryID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[TransactionID] [uniqueidentifier] NOT NULL,
[Amount] [money] NOT NULL,
[AccountingBasis] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AccountingBookID] [uniqueidentifier] NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[JournalEntry] ADD CONSTRAINT [PK_JournalEntry] PRIMARY KEY CLUSTERED  ([JournalEntryID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_JournalEntry_AccountingBasis] ON [dbo].[JournalEntry] ([AccountingBasis]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_JournalEntry_GLAccountID] ON [dbo].[JournalEntry] ([GLAccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_JournalEntry_TransactionID] ON [dbo].[JournalEntry] ([TransactionID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[JournalEntry] WITH NOCHECK ADD CONSTRAINT [FK_JournalEntry_GLAccount] FOREIGN KEY ([GLAccountID], [AccountID]) REFERENCES [dbo].[GLAccount] ([GLAccountID], [AccountID])
GO
ALTER TABLE [dbo].[JournalEntry] WITH NOCHECK ADD CONSTRAINT [FK_JournalEntry_Transaction] FOREIGN KEY ([TransactionID], [AccountID]) REFERENCES [dbo].[Transaction] ([TransactionID], [AccountID])
GO
ALTER TABLE [dbo].[JournalEntry] NOCHECK CONSTRAINT [FK_JournalEntry_GLAccount]
GO
ALTER TABLE [dbo].[JournalEntry] NOCHECK CONSTRAINT [FK_JournalEntry_Transaction]
GO
