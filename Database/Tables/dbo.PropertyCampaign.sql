CREATE TABLE [dbo].[PropertyCampaign]
(
[PropertyCampaignID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NOT NULL,
[OccupancyGoalDate] [date] NOT NULL,
[IsActive] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyCampaign] ADD CONSTRAINT [PK_PropertyCampaign] PRIMARY KEY CLUSTERED  ([PropertyCampaignID], [AccountID]) ON [PRIMARY]
GO
