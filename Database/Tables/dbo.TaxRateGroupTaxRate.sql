CREATE TABLE [dbo].[TaxRateGroupTaxRate]
(
[TaxRateGroupID] [uniqueidentifier] NOT NULL,
[TaxRateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TaxRateGroupTaxRate] ADD CONSTRAINT [PK_TaxRateGroupTaxRate] PRIMARY KEY CLUSTERED  ([TaxRateGroupID], [TaxRateID], [AccountID]) ON [PRIMARY]
GO
