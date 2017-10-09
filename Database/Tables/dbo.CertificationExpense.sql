CREATE TABLE [dbo].[CertificationExpense]
(
[CertificationExpenseID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CertificationID] [uniqueidentifier] NOT NULL,
[AffordableExpenseAmountID] [uniqueidentifier] NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Type] [varchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [money] NOT NULL,
[VerificationSources] [varchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Period] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateVerified] [date] NULL,
[VerifiedByPersonName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CertificationExpense] ADD CONSTRAINT [PK__Certific__A9201F77C13762E9] PRIMARY KEY CLUSTERED  ([CertificationExpenseID]) ON [PRIMARY]
GO
