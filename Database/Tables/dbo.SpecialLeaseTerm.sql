CREATE TABLE [dbo].[SpecialLeaseTerm]
(
[SpecialLeaseTermID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SpecialID] [uniqueidentifier] NOT NULL,
[LeaseTermID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SpecialLeaseTerm] ADD CONSTRAINT [PK_SpecialLeaseTerm] PRIMARY KEY CLUSTERED  ([SpecialLeaseTermID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SpecialLeaseTerm] WITH NOCHECK ADD CONSTRAINT [FK_SpecialLeaseTerm_LeaseTerm] FOREIGN KEY ([LeaseTermID], [AccountID]) REFERENCES [dbo].[LeaseTerm] ([LeaseTermID], [AccountID]) ON DELETE CASCADE
GO
ALTER TABLE [dbo].[SpecialLeaseTerm] WITH NOCHECK ADD CONSTRAINT [FK_SpecialLeaseTerm_Special] FOREIGN KEY ([SpecialID], [AccountID]) REFERENCES [dbo].[Special] ([SpecialID], [AccountID]) ON DELETE CASCADE
GO
ALTER TABLE [dbo].[SpecialLeaseTerm] NOCHECK CONSTRAINT [FK_SpecialLeaseTerm_LeaseTerm]
GO
ALTER TABLE [dbo].[SpecialLeaseTerm] NOCHECK CONSTRAINT [FK_SpecialLeaseTerm_Special]
GO
