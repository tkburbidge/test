CREATE TABLE [dbo].[IntegrationPartnerItem]
(
[IntegrationPartnerItemID] [int] NOT NULL,
[IntegrationPartnerID] [int] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Category] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IntegrationURI] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value1] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value2] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value3] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IntegrationPartnerItem] ADD CONSTRAINT [PK_IntegrationPartnerItem_1] PRIMARY KEY CLUSTERED  ([IntegrationPartnerItemID]) ON [PRIMARY]
GO
