CREATE TYPE [dbo].[LateFeeCollection] AS TABLE
(
[ULGID] [uniqueidentifier] NULL,
[LateFee] [money] NULL,
[FeeLedgerItemTypeID] [uniqueidentifier] NULL
)
GO
