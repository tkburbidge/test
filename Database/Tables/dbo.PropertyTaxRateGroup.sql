CREATE TABLE [dbo].[PropertyTaxRateGroup]
(
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[TaxRateGroupID] [uniqueidentifier] NOT NULL,
[IsObsolete] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyTaxRateGroup] ADD CONSTRAINT [PK_PropertyTaxRateGroup] PRIMARY KEY CLUSTERED  ([PropertyID], [TaxRateGroupID], [AccountID]) ON [PRIMARY]
GO
