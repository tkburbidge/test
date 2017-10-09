CREATE TYPE [dbo].[PaymentCollection] AS TABLE
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
[TimeStamp] [datetime] NOT NULL
)
GO
