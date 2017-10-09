CREATE TABLE [dbo].[AffordableProgramAllocationBuilding]
(
[AccountID] [bigint] NOT NULL,
[AffordableProgramAllocationBuildingID] [uniqueidentifier] NOT NULL,
[AffordableProgramAllocationID] [uniqueidentifier] NOT NULL,
[BuildingID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableProgramAllocationBuilding] ADD CONSTRAINT [PK_AffordableProgramAllocationBuilding] PRIMARY KEY CLUSTERED  ([AffordableProgramAllocationBuildingID], [AccountID]) ON [PRIMARY]
GO
