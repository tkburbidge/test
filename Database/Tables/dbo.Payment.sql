CREATE TABLE [dbo].[Payment]
(
[PaymentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[BatchID] [uniqueidentifier] NULL,
[ReferenceNumber] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Date] [date] NULL,
[ReceivedFromPaidTo] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Amount] [money] NOT NULL,
[Description] [nvarchar] (75) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Notes] [nvarchar] (425) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PaidOut] [bit] NOT NULL,
[Reversed] [bit] NOT NULL,
[ReversedReason] [nvarchar] (22) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ReversedDate] [date] NULL,
[TimeStamp] [datetime] NOT NULL,
[VoidNotes] [nvarchar] (425) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PostingBatchID] [uniqueidentifier] NULL,
[TaxRateGroupID] [uniqueidentifier] NULL,
[PayerPersonID] [uniqueidentifier] NULL,
[TaxRateID] [uniqueidentifier] NULL,
[SalesTaxForPaymentID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Payment] ADD CONSTRAINT [PK_Check] PRIMARY KEY CLUSTERED  ([PaymentID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Payment_Date] ON [dbo].[Payment] ([Date] DESC) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Payment_ObjectID] ON [dbo].[Payment] ([ObjectID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Payment_PostingBatchID] ON [dbo].[Payment] ([PostingBatchID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Payment_ReferenceNumber] ON [dbo].[Payment] ([ReferenceNumber]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Payment_Reversed] ON [dbo].[Payment] ([Reversed]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Payment_ReversedDate] ON [dbo].[Payment] ([ReversedDate] DESC) ON [PRIMARY]
GO
