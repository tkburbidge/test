CREATE TABLE [dbo].[EventAttendee]
(
[EventAttendeeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[EventID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [varchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[EventAttendee] ADD CONSTRAINT [PK_EventAttendee] PRIMARY KEY CLUSTERED  ([EventAttendeeID], [AccountID]) ON [PRIMARY]
GO
