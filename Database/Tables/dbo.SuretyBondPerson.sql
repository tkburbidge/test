CREATE TABLE [dbo].[SuretyBondPerson]
(
[SuretyBondPersonID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SuretyBondID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SuretyBondPerson] ADD CONSTRAINT [PK_SuretyBondPerson] PRIMARY KEY CLUSTERED  ([SuretyBondPersonID], [AccountID]) ON [PRIMARY]
GO
