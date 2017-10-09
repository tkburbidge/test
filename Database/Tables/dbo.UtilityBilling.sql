CREATE TABLE [dbo].[UtilityBilling]
(
[UtilityBillingID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PostingDate] [date] NOT NULL,
[IsPosted] [bit] NOT NULL,
[BuildingIDs] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[BillingStartDate] [date] NOT NULL,
[BillingEndDate] [date] NOT NULL,
[PreviousReading] [int] NOT NULL,
[CurrentReading] [int] NOT NULL,
[BilledAmount] [money] NOT NULL,
[RatePerUnit] [decimal] (12, 6) NOT NULL,
[DueDate] [date] NOT NULL,
[LateFee] [money] NOT NULL,
[LateFeeIsPercent] [bit] NOT NULL,
[PostingBatchID] [uniqueidentifier] NULL,
[ProrateCharges] [bit] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[UtilityBilling] ADD CONSTRAINT [PK_UtilityBilling] PRIMARY KEY CLUSTERED  ([UtilityBillingID], [AccountID]) ON [PRIMARY]
GO
