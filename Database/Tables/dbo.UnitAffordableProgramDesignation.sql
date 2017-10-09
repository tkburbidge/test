CREATE TABLE [dbo].[UnitAffordableProgramDesignation]
(
[UnitAffordableProgramDesignationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UnitID] [uniqueidentifier] NOT NULL,
[AffordableProgramID] [uniqueidentifier] NOT NULL,
[ChangedByPersonID] [uniqueidentifier] NOT NULL,
[Timestamp] [datetime] NOT NULL,
[AffordableProgramAllocationID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UnitAffordableProgramDesignation] ADD CONSTRAINT [PK_UnitAffordableProgramDesignation] PRIMARY KEY CLUSTERED  ([UnitAffordableProgramDesignationID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UnitAffordableProgramDesignation] WITH NOCHECK ADD CONSTRAINT [FK_UnitAffordableProgramDesignation_Person] FOREIGN KEY ([ChangedByPersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
ALTER TABLE [dbo].[UnitAffordableProgramDesignation] WITH NOCHECK ADD CONSTRAINT [FK_UnitAffordableProgramDesignation_Unit] FOREIGN KEY ([UnitID], [AccountID]) REFERENCES [dbo].[Unit] ([UnitID], [AccountID])
GO
ALTER TABLE [dbo].[UnitAffordableProgramDesignation] NOCHECK CONSTRAINT [FK_UnitAffordableProgramDesignation_Person]
GO
ALTER TABLE [dbo].[UnitAffordableProgramDesignation] NOCHECK CONSTRAINT [FK_UnitAffordableProgramDesignation_Unit]
GO
