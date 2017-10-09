CREATE TABLE [dbo].[IncomePercentage]
(
[IncomePercentageID] [uniqueidentifier] NOT NULL,
[Percent] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[IncomePercentage] ADD CONSTRAINT [PK_IncomePercentage_1] PRIMARY KEY CLUSTERED  ([IncomePercentageID]) ON [PRIMARY]
GO
