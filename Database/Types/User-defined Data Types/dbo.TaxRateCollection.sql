CREATE TYPE [dbo].[TaxRateCollection] AS TABLE
(
[TaxRateID] [uniqueidentifier] NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Rate] [decimal] (6, 4) NULL,
[GLAccountID] [uniqueidentifier] NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)
GO
