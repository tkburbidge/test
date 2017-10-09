CREATE TABLE [dbo].[TaxRate]
(
[TaxRateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Rate] [decimal] (6, 4) NOT NULL,
[GLAccountID] [uniqueidentifier] NULL,
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsObsolete] [bit] NOT NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TaxRate] ADD CONSTRAINT [PK_TaxRate] PRIMARY KEY CLUSTERED  ([TaxRateID], [AccountID]) ON [PRIMARY]
GO
