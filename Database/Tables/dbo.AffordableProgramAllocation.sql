CREATE TABLE [dbo].[AffordableProgramAllocation]
(
[AffordableProgramAllocationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AffordableProgramID] [uniqueidentifier] NOT NULL,
[UnitAmount] [int] NULL,
[AmiPercent] [int] NULL,
[OverIncomePercent] [int] NULL,
[ContractNumber] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PlanOfAction] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SubsidyType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NumberOfUnits] [int] NULL,
[Before1981] [bit] NOT NULL,
[UseSection202] [bit] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Elderly] [bit] NOT NULL,
[Disabled] [bit] NOT NULL,
[Displaced] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Veteran] [bit] NOT NULL,
[PrevHousing] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AssistancePaymentTransactionCategory] [uniqueidentifier] NULL,
[UnitAmountIsPercent] [bit] NOT NULL,
[RentLimitPercent] [int] NULL,
[HouseholdType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Frail] [bit] NOT NULL,
[DisabledHearing] [bit] NOT NULL,
[DisabledMobility] [bit] NOT NULL,
[DisabledVisual] [bit] NOT NULL,
[DisabledMental] [bit] NOT NULL,
[ExpirationDate] [date] NULL,
[SendSubmissionsToCA] [bit] NOT NULL,
[IsRadConverted] [bit] NOT NULL,
[IsUnitAmountForAllBuildings] [bit] NOT NULL,
[IsHighHome] [bit] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableProgramAllocation] ADD CONSTRAINT [PK_AffordableProgramAllocation] PRIMARY KEY CLUSTERED  ([AffordableProgramAllocationID], [AccountID]) ON [PRIMARY]
GO
