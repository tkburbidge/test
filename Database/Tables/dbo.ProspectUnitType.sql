CREATE TABLE [dbo].[ProspectUnitType]
(
[ProspectUnitTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ProspectID] [uniqueidentifier] NOT NULL,
[UnitTypeID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProspectUnitType] ADD CONSTRAINT [PK_ProspectUnitType] PRIMARY KEY CLUSTERED  ([ProspectUnitTypeID], [AccountID]) ON [PRIMARY]
GO
