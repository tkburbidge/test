CREATE TABLE [dbo].[JournalEntryNote]
(
[JournalEntryNoteID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[TransactionGroupID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Activity] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Timestamp] [datetime] NOT NULL CONSTRAINT [DF_JournalEntryNote_Timestamp] DEFAULT (getutcdate())
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[JournalEntryNote] ADD CONSTRAINT [PK_JournalEntryNote] PRIMARY KEY CLUSTERED  ([JournalEntryNoteID], [AccountID]) ON [PRIMARY]
GO
