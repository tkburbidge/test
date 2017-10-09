CREATE TABLE [dbo].[UnitTypeLeaseTerm]
(
[UnitTypeLeaseTermID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UnitTypeID] [uniqueidentifier] NOT NULL,
[LeaseTermID] [uniqueidentifier] NOT NULL,
[Amount] [money] NOT NULL,
[IsPercentage] [bit] NOT NULL,
[Round] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UnitTypeLeaseTerm] ADD CONSTRAINT [PK_UnitTypeLeaseTerm] PRIMARY KEY CLUSTERED  ([UnitTypeLeaseTermID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[UnitTypeLeaseTerm] WITH NOCHECK ADD CONSTRAINT [FK_UnitTypeLeaseTerm_LeaseTerm] FOREIGN KEY ([LeaseTermID], [AccountID]) REFERENCES [dbo].[LeaseTerm] ([LeaseTermID], [AccountID]) ON DELETE CASCADE
GO
ALTER TABLE [dbo].[UnitTypeLeaseTerm] WITH NOCHECK ADD CONSTRAINT [FK_UnitTypeLeaseTerm_UnitType] FOREIGN KEY ([UnitTypeID], [AccountID]) REFERENCES [dbo].[UnitType] ([UnitTypeID], [AccountID]) ON DELETE CASCADE
GO
ALTER TABLE [dbo].[UnitTypeLeaseTerm] NOCHECK CONSTRAINT [FK_UnitTypeLeaseTerm_LeaseTerm]
GO
ALTER TABLE [dbo].[UnitTypeLeaseTerm] NOCHECK CONSTRAINT [FK_UnitTypeLeaseTerm_UnitType]
GO
