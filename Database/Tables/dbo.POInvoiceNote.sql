CREATE TABLE [dbo].[POInvoiceNote]
(
[POInvoiceNoteID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NULL,
[AltObjectID] [uniqueidentifier] NULL,
[AltObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Date] [date] NOT NULL,
[Status] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Notes] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Timestamp] [datetime] NOT NULL CONSTRAINT [DF_POInvoiceNote_Timestamp] DEFAULT (getutcdate()),
[IntegrationPartnerID] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[POInvoiceNote] ADD CONSTRAINT [PK_POInvoiceNote] PRIMARY KEY CLUSTERED  ([POInvoiceNoteID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [POInvoiceNote_ObjectID] ON [dbo].[POInvoiceNote] ([ObjectID], [Timestamp]) ON [PRIMARY]
GO
