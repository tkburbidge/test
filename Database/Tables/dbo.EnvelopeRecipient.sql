CREATE TABLE [dbo].[EnvelopeRecipient]
(
[AccountID] [bigint] NOT NULL,
[EnvelopeID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Status] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SecurityToken] [uniqueidentifier] NULL,
[SentTime] [datetime] NULL,
[ReminderSentTime] [datetime] NULL,
[ExpirationWarningSentTime] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[EnvelopeRecipient] ADD CONSTRAINT [PK_EnvelopeRecipient] PRIMARY KEY CLUSTERED  ([AccountID], [EnvelopeID], [PersonID]) ON [PRIMARY]
GO
