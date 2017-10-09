CREATE TABLE [dbo].[SecurityLedgerItemType]
(
[SecurityLedgerItemTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SecurityRoleID] [uniqueidentifier] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SecurityLedgerItemType] ADD CONSTRAINT [PK_SecurityLedgerItemType] PRIMARY KEY CLUSTERED  ([SecurityLedgerItemTypeID], [AccountID]) ON [PRIMARY]
GO
