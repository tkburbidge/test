CREATE TABLE [dbo].[Owner]
(
[OwnerID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[VendorID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Owner] ADD CONSTRAINT [PK_Owner] PRIMARY KEY CLUSTERED  ([OwnerID], [AccountID]) ON [PRIMARY]
GO
