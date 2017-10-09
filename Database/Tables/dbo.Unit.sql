CREATE TABLE [dbo].[Unit]
(
[UnitID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UnitTypeID] [uniqueidentifier] NOT NULL,
[BuildingID] [uniqueidentifier] NOT NULL,
[AddressID] [uniqueidentifier] NOT NULL,
[Number] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PaddedNumber] [nchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Floor] [nvarchar] (5) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LastVacatedDate] [date] NULL,
[TotalVacantDays] [int] NOT NULL,
[AddressIncludesUnitNumber] [bit] NOT NULL,
[AllowMultipleLeases] [bit] NOT NULL,
[AvailableUnitsNote] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PetsPermitted] [bit] NOT NULL,
[AvailableForOnlineMarketing] [bit] NOT NULL,
[IsHoldingUnit] [bit] NOT NULL,
[ExcludedFromOccupancy] [bit] NOT NULL,
[DateAvailable] [date] NULL,
[SquareFootage] [int] NOT NULL,
[HearingAccessibility] [bit] NOT NULL,
[MobilityAccessibility] [bit] NOT NULL,
[VisualAccessibility] [bit] NOT NULL,
[WorkOrderUnitInstructions] [nvarchar] (3500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsExempt] [bit] NOT NULL,
[IsEmployee] [bit] NOT NULL,
[IsMarket] [bit] NOT NULL,
[DateRemoved] [date] NULL,
[MaxPetsPermitted] [int] NOT NULL,
[HudUnitNumber] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Unit] ADD CONSTRAINT [PK_Unit] PRIMARY KEY CLUSTERED  ([UnitID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Unit_UnitTypeID] ON [dbo].[Unit] ([UnitTypeID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Unit] WITH NOCHECK ADD CONSTRAINT [FK_Unit_Building] FOREIGN KEY ([BuildingID], [AccountID]) REFERENCES [dbo].[Building] ([BuildingID], [AccountID])
GO
ALTER TABLE [dbo].[Unit] WITH NOCHECK ADD CONSTRAINT [FK_Unit_UnitType] FOREIGN KEY ([UnitTypeID], [AccountID]) REFERENCES [dbo].[UnitType] ([UnitTypeID], [AccountID])
GO
ALTER TABLE [dbo].[Unit] NOCHECK CONSTRAINT [FK_Unit_Building]
GO
ALTER TABLE [dbo].[Unit] NOCHECK CONSTRAINT [FK_Unit_UnitType]
GO
