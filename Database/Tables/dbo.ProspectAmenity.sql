CREATE TABLE [dbo].[ProspectAmenity]
(
[AccountID] [bigint] NOT NULL,
[ProspectID] [uniqueidentifier] NOT NULL,
[AmenityID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProspectAmenity] ADD CONSTRAINT [PK_ProspectAmenity] PRIMARY KEY CLUSTERED  ([AccountID], [ProspectID], [AmenityID]) ON [PRIMARY]
GO
