CREATE TABLE [dbo].[PropertyLateFeeSchedule]
(
[PropertyLateFeeScheduleID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[LateFeeScheduleID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyLateFeeSchedule] ADD CONSTRAINT [PK_PropertyLateFeeSchedule] PRIMARY KEY CLUSTERED  ([PropertyLateFeeScheduleID], [AccountID]) ON [PRIMARY]
GO
