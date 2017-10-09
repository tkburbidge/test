CREATE TABLE [dbo].[SignaturePackageProperty]
(
[SignaturePackageID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SignaturePackageProperty] ADD CONSTRAINT [PK_SignaturePackageProperty] PRIMARY KEY CLUSTERED  ([SignaturePackageID], [PropertyID], [AccountID]) ON [PRIMARY]
GO
