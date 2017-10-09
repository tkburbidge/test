CREATE TABLE [dbo].[RentersInsurancePerson]
(
[RentersInsurancePersonID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RentersInsuranceID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RentersInsurancePerson] ADD CONSTRAINT [PK_RentersInsurancePerson] PRIMARY KEY CLUSTERED  ([RentersInsurancePersonID], [AccountID]) ON [PRIMARY]
GO
