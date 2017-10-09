CREATE TABLE [dbo].[JournalEntryTemplate]
(
[JournalEntryTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RecurringItemID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[Description] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [money] NOT NULL,
[AccountingBasis] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OrderBy] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[JournalEntryTemplate] ADD CONSTRAINT [PK_JournalEntryTemplate] PRIMARY KEY CLUSTERED  ([JournalEntryTemplateID], [AccountID]) ON [PRIMARY]
GO
