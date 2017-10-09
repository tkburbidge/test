CREATE TABLE [dbo].[AffordableSubmissionMessage]
(
[AffordableSubmissionMessageID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AffordableSubmissionID] [uniqueidentifier] NOT NULL,
[Message] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCreated] [datetime] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableSubmissionMessage] ADD CONSTRAINT [PK__Affordab__BB7C7E16AA2B6FDA] PRIMARY KEY CLUSTERED  ([AffordableSubmissionMessageID]) ON [PRIMARY]
GO
