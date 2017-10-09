CREATE TABLE [dbo].[IntegrationSQLReportIntegrationSQL]
(
[IntegrationSQLReportIntegrationSQLID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[IntegrationSQLReportID] [uniqueidentifier] NOT NULL,
[IntegrationSQLID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ParameterData] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ParameterDataType] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ParameterIdentifier] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IntegrationSQLReportIntegrationSQL] ADD CONSTRAINT [PK_IntegrationSQLReportIntegrationSQL] PRIMARY KEY CLUSTERED  ([IntegrationSQLReportIntegrationSQLID], [AccountID]) ON [PRIMARY]
GO
