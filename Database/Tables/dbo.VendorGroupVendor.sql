CREATE TABLE [dbo].[VendorGroupVendor]
(
[VendorGroupVendorID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[VendorGroupID] [uniqueidentifier] NOT NULL,
[VendorID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[VendorGroupVendor] ADD CONSTRAINT [PK_VendorGroupVendor] PRIMARY KEY CLUSTERED  ([AccountID], [VendorGroupVendorID]) ON [PRIMARY]
GO
