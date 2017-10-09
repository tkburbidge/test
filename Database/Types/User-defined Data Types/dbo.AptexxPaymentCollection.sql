CREATE TYPE [dbo].[AptexxPaymentCollection] AS TABLE
(
[PaymentID] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ExternalID] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PayerID] [uniqueidentifier] NULL,
[Date] [datetime] NULL,
[GrossAmount] [money] NULL,
[NetAmount] [money] NULL,
[DepositAmount] [money] NULL,
[PaymentType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LedgerItemTypeID] [uniqueidentifier] NULL,
[PayerPersonID] [uniqueidentifier] NULL,
[AptexxPayerID] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)
GO
