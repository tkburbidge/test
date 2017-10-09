CREATE TABLE [dbo].[CertificationAffordableProgramAllocation]
(
[CertificationID] [uniqueidentifier] NOT NULL,
[AffordableProgramAllocationID] [uniqueidentifier] NOT NULL,
[CertificationAffordableProgramAllocationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CertificationAffordableProgramAllocation] ADD CONSTRAINT [PK_CertificationTaxCreditProgramAllocation] PRIMARY KEY CLUSTERED  ([CertificationAffordableProgramAllocationID]) ON [PRIMARY]
GO
