CREATE TABLE [dbo].[RepairAndUpgrade]
(
[RepairAndUpgradeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[TypePickListItemID] [uniqueidentifier] NOT NULL,
[Date] [date] NULL,
[VendorID] [uniqueidentifier] NULL,
[WorkOrderID] [uniqueidentifier] NULL,
[SupervisorPersonID] [uniqueidentifier] NULL,
[Make] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Model] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Cost] [money] NULL,
[GLAccountID] [uniqueidentifier] NULL,
[WarrantyExpirationDate] [date] NULL,
[Notes] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SquareFootage] [int] NULL,
[LifeExpectancy] [int] NULL,
[Color] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FlooringType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PadWeight] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PadHeight] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RetiredDate] [datetime] NULL,
[RetiredReasonPickListItemID] [uniqueidentifier] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[RepairAndUpgrade] ADD CONSTRAINT [PK_RepairAndUpgrade] PRIMARY KEY CLUSTERED  ([RepairAndUpgradeID], [AccountID]) ON [PRIMARY]
GO
