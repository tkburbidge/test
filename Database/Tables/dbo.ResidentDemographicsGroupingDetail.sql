CREATE TABLE [dbo].[ResidentDemographicsGroupingDetail]
(
[ResidentDemographicsGroupingDetailID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ResidentDemographicsGroupingID] [uniqueidentifier] NOT NULL,
[Low] [int] NULL,
[High] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ResidentDemographicsGroupingDetail] ADD CONSTRAINT [PK_ResidentDemographicsGroupingDetail] PRIMARY KEY CLUSTERED  ([ResidentDemographicsGroupingDetailID], [AccountID]) ON [PRIMARY]
GO
