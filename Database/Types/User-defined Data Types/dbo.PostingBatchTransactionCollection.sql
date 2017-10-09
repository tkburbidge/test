CREATE TYPE [dbo].[PostingBatchTransactionCollection] AS TABLE
(
[ObjectID] [uniqueidentifier] NULL,
[ObjectName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Amount] [money] NULL,
[Date] [date] NULL,
[Unit] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)
GO
