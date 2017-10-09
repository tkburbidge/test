CREATE TABLE [dbo].[Bulletin]
(
[BulletinID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Type] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Date] [date] NOT NULL,
[Html] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[Bulletin] ADD CONSTRAINT [PK_Notification] PRIMARY KEY CLUSTERED  ([BulletinID], [AccountID]) ON [PRIMARY]
GO
