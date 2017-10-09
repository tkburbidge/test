CREATE TABLE [dbo].[ActivityLog]
(
[ActivityLogID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ActivityLogType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ModifiedByPersonID] [uniqueidentifier] NULL,
[ObjectName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ObjectID] [uniqueidentifier] NULL,
[PropertyID] [uniqueidentifier] NULL,
[Activity] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Timestamp] [datetime] NOT NULL,
[ExceptionName] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ExceptionCaught] [bit] NOT NULL,
[Exception] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AltObjectID] [uniqueidentifier] NULL,
[IntegrationPartnerID] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[ActivityLog] ADD CONSTRAINT [PK_ActivityLog] PRIMARY KEY CLUSTERED  ([ActivityLogID], [AccountID]) ON [PRIMARY]
GO
