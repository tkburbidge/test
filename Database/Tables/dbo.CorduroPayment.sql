CREATE TABLE [dbo].[CorduroPayment]
(
[CorduroPaymentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CorduroTransactionID] [uniqueidentifier] NULL,
[CorduroWalletID] [uniqueidentifier] NULL,
[PaymentID] [uniqueidentifier] NULL,
[DateCreated] [datetime] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LastCheckedDate] [datetime] NULL,
[CheckCount] [int] NOT NULL,
[Amount] [money] NOT NULL,
[ResponseCode] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ResponseText] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CorduroPayment] ADD CONSTRAINT [PK_CorduroPayment] PRIMARY KEY CLUSTERED  ([CorduroPaymentID], [AccountID]) ON [PRIMARY]
GO
