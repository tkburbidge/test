CREATE TABLE [dbo].[PaymentProcessorFee]
(
[PaymentProcessorFeeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[IntegrationPartnerID] [int] NOT NULL,
[PaymentMethod] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PercentFee] [decimal] (6, 4) NOT NULL,
[FlatFee] [money] NOT NULL,
[PaymentType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PaymentProcessorFee] ADD CONSTRAINT [PK_PaymnetProcessorFee] PRIMARY KEY CLUSTERED  ([PaymentProcessorFeeID], [AccountID]) ON [PRIMARY]
GO
