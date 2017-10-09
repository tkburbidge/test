CREATE TABLE [dbo].[ChargeDistribution]
(
[ChargeDistributionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PostingDate] [date] NULL,
[IsPosted] [bit] NOT NULL,
[BuildingIDs] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DocumentID] [uniqueidentifier] NULL,
[ExcludeVacantUnits] [bit] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[ChargeDistribution] ADD CONSTRAINT [PK_ChargeDistribution] PRIMARY KEY CLUSTERED  ([ChargeDistributionID], [AccountID]) ON [PRIMARY]
GO
