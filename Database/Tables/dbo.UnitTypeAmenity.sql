CREATE TABLE [dbo].[UnitTypeAmenity]
(
[UnitTypeAmenityID] [uniqueidentifier] NOT NULL,
[UnitTypeID] [uniqueidentifier] NOT NULL,
[AmenityID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UnitTypeAmenity] ADD CONSTRAINT [PK_UnitTypeAmenity] PRIMARY KEY CLUSTERED  ([UnitTypeAmenityID], [AccountID]) ON [PRIMARY]
GO
