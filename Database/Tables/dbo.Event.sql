CREATE TABLE [dbo].[Event]
(
[EventID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RecurringEventID] [uniqueidentifier] NULL,
[Title] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Location] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Start] [datetime] NOT NULL,
[End] [datetime] NOT NULL,
[IsAllDayEvent] [bit] NOT NULL,
[IsPortalVisible] [bit] NOT NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[Event] ADD CONSTRAINT [PK_Event] PRIMARY KEY CLUSTERED  ([EventID], [AccountID]) ON [PRIMARY]
GO
