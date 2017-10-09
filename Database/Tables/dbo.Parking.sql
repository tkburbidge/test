CREATE TABLE [dbo].[Parking]
(
[ParkingID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Assigned] [bit] NOT NULL,
[AssignedFee] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SpaceFee] [money] NULL,
[Spaces] [int] NULL,
[Comment] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ParkingType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Parking] ADD CONSTRAINT [PK_Parking] PRIMARY KEY CLUSTERED  ([ParkingID], [AccountID]) ON [PRIMARY]
GO
