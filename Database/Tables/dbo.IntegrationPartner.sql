CREATE TABLE [dbo].[IntegrationPartner]
(
[IntegrationPartnerID] [int] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Category] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IntegrationURI] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ApiKey] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsUserEditable] [bit] NOT NULL,
[LogoUrl] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value1] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value2] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsApiUser] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IntegrationPartner] ADD CONSTRAINT [PK_IntegrationPartner_1] PRIMARY KEY CLUSTERED  ([IntegrationPartnerID]) ON [PRIMARY]
GO
