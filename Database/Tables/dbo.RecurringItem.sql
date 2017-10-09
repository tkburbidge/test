CREATE TABLE [dbo].[RecurringItem]
(
[RecurringItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NULL,
[Frequency] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DayToRun] [int] NOT NULL,
[ItemType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[AssignedToPersonID] [uniqueidentifier] NOT NULL,
[LastRecurringPostDate] [date] NULL,
[LastManualPostDate] [date] NULL,
[LastManualPostPersonID] [uniqueidentifier] NULL,
[RepeatsEvery] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RecurringItem] ADD CONSTRAINT [PK_RecurringItem] PRIMARY KEY CLUSTERED  ([RecurringItemID], [AccountID]) ON [PRIMARY]
GO
