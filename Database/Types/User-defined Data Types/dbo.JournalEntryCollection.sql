CREATE TYPE [dbo].[JournalEntryCollection] AS TABLE
(
[JournalEntryID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[TransactionID] [uniqueidentifier] NOT NULL,
[Amount] [money] NOT NULL,
[AccountingBasis] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AccountingBookID] [uniqueidentifier] NULL
)
GO
