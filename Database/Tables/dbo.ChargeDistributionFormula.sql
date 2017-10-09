CREATE TABLE [dbo].[ChargeDistributionFormula]
(
[ChargeDistributionFormulaID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[NumberOfOccupantsWeight] [tinyint] NULL,
[SquareFootageWeight] [tinyint] NULL,
[AdditionalFee] [money] NULL,
[BillingPercentage] [tinyint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ChargeDistributionFormula] ADD CONSTRAINT [PK_ChargeDistributionFormula] PRIMARY KEY CLUSTERED  ([ChargeDistributionFormulaID], [AccountID]) ON [PRIMARY]
GO
