CREATE TABLE [dbo].[STUDWarehouseProperty]
(
[STUDWarehousePropertyID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Date] [date] NOT NULL,
[WeekNumber] [int] NOT NULL,
[UnitCount] [int] NOT NULL,
[OccupiedCount] [int] NOT NULL,
[RenewalsTotal] [int] NOT NULL,
[Leads] [int] NOT NULL,
[Applicants] [int] NOT NULL,
[SignedLeases] [int] NOT NULL,
[AverageEffectiveRent] [money] NOT NULL
) ON [PRIMARY]
GO
