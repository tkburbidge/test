CREATE TABLE [dbo].[RecurringEvent]
(
[RecurringEventID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Title] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Location] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[StartDate] [datetime] NULL,
[EndDate] [date] NOT NULL,
[Frequency] [int] NOT NULL,
[DaysOfWeek] [int] NOT NULL,
[MonthlyInterval] [int] NOT NULL,
[EveryXDays] [int] NOT NULL,
[DaysOfMonth] [int] NOT NULL,
[Duration] [int] NOT NULL,
[IsAllDayEvent] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RecurringEvent] ADD CONSTRAINT [PK_RecurringEvent] PRIMARY KEY CLUSTERED  ([RecurringEventID], [AccountID]) ON [PRIMARY]
GO
