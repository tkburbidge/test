CREATE TYPE [dbo].[TransactionCollection] AS TABLE
(
[TransactionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[TransactionTypeID] [uniqueidentifier] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NULL,
[AppliesToTransactionID] [uniqueidentifier] NULL,
[ReversesTransactionID] [uniqueidentifier] NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NULL,
[TaxGroupID] [uniqueidentifier] NULL,
[NotVisible] [bit] NOT NULL,
[Origin] [nchar] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [money] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Note] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TransactionDate] [date] NOT NULL,
[TimeStamp] [datetime] NOT NULL,
[IsDeleted] [bit] NULL
)
GO
