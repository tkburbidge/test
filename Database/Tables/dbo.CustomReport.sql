CREATE TABLE [dbo].[CustomReport]
(
[CustomReportID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Type] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Category] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TemplateDocumentID] [uniqueidentifier] NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[LastEdited] [datetime] NOT NULL,
[DataSet] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ReportLayout] [varbinary] (max) NULL,
[Filters] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ExpandedTemplateDocumentID] [uniqueidentifier] NULL,
[ExportOptions] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PermissionID] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[CustomReport] ADD CONSTRAINT [PK_CustomReport] PRIMARY KEY CLUSTERED  ([CustomReportID], [AccountID]) ON [PRIMARY]
GO
