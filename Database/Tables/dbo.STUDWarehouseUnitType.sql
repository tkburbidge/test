CREATE TABLE [dbo].[STUDWarehouseUnitType]
(
[STUDWarehouseUnitTypeID] [uniqueidentifier] NOT NULL,
[UnitTypeID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Date] [date] NOT NULL,
[WeekNumber] [int] NOT NULL,
[UnitCount] [int] NOT NULL,
[OccupiedCount] [int] NOT NULL,
[Leads] [int] NOT NULL,
[SignedLeases] [int] NOT NULL,
[RenewalsTotal] [int] NOT NULL,
[AverageEffectiveRent] [money] NOT NULL,
[AverageNewRent] [money] NOT NULL,
[RentChange] [money] NOT NULL,
[AverageRenewalRent] [money] NOT NULL
) ON [PRIMARY]
GO
