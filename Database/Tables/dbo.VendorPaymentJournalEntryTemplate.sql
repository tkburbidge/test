CREATE TABLE [dbo].[VendorPaymentJournalEntryTemplate]
(
[VendorPaymentJournalEntryTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[VendorPaymentTemplateID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[Amount] [money] NOT NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ObjectName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ReportOn1099] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[VendorPaymentJournalEntryTemplate] ADD CONSTRAINT [PK_VendorPaymentJournalEntryTemplate] PRIMARY KEY CLUSTERED  ([VendorPaymentJournalEntryTemplateID], [AccountID]) ON [PRIMARY]
GO
