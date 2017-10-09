CREATE TABLE [dbo].[ReportGroup]
(
[ReportGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ParentGLAccountGroupID] [uniqueidentifier] NULL,
[ChildGLAccountGroupID] [uniqueidentifier] NULL,
[ReportName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OrderBy] [smallint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ReportGroup] ADD CONSTRAINT [PK_ReportGroup] PRIMARY KEY CLUSTERED  ([ReportGroupID], [AccountID]) ON [PRIMARY]
GO
