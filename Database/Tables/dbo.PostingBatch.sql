CREATE TABLE [dbo].[PostingBatch]
(
[PostingBatchID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[IntegrationPartnerID] [int] NULL,
[PostingPersonID] [uniqueidentifier] NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Date] [date] NULL,
[PostedDate] [date] NULL,
[OriginalTotalAmount] [money] NULL,
[TransactionCount] [int] NULL,
[IsPaymentBatch] [bit] NOT NULL,
[IsPosted] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PostingBatch] ADD CONSTRAINT [PK_PostingBatch] PRIMARY KEY CLUSTERED  ([PostingBatchID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PostingBatch_PropertyID] ON [dbo].[PostingBatch] ([PropertyID]) ON [PRIMARY]
GO
