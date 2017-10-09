CREATE TABLE [dbo].[PropertyLeaseTerm]
(
[PropertyLeaseTermID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[LeaseTermID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyLeaseTerm] ADD CONSTRAINT [PK_PropertyLeaseTerm] PRIMARY KEY CLUSTERED  ([PropertyLeaseTermID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyLeaseTerm] WITH NOCHECK ADD CONSTRAINT [FK_PropertyLeaseTerm_LeaseTerm] FOREIGN KEY ([LeaseTermID], [AccountID]) REFERENCES [dbo].[LeaseTerm] ([LeaseTermID], [AccountID]) ON DELETE CASCADE
GO
ALTER TABLE [dbo].[PropertyLeaseTerm] NOCHECK CONSTRAINT [FK_PropertyLeaseTerm_LeaseTerm]
GO
