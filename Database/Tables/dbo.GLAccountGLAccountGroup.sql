CREATE TABLE [dbo].[GLAccountGLAccountGroup]
(
[GLAccountGLAccountGroupID] [uniqueidentifier] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[GLAccountGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[GLAccountGLAccountGroup] ADD CONSTRAINT [PK_GLAccountGLAccountGroup] PRIMARY KEY CLUSTERED  ([GLAccountGLAccountGroupID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[GLAccountGLAccountGroup] WITH NOCHECK ADD CONSTRAINT [FK_GLAccountGLAccountGroup_GLAccount] FOREIGN KEY ([GLAccountID], [AccountID]) REFERENCES [dbo].[GLAccount] ([GLAccountID], [AccountID])
GO
ALTER TABLE [dbo].[GLAccountGLAccountGroup] WITH NOCHECK ADD CONSTRAINT [FK_GLAccountGLAccountGroup_GLAccountGroup] FOREIGN KEY ([GLAccountGroupID], [AccountID]) REFERENCES [dbo].[GLAccountGroup] ([GLAccountGroupID], [AccountID])
GO
ALTER TABLE [dbo].[GLAccountGLAccountGroup] NOCHECK CONSTRAINT [FK_GLAccountGLAccountGroup_GLAccount]
GO
ALTER TABLE [dbo].[GLAccountGLAccountGroup] NOCHECK CONSTRAINT [FK_GLAccountGLAccountGroup_GLAccountGroup]
GO
