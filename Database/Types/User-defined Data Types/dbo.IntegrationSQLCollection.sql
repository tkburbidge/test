CREATE TYPE [dbo].[IntegrationSQLCollection] AS TABLE
(
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Type] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IntegrationSQLReportID] [uniqueidentifier] NULL,
[IntegrationSQLID] [uniqueidentifier] NULL,
[ParameterIdentifier] [uniqueidentifier] NULL
)
GO
