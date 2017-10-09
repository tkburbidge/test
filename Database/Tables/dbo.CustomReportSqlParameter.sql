CREATE TABLE [dbo].[CustomReportSqlParameter]
(
[CustomReportSqlParameterID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CustomReportID] [uniqueidentifier] NOT NULL,
[SqlParameter] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Label] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CustomReportSqlParameter] ADD CONSTRAINT [PK_CustomReportSqlParameter] PRIMARY KEY CLUSTERED  ([CustomReportSqlParameterID], [AccountID]) ON [PRIMARY]
GO
