CREATE TABLE [dbo].[MessageJobTemplate]
(
[MessageJobTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[EmailTemplateID] [uniqueidentifier] NOT NULL,
[MessageEventType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DayOffset] [int] NOT NULL,
[PersonCreatedID] [uniqueidentifier] NOT NULL,
[IsArchived] [bit] NOT NULL,
[PropertyOrGroupID] [uniqueidentifier] NOT NULL,
[MainContactsOnly] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[MessageJobTemplate] ADD CONSTRAINT [PK_MessageJobTemplate] PRIMARY KEY CLUSTERED  ([MessageJobTemplateID], [AccountID]) ON [PRIMARY]
GO
