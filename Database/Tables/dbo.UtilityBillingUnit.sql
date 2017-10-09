CREATE TABLE [dbo].[UtilityBillingUnit]
(
[UtilityBillingUnitID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UtilityBillingID] [uniqueidentifier] NOT NULL,
[UnitID] [uniqueidentifier] NOT NULL,
[UnitLeaseGroupID] [uniqueidentifier] NULL,
[PreviousReading] [int] NOT NULL,
[CurrentReading] [int] NOT NULL,
[Amount] [money] NOT NULL,
[LeaseID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UtilityBillingUnit] ADD CONSTRAINT [PK_UtilityBillingUnit] PRIMARY KEY CLUSTERED  ([UtilityBillingUnitID], [AccountID]) ON [PRIMARY]
GO
