CREATE TABLE [dbo].[UserActivity]
(
[UserActivityID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UserID] [uniqueidentifier] NOT NULL,
[DateCreated] [datetime] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Count] [int] NOT NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UserActivity] ADD CONSTRAINT [PK_UserActivity] PRIMARY KEY CLUSTERED  ([UserActivityID], [AccountID]) ON [PRIMARY]
GO
