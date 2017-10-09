CREATE TABLE [dbo].[BatchReportParameter]
(
[BatchReportParameterID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ReportBatchReportID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DefaultValue] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[BatchReportParameter] ADD CONSTRAINT [PK_BatchReportParameter] PRIMARY KEY CLUSTERED  ([BatchReportParameterID], [AccountID]) ON [PRIMARY]
GO
