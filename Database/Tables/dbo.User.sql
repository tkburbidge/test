CREATE TABLE [dbo].[User]
(
[UserID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SecurityRoleID] [uniqueidentifier] NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Username] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Password] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LastLoginDate] [datetime] NULL,
[SessionActive] [bit] NOT NULL,
[IsResident] [bit] NOT NULL,
[IsEmailVerified] [bit] NOT NULL,
[IsDisabled] [bit] NOT NULL,
[BoardRoomLeftColumn] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[BoardRoomRightColumn] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SelectedPropertyID] [uniqueidentifier] NULL,
[SelectedPropertyOrGroupID] [uniqueidentifier] NULL,
[CalendarColor] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ShowUpdates] [bit] NOT NULL,
[TimeZoneID] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ReceiveWorkorderAssignedNotifications] [bit] NOT NULL,
[DefaultBoardRoomSelectedPropertyOrGroupID] [uniqueidentifier] NULL,
[SelectedCalendarIDs] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EmailSignature] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SearchLastSelectedProperty] [bit] NOT NULL,
[ShowEfficiencyBar] [bit] NOT NULL,
[LastPasswordResetDate] [date] NOT NULL,
[DefaultReportExportFormat] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL CONSTRAINT [DF__tmp_ms_xx__Defau__5D2D6794] DEFAULT (NULL),
[ResetPasswordID] [uniqueidentifier] NULL,
[ResetPasswordDate] [datetime] NULL,
[ShowPopUpNotifications] [bit] NOT NULL,
[SecurityQuestion1] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SecurityQuestion1Answer] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SecurityQuestion2] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SecurityQuestion2Answer] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[WorkflowGroupID] [uniqueidentifier] NULL,
[HiddenReports] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LanguagePreference] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ComplianceCenterModules] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ComplianceCenterPortfolioModules] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TracsPassword] [nvarchar] (24) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TracsUserID] [nvarchar] (24) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FailedLoginCount] [int] NOT NULL CONSTRAINT [DF__User__FailedLogi__00CBA98C] DEFAULT ((0)),
[LastFailedLoginAttempt] [datetime] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[User] ADD CONSTRAINT [PK_User] PRIMARY KEY CLUSTERED  ([UserID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[User] WITH NOCHECK ADD CONSTRAINT [FK_User_Person] FOREIGN KEY ([PersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
ALTER TABLE [dbo].[User] WITH NOCHECK ADD CONSTRAINT [FK_User_SecurityRole] FOREIGN KEY ([SecurityRoleID], [AccountID]) REFERENCES [dbo].[SecurityRole] ([SecurityRoleID], [AccountID])
GO
ALTER TABLE [dbo].[User] NOCHECK CONSTRAINT [FK_User_Person]
GO
ALTER TABLE [dbo].[User] NOCHECK CONSTRAINT [FK_User_SecurityRole]
GO
