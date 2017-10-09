CREATE TABLE [dbo].[PropertyWarehouseData]
(
[PropertyWarehouseDataID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Date] [date] NOT NULL,
[BilledCharges] [money] NULL,
[BilledChargesLastTimestamp] [datetime2] NULL,
[ActualCollected] [money] NULL,
[ActualCollectedLastTimestamp] [datetime2] NULL,
[Budget] [money] NULL,
[BudgetLastTimestamp] [datetime2] NULL,
[Deliquency] [money] NULL,
[BilledRentCharges] [money] NULL,
[BilledRentChargesLastTimestamp] [datetime2] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyWarehouseData] ADD CONSTRAINT [PK__Property__7AAD3DF9EF52DF40] PRIMARY KEY CLUSTERED  ([PropertyWarehouseDataID], [AccountID]) ON [PRIMARY]
GO
