CREATE TABLE [dbo].[LedgerItemTypeProperty]
(
[LedgerItemTypePropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[TaxRateGroupID] [uniqueidentifier] NULL,
[IsInterestable] [bit] NULL,
[HasAccess] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LedgerItemTypeProperty] ADD CONSTRAINT [PK_LedgerItemTypeProperty] PRIMARY KEY CLUSTERED  ([LedgerItemTypePropertyID], [AccountID]) ON [PRIMARY]
GO
