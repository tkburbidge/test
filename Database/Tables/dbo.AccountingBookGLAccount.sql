CREATE TABLE [dbo].[AccountingBookGLAccount]
(
[AccountingBookGLAccountID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AccountingBookID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AccountingBookGLAccount] ADD CONSTRAINT [PK_AccountingBookGLAccount] PRIMARY KEY CLUSTERED  ([AccountingBookGLAccountID], [AccountID]) ON [PRIMARY]
GO
