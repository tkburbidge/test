CREATE TABLE [dbo].[YearBudgetUnitType]
(
[YearBudgetUnitTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[YearBudgetID] [uniqueidentifier] NOT NULL,
[UnitTypeID] [uniqueidentifier] NOT NULL,
[BeginningVacancies] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[YearBudgetUnitType] ADD CONSTRAINT [PK_YearBudgetUnitType] PRIMARY KEY CLUSTERED  ([YearBudgetUnitTypeID], [AccountID]) ON [PRIMARY]
GO
