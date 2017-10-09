CREATE TYPE [dbo].[ChargeDistributionEditsCollection] AS TABLE
(
[ChargeDistributionDetailID] [uniqueidentifier] NOT NULL,
[UnitLeaseGroupID] [uniqueidentifier] NOT NULL,
[Amount] [money] NOT NULL
)
GO
