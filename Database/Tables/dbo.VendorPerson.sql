CREATE TABLE [dbo].[VendorPerson]
(
[VendorPersonID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[VendorID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[VendorPerson] ADD CONSTRAINT [PK_VendorPerson] PRIMARY KEY CLUSTERED  ([VendorPersonID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[VendorPerson] WITH NOCHECK ADD CONSTRAINT [FK_VendorPerson_Vendor] FOREIGN KEY ([VendorID], [AccountID]) REFERENCES [dbo].[Vendor] ([VendorID], [AccountID])
GO
ALTER TABLE [dbo].[VendorPerson] NOCHECK CONSTRAINT [FK_VendorPerson_Vendor]
GO
