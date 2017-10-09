CREATE TABLE [dbo].[Building]
(
[BuildingID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Floors] [tinyint] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AddressID] [uniqueidentifier] NULL,
[IdentificationNumber] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PlacedInServiceDate] [datetime] NULL,
[ApplicableFraction] [decimal] (18, 2) NULL,
[RentUp] [bit] NOT NULL,
[TaxID] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Building] ADD CONSTRAINT [PK_Building] PRIMARY KEY CLUSTERED  ([BuildingID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Building] WITH NOCHECK ADD CONSTRAINT [FK_Building_Property] FOREIGN KEY ([PropertyID], [AccountID]) REFERENCES [dbo].[Property] ([PropertyID], [AccountID])
GO
ALTER TABLE [dbo].[Building] NOCHECK CONSTRAINT [FK_Building_Property]
GO
