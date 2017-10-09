CREATE TABLE [dbo].[NotificationProperty]
(
[NotificationPropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[NotificationID] [int] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[NotificationProperty] ADD CONSTRAINT [PK_NotificationProperty] PRIMARY KEY CLUSTERED  ([NotificationPropertyID], [AccountID]) ON [PRIMARY]
GO
