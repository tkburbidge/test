CREATE TABLE [dbo].[CollectionDetail]
(
[CollectionDetailID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [money] NOT NULL,
[OrderBy] [tinyint] NOT NULL,
[Notes] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OriginalTransactionID] [uniqueidentifier] NULL,
[Date] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CollectionDetail] ADD CONSTRAINT [PK_CollectionDetail] PRIMARY KEY CLUSTERED  ([CollectionDetailID], [AccountID]) ON [PRIMARY]
GO
