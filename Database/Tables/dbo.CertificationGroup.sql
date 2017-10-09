CREATE TABLE [dbo].[CertificationGroup]
(
[CertificationGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[InitialEffectiveDate] [date] NOT NULL,
[InitialIncome] [money] NULL,
[InitialHouseholdSize] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CertificationGroup] ADD CONSTRAINT [PK_CertificationGroup] PRIMARY KEY CLUSTERED  ([CertificationGroupID], [AccountID]) ON [PRIMARY]
GO
