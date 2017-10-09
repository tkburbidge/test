CREATE TABLE [dbo].[Package]
(
[PackageID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PackageLogID] [uniqueidentifier] NOT NULL,
[TrackingNumber] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Condition] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Package] ADD CONSTRAINT [PK_Package] PRIMARY KEY CLUSTERED  ([PackageID], [AccountID]) ON [PRIMARY]
GO
