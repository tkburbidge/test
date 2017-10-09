CREATE TABLE [dbo].[PartialTransactionEdit]
(
[OriginalID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ReversesID] [uniqueidentifier] NOT NULL,
[EditedID] [uniqueidentifier] NULL,
[IsPayment] [bit] NOT NULL,
[TimeStamp] [datetime] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PartialTransactionEdit] ADD CONSTRAINT [PK_PartialTransactionEdit] PRIMARY KEY CLUSTERED  ([OriginalID], [AccountID]) ON [PRIMARY]
GO
