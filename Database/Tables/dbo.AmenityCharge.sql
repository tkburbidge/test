CREATE TABLE [dbo].[AmenityCharge]
(
[AmenityChargeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AmenityID] [uniqueidentifier] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NULL,
[Amount] [money] NOT NULL,
[DateEffective] [date] NOT NULL,
[DateCreated] [datetime] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AmenityCharge] ADD CONSTRAINT [PK_AmenityCharge] PRIMARY KEY CLUSTERED  ([AmenityChargeID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_AmenityCharge_Amenity] ON [dbo].[AmenityCharge] ([AmenityID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_AmenityCharge_DateEffective] ON [dbo].[AmenityCharge] ([DateEffective]) ON [PRIMARY]
GO
