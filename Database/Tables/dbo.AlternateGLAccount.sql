CREATE TABLE [dbo].[AlternateGLAccount]
(
[AlternateGLAccountID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AlternateChartOfAccountsID] [uniqueidentifier] NOT NULL,
[GLAccountType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (210) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Number] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Statistic] [nvarchar] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ParentAlternateGLAccountID] [uniqueidentifier] NULL,
[SummaryParent] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AlternateGLAccount] ADD CONSTRAINT [PK_AlternateGLAccount] PRIMARY KEY CLUSTERED  ([AlternateGLAccountID], [AccountID]) ON [PRIMARY]
GO
