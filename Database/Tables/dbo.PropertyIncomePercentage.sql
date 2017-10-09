CREATE TABLE [dbo].[PropertyIncomePercentage]
(
[PropertyIncomePercentageID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[IncomePercentageID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyIncomePercentage] ADD CONSTRAINT [PK_PropertyIncomePercentage_1] PRIMARY KEY CLUSTERED  ([PropertyIncomePercentageID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PropertyIncomePercentage] WITH NOCHECK ADD CONSTRAINT [FK_PropertyIncomePercentage_IncomePercentage] FOREIGN KEY ([IncomePercentageID]) REFERENCES [dbo].[IncomePercentage] ([IncomePercentageID])
GO
ALTER TABLE [dbo].[PropertyIncomePercentage] WITH NOCHECK ADD CONSTRAINT [FK_PropertyIncomePercentage_Property] FOREIGN KEY ([PropertyID], [AccountID]) REFERENCES [dbo].[Property] ([PropertyID], [AccountID])
GO
ALTER TABLE [dbo].[PropertyIncomePercentage] NOCHECK CONSTRAINT [FK_PropertyIncomePercentage_IncomePercentage]
GO
ALTER TABLE [dbo].[PropertyIncomePercentage] NOCHECK CONSTRAINT [FK_PropertyIncomePercentage_Property]
GO
