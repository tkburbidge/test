CREATE TABLE [dbo].[BulletinVideo]
(
[BulletinVideoID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Video] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[BulletinID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BulletinVideo] ADD CONSTRAINT [PK_BulletinVideo] PRIMARY KEY CLUSTERED  ([BulletinVideoID], [AccountID]) ON [PRIMARY]
GO
