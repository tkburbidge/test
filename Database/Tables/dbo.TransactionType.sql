CREATE TABLE [dbo].[TransactionType]
(
[TransactionTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[Group] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OrderBy] [tinyint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TransactionType] ADD CONSTRAINT [PK_TransactionType] PRIMARY KEY CLUSTERED  ([TransactionTypeID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_TransactionType_NameGroup] ON [dbo].[TransactionType] ([Name], [Group]) ON [PRIMARY]
GO
