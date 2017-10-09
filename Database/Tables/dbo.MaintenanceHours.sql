CREATE TABLE [dbo].[MaintenanceHours]
(
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[SundayFull] [bit] NOT NULL,
[MondayFull] [bit] NOT NULL,
[TuesdayFull] [bit] NOT NULL,
[WednesdayFull] [bit] NOT NULL,
[ThursdayFull] [bit] NOT NULL,
[FridayFull] [bit] NOT NULL,
[SaturdayFull] [bit] NOT NULL,
[SundayStart] [time] NULL,
[MondayStart] [time] NULL,
[TuesdayStart] [time] NULL,
[WednesdayStart] [time] NULL,
[ThursdayStart] [time] NULL,
[FridayStart] [time] NULL,
[SaturdayStart] [time] NULL,
[SundayEnd] [time] NULL,
[MondayEnd] [time] NULL,
[TuesdayEnd] [time] NULL,
[WednesdayEnd] [time] NULL,
[ThursdayEnd] [time] NULL,
[FridayEnd] [time] NULL,
[SaturdayEnd] [time] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[MaintenanceHours] ADD CONSTRAINT [PK_MaintenanceHours] PRIMARY KEY CLUSTERED  ([AccountID], [PropertyID]) ON [PRIMARY]
GO
