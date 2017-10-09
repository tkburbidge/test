CREATE TABLE [dbo].[EmployeePayPeriod]
(
[EmployeePayPeriodID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NULL,
[PayPeriodID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[VerifiedByPersonID] [uniqueidentifier] NULL,
[ClockedIn] [datetime] NOT NULL,
[ClockedOut] [datetime] NULL,
[Type] [nchar] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Notes] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LunchDeduction] [int] NULL,
[AutoClockedOut] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[EmployeePayPeriod] ADD CONSTRAINT [PK_EmployeePayPeriod] PRIMARY KEY CLUSTERED  ([EmployeePayPeriodID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[EmployeePayPeriod] WITH NOCHECK ADD CONSTRAINT [FK_EmployeePayPeriod_PayPeriod] FOREIGN KEY ([PayPeriodID], [AccountID]) REFERENCES [dbo].[PayPeriod] ([PayPeriodID], [AccountID])
GO
ALTER TABLE [dbo].[EmployeePayPeriod] WITH NOCHECK ADD CONSTRAINT [FK_EmployeePayPeriod_Person] FOREIGN KEY ([PersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
ALTER TABLE [dbo].[EmployeePayPeriod] NOCHECK CONSTRAINT [FK_EmployeePayPeriod_PayPeriod]
GO
ALTER TABLE [dbo].[EmployeePayPeriod] NOCHECK CONSTRAINT [FK_EmployeePayPeriod_Person]
GO
