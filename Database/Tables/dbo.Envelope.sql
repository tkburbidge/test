CREATE TABLE [dbo].[Envelope]
(
[EnvelopeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SentDate] [date] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Status] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DocuSignEnvelopeID] [uniqueidentifier] NULL,
[SignedDocumentID] [uniqueidentifier] NULL,
[UpdatedTime] [datetime] NOT NULL,
[SignaturePackageID] [uniqueidentifier] NULL,
[ExpireWarnDays] [int] NULL,
[EnableReminders] [bit] NOT NULL,
[ReminderDelayDays] [int] NULL,
[ReminderFrequencyDays] [int] NULL,
[ExpirationDate] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Envelope] ADD CONSTRAINT [PK_Envelope] PRIMARY KEY CLUSTERED  ([EnvelopeID], [AccountID]) ON [PRIMARY]
GO
