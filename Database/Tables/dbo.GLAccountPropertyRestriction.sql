CREATE TABLE [dbo].[GLAccountPropertyRestriction]
(
[GLAccountPropertyRestrictionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[GLAccountPropertyRestriction] ADD CONSTRAINT [PK_GLAccountPropertyRestriction] PRIMARY KEY CLUSTERED  ([GLAccountPropertyRestrictionID], [AccountID]) ON [PRIMARY]
GO
