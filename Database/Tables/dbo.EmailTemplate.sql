CREATE TABLE [dbo].[EmailTemplate]
(
[EmailTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Subject] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Body] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PropertyOrGroupID] [uniqueidentifier] NOT NULL,
[CreatedByPersonID] [uniqueidentifier] NOT NULL,
[LastModified] [date] NOT NULL,
[IsArchived] [bit] NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsSystem] [bit] NOT NULL,
[IsTemporary] [bit] NOT NULL,
[SendingMethod] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NotificationID] [int] NULL,
[SMSBody] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[EmailTemplate] ADD CONSTRAINT [PK_EmailTemplate] PRIMARY KEY CLUSTERED  ([EmailTemplateID], [AccountID]) ON [PRIMARY]
GO
