CREATE TABLE [dbo].[IntegrationPartnerPermission]
(
[IntegrationPartnerPermissionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[IntegrationPartnerID] [int] NOT NULL,
[PropertyID] [uniqueidentifier] NULL,
[MethodName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IntegrationPartnerPermission] ADD CONSTRAINT [PK_IntegrationPartnerPermission] PRIMARY KEY CLUSTERED  ([IntegrationPartnerPermissionID], [AccountID]) ON [PRIMARY]
GO
