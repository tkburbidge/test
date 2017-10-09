CREATE TABLE [dbo].[IntegrationPartnerItemIntegrationSQL]
(
[IntegrationPartnerItemIntegrationSQLID] [uniqueidentifier] NOT NULL,
[IntegrationPartnerItemID] [int] NOT NULL,
[IntegrationSQLID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IntegrationPartnerItemIntegrationSQL] ADD CONSTRAINT [PK_IntegrationPartnerItemIntegrationSQL] PRIMARY KEY CLUSTERED  ([IntegrationPartnerItemIntegrationSQLID]) ON [PRIMARY]
GO
