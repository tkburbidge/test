CREATE TABLE [dbo].[IntegrationPartnerItemProperty]
(
[IntegrationPartnerItemPropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[IntegrationPartnerItemID] [int] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[IntegrationURI] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value1] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value2] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value3] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value4] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value5] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value6] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value7] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value8] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IntegrationPartnerItemProperty] ADD CONSTRAINT [PK_IntegrationPartnerItemProperty] PRIMARY KEY CLUSTERED  ([IntegrationPartnerItemPropertyID], [AccountID]) ON [PRIMARY]
GO
