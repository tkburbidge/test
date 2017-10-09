CREATE TABLE [dbo].[EmailRecipient]
(
[EmailRecipientID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[EmailJobID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NULL,
[EmailStatus] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EmailErrorMessage] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateCreated] [datetime] NULL,
[DateProcessed] [datetime] NULL,
[DateSent] [datetime] NULL,
[UpdateGuid] [uniqueidentifier] NULL,
[ErrorCount] [int] NOT NULL,
[Subject] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Body] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SMSBody] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SendText] [bit] NULL,
[SendEmail] [bit] NULL,
[TextStatus] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TextErrorMessage] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[EmailRecipient] ADD CONSTRAINT [PK_EmailRecipient] PRIMARY KEY CLUSTERED  ([EmailRecipientID], [AccountID]) ON [PRIMARY]
GO
