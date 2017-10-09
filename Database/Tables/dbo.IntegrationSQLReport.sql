CREATE TABLE [dbo].[IntegrationSQLReport]
(
[IntegrationSQLReportID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[IntegrationPartnerItemPropertyID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Frequency] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DayToRun] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CanBeManual] [bit] NOT NULL,
[Value1] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value2] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value3] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IntegrationSQLReport] ADD CONSTRAINT [PK_IntegrationSQLReport] PRIMARY KEY CLUSTERED  ([IntegrationSQLReportID], [AccountID]) ON [PRIMARY]
GO
