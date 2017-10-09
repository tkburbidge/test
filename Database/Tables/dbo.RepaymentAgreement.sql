CREATE TABLE [dbo].[RepaymentAgreement]
(
[RepaymentAgreementID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AgreementType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AgreementID] [nvarchar] (12) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AgreementStartDate] [datetime] NOT NULL,
[AgreementEndDate] [datetime] NOT NULL,
[TotalRequestedAmount] [int] NULL,
[InternalStatus] [nvarchar] (8) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[HUDStatus] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[OwnerSignedDate] [datetime] NULL,
[TenantSignedDate] [datetime] NULL,
[Locked] [bit] NOT NULL,
[DateCreated] [datetime] NOT NULL,
[LeaseID] [uniqueidentifier] NOT NULL,
[AffordableProgramAllocationID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RepaymentAgreement] ADD CONSTRAINT [PK_RepaymentAgreement] PRIMARY KEY CLUSTERED  ([RepaymentAgreementID], [AccountID]) ON [PRIMARY]
GO
