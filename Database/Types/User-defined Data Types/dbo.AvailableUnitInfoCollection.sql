CREATE TYPE [dbo].[AvailableUnitInfoCollection] AS TABLE
(
[UnitID] [uniqueidentifier] NOT NULL,
[OldLeaseID] [uniqueidentifier] NULL,
[NewLeaseID] [uniqueidentifier] NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)
GO
