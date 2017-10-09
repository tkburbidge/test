CREATE TABLE [dbo].[VendorGroup]
(
[VendorGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[VendorGroup] ADD CONSTRAINT [PK_VendorGroup] PRIMARY KEY CLUSTERED  ([VendorGroupID], [AccountID]) ON [PRIMARY]
GO
