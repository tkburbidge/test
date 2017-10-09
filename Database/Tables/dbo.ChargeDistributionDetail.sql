CREATE TABLE [dbo].[ChargeDistributionDetail]
(
[ChargeDistributionDetailID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ChargeDistributionID] [uniqueidentifier] NOT NULL,
[PostingBatchID] [uniqueidentifier] NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[VendorID] [uniqueidentifier] NULL,
[ChargeDistributionFormulaID] [uniqueidentifier] NULL,
[Amount] [money] NOT NULL,
[Description] [nvarchar] (300) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[BillingStartDate] [date] NULL,
[BillingEndDate] [date] NULL,
[OrderBy] [tinyint] NOT NULL,
[BilledAmount] [money] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ChargeDistributionDetail] ADD CONSTRAINT [PK_ChargeDistributionDetail] PRIMARY KEY CLUSTERED  ([ChargeDistributionDetailID], [AccountID]) ON [PRIMARY]
GO
