CREATE TYPE [dbo].[PrintedCheckNumber] AS TABLE
(
[PaymentID] [uniqueidentifier] NOT NULL,
[CheckNumber] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
)
GO
