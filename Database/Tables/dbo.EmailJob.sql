CREATE TABLE [dbo].[EmailJob]
(
[EmailJobID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[EmailTemplateID] [uniqueidentifier] NULL,
[Status] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Subject] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Body] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LastSent] [datetime] NULL,
[DateTimeCreatedUTC] [datetime] NULL,
[PersonType] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CreatedByPersonID] [uniqueidentifier] NOT NULL,
[SendingMethod] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SMSBody] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NotificationID] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[EmailJob] ADD CONSTRAINT [PK_EmailJob] PRIMARY KEY CLUSTERED  ([EmailJobID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_EmailJob_DateTimeCreatedUTC_Status] ON [dbo].[EmailJob] ([DateTimeCreatedUTC], [Status]) ON [PRIMARY]
GO
