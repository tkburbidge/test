CREATE TABLE [dbo].[AlternateChartOfAccounts]
(
[AlternateChartOfAccountsID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AlternateChartOfAccounts] ADD CONSTRAINT [PK_AlternateChartOfAccounts] PRIMARY KEY CLUSTERED  ([AlternateChartOfAccountsID], [AccountID]) ON [PRIMARY]
GO
