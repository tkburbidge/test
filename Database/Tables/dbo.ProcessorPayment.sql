CREATE TABLE [dbo].[ProcessorPayment]
(
[ProcessorPaymentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[IntegrationPartnerItemID] [int] NOT NULL,
[ProcessorTransactionID] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[WalletItemID] [uniqueidentifier] NULL,
[PaymentID] [uniqueidentifier] NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [money] NOT NULL,
[Fee] [money] NOT NULL,
[DateCreated] [datetime] NOT NULL,
[PaymentType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Payer] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[RefundDate] [datetime] NULL,
[DateProcessed] [datetime] NOT NULL,
[DateSettled] [datetime] NULL,
[LedgerItemTypeID] [uniqueidentifier] NULL,
[ProcessorPayerID] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IntegrationPartnerID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProcessorPayment] ADD CONSTRAINT [PK_ProcessorPayment] PRIMARY KEY CLUSTERED  ([ProcessorPaymentID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_ProcessorPayment_ProcessorTransactionID] ON [dbo].[ProcessorPayment] ([AccountID], [ProcessorTransactionID]) ON [PRIMARY]
GO
