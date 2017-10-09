CREATE TABLE [dbo].[Amenity]
(
[AmenityID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[AmenityTypeID] [uniqueidentifier] NULL,
[Name] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MITSAmenityTypePickListItemID] [uniqueidentifier] NULL,
[Level] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AvailableForOnlineMarketing] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Amenity] ADD CONSTRAINT [PK_Amenity] PRIMARY KEY CLUSTERED  ([AmenityID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Amenity] WITH NOCHECK ADD CONSTRAINT [FK_Amenity_AmenityType] FOREIGN KEY ([AmenityTypeID], [AccountID]) REFERENCES [dbo].[AmenityType] ([AmenityTypeID], [AccountID])
GO
ALTER TABLE [dbo].[Amenity] NOCHECK CONSTRAINT [FK_Amenity_AmenityType]
GO
