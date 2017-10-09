CREATE TABLE [dbo].[LoginTracking]
(
[LoginTrackingID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Login] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IPAddress] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LoginTime] [datetime] NOT NULL,
[LogoutTime] [datetime] NULL,
[LogoutMethod] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PasswordFailures] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LoginTracking] ADD CONSTRAINT [PK_LoginTracking] PRIMARY KEY CLUSTERED  ([LoginTrackingID], [AccountID]) ON [PRIMARY]
GO
