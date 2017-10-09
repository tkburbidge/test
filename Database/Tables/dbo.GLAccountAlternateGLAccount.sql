CREATE TABLE [dbo].[GLAccountAlternateGLAccount]
(
[AlternateGLAccountID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[GLAccountAlternateGLAccount] ADD CONSTRAINT [PK_GLAccountAlternateGLAccount] PRIMARY KEY CLUSTERED  ([AlternateGLAccountID], [GLAccountID], [AccountID]) ON [PRIMARY]
GO
