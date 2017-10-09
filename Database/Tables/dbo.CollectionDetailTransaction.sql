CREATE TABLE [dbo].[CollectionDetailTransaction]
(
[CollectionDetailTransactionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CollectionDetailID] [uniqueidentifier] NOT NULL,
[TransactionID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CollectionDetailTransaction] ADD CONSTRAINT [PK_CollectionDetailTransaction] PRIMARY KEY CLUSTERED  ([CollectionDetailTransactionID], [AccountID]) ON [PRIMARY]
GO
