CREATE TABLE [dbo].[LedgerItemTypeApplication]
(
[LedgerItemTypeApplicationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[AppliesToLedgerItemTypeID] [uniqueidentifier] NOT NULL,
[CanBeApplied] [bit] NOT NULL,
[OrderBy] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LedgerItemTypeApplication] ADD CONSTRAINT [PK_LedgerItemTypeApplication] PRIMARY KEY CLUSTERED  ([LedgerItemTypeApplicationID], [AccountID]) ON [PRIMARY]
GO
