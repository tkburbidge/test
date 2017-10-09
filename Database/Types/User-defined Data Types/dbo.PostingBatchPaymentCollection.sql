CREATE TYPE [dbo].[PostingBatchPaymentCollection] AS TABLE
(
[ObjectID] [uniqueidentifier] NULL,
[ReceivedFrom] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ReferenceNumber] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PartnerTransactionID] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Amount] [money] NULL,
[Date] [date] NULL,
[Description] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Notes] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LedgerItemTypeID] [uniqueidentifier] NULL,
[PayerPersonID] [uniqueidentifier] NULL
)
GO
