CREATE TABLE [dbo].[UserPassword]
(
[UserPasswordID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UserID] [uniqueidentifier] NOT NULL,
[Password] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Timestamp] [datetime] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UserPassword] ADD CONSTRAINT [PK_UserPassword] PRIMARY KEY CLUSTERED  ([UserPasswordID], [AccountID]) ON [PRIMARY]
GO
