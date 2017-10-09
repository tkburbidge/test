CREATE TABLE [dbo].[LedgerLineItemGroupLedgerItemType]
(
[LedgerLineItemGroupLedgerItemTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LedgerLineItemGroupID] [uniqueidentifier] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LedgerLineItemGroupLedgerItemType] ADD CONSTRAINT [PK_LedgerLineItemGroupLedgerItemType] PRIMARY KEY CLUSTERED  ([LedgerLineItemGroupLedgerItemTypeID], [AccountID]) ON [PRIMARY]
GO
