CREATE TABLE [dbo].[Salary]
(
[SalaryID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[EmploymentID] [uniqueidentifier] NOT NULL,
[EffectiveDate] [date] NOT NULL,
[Amount] [money] NOT NULL,
[SalaryPeriod] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateVerified] [datetime] NULL,
[VerifiedByPersonID] [uniqueidentifier] NULL,
[VerificationSources] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IncomeDate] [date] NULL,
[IncomeAmount] [money] NULL,
[IncomeHoursPerWeek] [int] NULL,
[IncomePeriod] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OvertimeRate] [money] NULL,
[OvertimeHoursPerWeek] [int] NULL,
[OvertimeFrequency] [int] NULL,
[AnticipatedRateDate] [date] NULL,
[AnticipatedRateAmount] [money] NULL,
[AnticipatedRateHoursPerWeek] [int] NULL,
[AnticipatedRatePeriod] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CalculatorIsHourly] [bit] NOT NULL,
[UseCalculator] [bit] NOT NULL,
[HUDAmount] [money] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Salary] ADD CONSTRAINT [PK_SalaryID] PRIMARY KEY CLUSTERED  ([SalaryID], [AccountID]) ON [PRIMARY]
GO
