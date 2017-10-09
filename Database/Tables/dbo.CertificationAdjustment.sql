CREATE TABLE [dbo].[CertificationAdjustment]
(
[CertificationAdjustmentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CertificationID] [uniqueidentifier] NOT NULL,
[IsPrior] [bit] NOT NULL,
[BeginningDailyRate] [money] NULL,
[EndingDailyRate] [money] NULL,
[Amount] [int] NOT NULL,
[GroupNumber] [int] NOT NULL,
[NewCert] [bit] NOT NULL,
[CertType] [nvarchar] (5) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EffectiveDate] [date] NOT NULL,
[AssistancePayment] [int] NOT NULL,
[BeginningDate] [date] NOT NULL,
[EndingDate] [date] NOT NULL,
[BeginningNoOfDays] [int] NULL,
[NoOfMonths] [int] NULL,
[EndingNoOfDays] [int] NULL,
[Requested] [int] NULL,
[LastName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FirstName] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[MiddleInitial] [nvarchar] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[UnitNumber] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CertificationAdjustment] ADD CONSTRAINT [PK_CertificationAdjustment] PRIMARY KEY CLUSTERED  ([CertificationAdjustmentID], [AccountID]) ON [PRIMARY]
GO
