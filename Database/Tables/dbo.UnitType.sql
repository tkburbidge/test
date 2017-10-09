CREATE TABLE [dbo].[UnitType]
(
[UnitTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Bedrooms] [int] NOT NULL,
[Bathrooms] [decimal] (3, 1) NOT NULL,
[SquareFootage] [int] NOT NULL,
[MaximumOccupancy] [int] NOT NULL,
[RentLedgerItemTypeID] [uniqueidentifier] NOT NULL,
[MarketRent] [money] NOT NULL,
[DepositLedgerItemTypeID] [uniqueidentifier] NOT NULL,
[RequiredDeposit] [money] NOT NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AllowMultipleLeases] [bit] NOT NULL,
[MarketingName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MarketingDescription] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AvailableForOnlineMarketing] [bit] NOT NULL,
[MaximumVehicles] [int] NULL,
[UseMarketRent] [bit] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[UnitType] ADD CONSTRAINT [PK_UnitType] PRIMARY KEY CLUSTERED  ([UnitTypeID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_UnitType_PropertyID] ON [dbo].[UnitType] ([PropertyID]) ON [PRIMARY]
GO
