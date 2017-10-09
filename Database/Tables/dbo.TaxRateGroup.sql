CREATE TABLE [dbo].[TaxRateGroup]
(
[TaxRateGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCreated] [date] NOT NULL,
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsObsolete] [bit] NOT NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TaxRateGroup] ADD CONSTRAINT [PK_TaxRateGroup] PRIMARY KEY CLUSTERED  ([TaxRateGroupID], [AccountID]) ON [PRIMARY]
GO
