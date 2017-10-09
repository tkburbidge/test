CREATE TABLE [dbo].[PropertyLedgerItemUnitType]
(
[PropertyLedgerItemUnitTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyLedgerItemID] [uniqueidentifier] NOT NULL,
[UnitTypeID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyLedgerItemUnitType] ADD CONSTRAINT [PK_PropertyLedgerItemUnitType] PRIMARY KEY CLUSTERED  ([PropertyLedgerItemUnitTypeID], [AccountID]) ON [PRIMARY]
GO
