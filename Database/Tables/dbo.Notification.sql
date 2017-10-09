CREATE TABLE [dbo].[Notification]
(
[NotificationID] [int] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Type] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Category] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Level] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Notification] ADD CONSTRAINT [PK_Notification_1] PRIMARY KEY CLUSTERED  ([NotificationID]) ON [PRIMARY]
GO
