CREATE TABLE [dbo].[RentersInsuranceLeaseLedgerItem]
(
[RentersInsuranceLeaseLedgerItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RentersInsuranceID] [uniqueidentifier] NOT NULL,
[LeaseLedgerItemID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RentersInsuranceLeaseLedgerItem] ADD CONSTRAINT [PK_RentersInsuranceLeaseLedgerItem] PRIMARY KEY CLUSTERED  ([RentersInsuranceLeaseLedgerItemID], [AccountID]) ON [PRIMARY]
GO
