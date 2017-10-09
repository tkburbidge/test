CREATE TABLE [dbo].[IntegrationSQL]
(
[IntegrationSQLID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FROMClause] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[WHEREClause] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PossibleParameterValues] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ParameterDataType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ColumnName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IntegrationSQL] ADD CONSTRAINT [PK_IntegrationSQL] PRIMARY KEY CLUSTERED  ([IntegrationSQLID]) ON [PRIMARY]
GO
