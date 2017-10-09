CREATE TABLE [dbo].[RepairAndUpgradeArea]
(
[RepairAndUpgradeID] [uniqueidentifier] NOT NULL,
[AreaPickListItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RepairAndUpgradeArea] ADD CONSTRAINT [PK_RepairAndUpgradeArea] PRIMARY KEY CLUSTERED  ([RepairAndUpgradeID], [AreaPickListItemID], [AccountID]) ON [PRIMARY]
GO
