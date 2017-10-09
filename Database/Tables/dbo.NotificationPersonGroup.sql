CREATE TABLE [dbo].[NotificationPersonGroup]
(
[NotificationPersonGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[NotificationID] [int] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PropertyID] [uniqueidentifier] NULL,
[IsEmailSubscribed] [bit] NOT NULL,
[IsSMSSubscribed] [bit] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[NotificationPersonGroup] ADD CONSTRAINT [PK_NotificationPersonGroup] PRIMARY KEY CLUSTERED  ([NotificationPersonGroupID], [AccountID]) ON [PRIMARY]
GO
