CREATE TABLE [dbo].[CertificationSalary]
(
[CertificationSalaryID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CertificationID] [uniqueidentifier] NOT NULL,
[SalaryID] [uniqueidentifier] NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Employer] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SalaryAmount] [money] NOT NULL,
[HudSalaryAmount] [money] NULL,
[Period] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[TaxCreditType] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[VerificationSources] [varchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateVerified] [date] NULL,
[VerifiedByPersonName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Type] [varchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CertificationSalary] ADD CONSTRAINT [PK__Certific__673E4D4DECA34D64] PRIMARY KEY CLUSTERED  ([CertificationSalaryID]) ON [PRIMARY]
GO
