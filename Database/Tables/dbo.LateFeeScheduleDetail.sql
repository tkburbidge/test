CREATE TABLE [dbo].[LateFeeScheduleDetail]
(
[LateFeeScheduleDetailID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LateFeeScheduleID] [uniqueidentifier] NOT NULL,
[Day] [smallint] NOT NULL,
[IsPercent] [bit] NOT NULL,
[Amount] [money] NOT NULL,
[AssessedBalance] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FeesAssessedDaily] [bit] NOT NULL,
[MinimumFee] [money] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LateFeeScheduleDetail] ADD CONSTRAINT [PK_LateFeeScheduleDetail] PRIMARY KEY CLUSTERED  ([LateFeeScheduleDetailID], [AccountID]) ON [PRIMARY]
GO
