CREATE TABLE [dbo].[YearBudget]
(
[YearBudgetID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[DefaultBudgetTemplateID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Year] [int] NOT NULL,
[LastModified] [datetime] NOT NULL,
[LastModifiedByPersonID] [uniqueidentifier] NOT NULL,
[AccountingBasis] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FutureStartMonth] [int] NOT NULL,
[DefaultCostPerTurnType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DefaultCostPerTurnOverride] [money] NULL,
[TermsAcceptedByPersonID] [uniqueidentifier] NOT NULL,
[TermsAcceptedTime] [datetime] NOT NULL,
[RentalIncomeNeedsRecalculation] [bit] NOT NULL,
[TurnoverCostsNeedsRecalculation] [bit] NOT NULL,
[RoundCalculations] [bit] NOT NULL,
[ApprovalWorkflowID] [uniqueidentifier] NULL,
[AllowManualOverrideProjectedMoveOuts] [bit] NOT NULL,
[AutoLoadHistoricalValues] [bit] NOT NULL,
[IsAlternate] [bit] NOT NULL,
[StartMonth] [int] NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FutureAmountBasis] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[YearBudget] ADD CONSTRAINT [PK_YearBudget] PRIMARY KEY CLUSTERED  ([YearBudgetID], [AccountID]) ON [PRIMARY]
GO
