CREATE TABLE [dbo].[CertificationMessageStatus]
(
[CertificationMessageStatusID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CertificationMessageID] [uniqueidentifier] NOT NULL,
[DateCreated] [datetime] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Status] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Notes] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Message] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[CertificationMessageStatus] ADD CONSTRAINT [PK_CertificationMessageStatus] PRIMARY KEY CLUSTERED  ([CertificationMessageStatusID], [AccountID]) ON [PRIMARY]
GO
