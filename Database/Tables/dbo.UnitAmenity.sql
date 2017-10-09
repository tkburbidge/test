CREATE TABLE [dbo].[UnitAmenity]
(
[UnitAmenityID] [uniqueidentifier] NOT NULL,
[UnitID] [uniqueidentifier] NOT NULL,
[AmenityID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[DateEffective] [date] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UnitAmenity] ADD CONSTRAINT [PK_UnitAmenity] PRIMARY KEY CLUSTERED  ([UnitAmenityID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_UnitAmenity_Amenity] ON [dbo].[UnitAmenity] ([AmenityID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_UnitAmenity_Unit] ON [dbo].[UnitAmenity] ([UnitID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UnitAmenity] WITH NOCHECK ADD CONSTRAINT [FK_UnitAmenity_Amenity] FOREIGN KEY ([AmenityID], [AccountID]) REFERENCES [dbo].[Amenity] ([AmenityID], [AccountID])
GO
ALTER TABLE [dbo].[UnitAmenity] WITH NOCHECK ADD CONSTRAINT [FK_UnitAmenity_Unit] FOREIGN KEY ([UnitID], [AccountID]) REFERENCES [dbo].[Unit] ([UnitID], [AccountID])
GO
ALTER TABLE [dbo].[UnitAmenity] NOCHECK CONSTRAINT [FK_UnitAmenity_Amenity]
GO
ALTER TABLE [dbo].[UnitAmenity] NOCHECK CONSTRAINT [FK_UnitAmenity_Unit]
GO
