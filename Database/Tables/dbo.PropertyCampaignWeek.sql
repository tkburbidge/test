CREATE TABLE [dbo].[PropertyCampaignWeek]
(
[PropertyCampaignWeekID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyCampaignID] [uniqueidentifier] NOT NULL,
[CalendarWeekNumber] [int] NOT NULL,
[CampaignWeekNumber] [int] NOT NULL,
[PreleasePercentageGoal] [money] NOT NULL,
[NewLeaseGoal] [int] NOT NULL,
[RenewalPercentageGoal] [money] NOT NULL,
[TrafficGoal] [int] NOT NULL,
[WeekStartDate] [date] NOT NULL,
[NewApplicantGoal] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyCampaignWeek] ADD CONSTRAINT [PK_PropertyCampaignWeek] PRIMARY KEY CLUSTERED  ([PropertyCampaignWeekID], [AccountID]) ON [PRIMARY]
GO
