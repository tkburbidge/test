CREATE TABLE [dbo].[TransactionGroup]
(
[TransactionGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[TransactionID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TransactionGroup] ADD CONSTRAINT [PK_TransactionGroup] PRIMARY KEY CLUSTERED  ([TransactionGroupID], [AccountID], [TransactionID]) ON [PRIMARY]
GO
