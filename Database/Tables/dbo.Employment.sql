CREATE TABLE [dbo].[Employment]
(
[EmploymentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[AddressID] [uniqueidentifier] NULL,
[Employer] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Industry] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Title] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Salary] [money] NULL,
[CompanyPhone] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContactName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Type] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SalaryPeriod] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[StartDate] [date] NULL,
[EndDate] [datetime] NULL,
[TaxCreditType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Employment] ADD CONSTRAINT [PK_Employment] PRIMARY KEY CLUSTERED  ([EmploymentID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Employment] WITH NOCHECK ADD CONSTRAINT [FK_Employment_Person] FOREIGN KEY ([PersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
ALTER TABLE [dbo].[Employment] WITH NOCHECK ADD CONSTRAINT [FK_Employment_Person1] FOREIGN KEY ([PersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
ALTER TABLE [dbo].[Employment] NOCHECK CONSTRAINT [FK_Employment_Person]
GO
ALTER TABLE [dbo].[Employment] NOCHECK CONSTRAINT [FK_Employment_Person1]
GO
