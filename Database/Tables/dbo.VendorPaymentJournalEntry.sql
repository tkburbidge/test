CREATE TABLE [dbo].[VendorPaymentJournalEntry]
(
[JournalEntryID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[TransactionID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ObjectName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ReportOn1099] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[VendorPaymentJournalEntry] ADD CONSTRAINT [PK_VendorPaymentJournalEntry] PRIMARY KEY CLUSTERED  ([JournalEntryID], [AccountID]) ON [PRIMARY]
GO
