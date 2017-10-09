CREATE TABLE [dbo].[UtilityReimbursement]
(
[AccountID] [bigint] NOT NULL,
[UtilityReimbursementID] [uniqueidentifier] NOT NULL,
[Date] [datetime] NOT NULL,
[UnitLeaseGroupID] [uniqueidentifier] NOT NULL,
[Amount] [money] NOT NULL,
[PaymentID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UtilityReimbursement] ADD CONSTRAINT [PK_UtilityReimbursement] PRIMARY KEY CLUSTERED  ([UtilityReimbursementID], [AccountID]) ON [PRIMARY]
GO
