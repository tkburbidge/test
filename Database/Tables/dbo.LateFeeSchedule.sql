CREATE TABLE [dbo].[LateFeeSchedule]
(
[LateFeeScheduleID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[MaximumLateFee] [money] NOT NULL,
[Threshold] [money] NOT NULL,
[IsArchived] [bit] NOT NULL,
[RentDueDay] [int] NOT NULL,
[IsLeaseSchedule] [bit] NOT NULL,
[IsRentSchedule] [bit] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[MaximumLateFeeType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LateFeeSchedule] ADD CONSTRAINT [PK_LateFeeSchedule] PRIMARY KEY CLUSTERED  ([LateFeeScheduleID], [AccountID]) ON [PRIMARY]
GO
