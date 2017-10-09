CREATE TABLE [dbo].[LateFeeScheduleLedgerItemType]
(
[LateFeeScheduleLedgerItemTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LateFeeScheduleID] [uniqueidentifier] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LateFeeScheduleLedgerItemType] ADD CONSTRAINT [PK_LateFeeScheduleLedgerItemType] PRIMARY KEY CLUSTERED  ([LateFeeScheduleLedgerItemTypeID], [AccountID]) ON [PRIMARY]
GO
