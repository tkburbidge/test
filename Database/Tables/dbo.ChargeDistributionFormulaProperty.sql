CREATE TABLE [dbo].[ChargeDistributionFormulaProperty]
(
[ChargeDistributionFormulaPropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ChargeDistributionFormulaID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ChargeDistributionFormulaProperty] ADD CONSTRAINT [PK_ChargeDistributionFormulaProperty] PRIMARY KEY CLUSTERED  ([ChargeDistributionFormulaPropertyID], [AccountID]) ON [PRIMARY]
GO
