CREATE TABLE [dbo].[OwnerDistribution]
(
[OwnerDistributionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Date] [date] NOT NULL,
[OwnerPropertyPercentageGroupID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[OwnerDistribution] ADD CONSTRAINT [PK_OwnerDistribution] PRIMARY KEY CLUSTERED  ([OwnerDistributionID], [AccountID]) ON [PRIMARY]
GO
