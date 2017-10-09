CREATE TABLE [dbo].[ApplicantInformation]
(
[AccountID] [bigint] NOT NULL,
[ApplicantInformationID] [uniqueidentifier] NOT NULL,
[LeaseID] [uniqueidentifier] NULL,
[ReferringAgency] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ReferringAgent] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ReferringPerson] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ReferringMethod] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Smokers] [bit] NOT NULL,
[HasPaid] [bit] NOT NULL,
[DateCreated] [datetime] NOT NULL,
[OriginatedOnline] [bit] NOT NULL CONSTRAINT [DF__tmp_ms_xx__Origi__5BC376B8] DEFAULT ((0)),
[IPAddress] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DateSubmitted] [datetime] NULL,
[IsPaymentPending] [bit] NOT NULL,
[DocumentID] [uniqueidentifier] NULL,
[LastCompletedStep] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[MoveInDate] [date] NULL,
[UnitID] [uniqueidentifier] NULL,
[ApplicantTypeID] [uniqueidentifier] NULL,
[FutureUnitLeaseGroupID] [uniqueidentifier] NOT NULL,
[LeaseTerm] [int] NULL,
[QuoteID] [uniqueidentifier] NULL,
[PricingID] [uniqueidentifier] NULL,
[LeaseTermName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[GuarantorForApplicantInformationID] [uniqueidentifier] NULL,
[IsGuarantor] [bit] NOT NULL CONSTRAINT [DF__Applicant__ISGua__5812E165] DEFAULT ((0)),
[LeaseEnvelopeID] [uniqueidentifier] NULL,
[CurrentStep] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ApplicantInformation] ADD CONSTRAINT [PK_ApplicantInformation] PRIMARY KEY CLUSTERED  ([ApplicantInformationID], [AccountID]) ON [PRIMARY]
GO
