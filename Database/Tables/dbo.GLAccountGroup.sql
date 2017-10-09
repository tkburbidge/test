CREATE TABLE [dbo].[GLAccountGroup]
(
[GLAccountGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ReportLabel] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[GLAccountGroup] ADD CONSTRAINT [PK_GLAccountType] PRIMARY KEY CLUSTERED  ([GLAccountGroupID], [AccountID]) ON [PRIMARY]
GO
