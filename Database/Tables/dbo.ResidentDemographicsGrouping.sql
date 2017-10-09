CREATE TABLE [dbo].[ResidentDemographicsGrouping]
(
[ResidentDemographicsGroupingID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ResidentDemographicsGrouping] ADD CONSTRAINT [PK_ResidentDemographicsGrouping] PRIMARY KEY CLUSTERED  ([ResidentDemographicsGroupingID], [AccountID]) ON [PRIMARY]
GO
