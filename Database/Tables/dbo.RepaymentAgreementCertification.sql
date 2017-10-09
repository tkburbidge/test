CREATE TABLE [dbo].[RepaymentAgreementCertification]
(
[RepaymentAgreementCertificationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RepaymentAgreementID] [uniqueidentifier] NOT NULL,
[CertificationID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RepaymentAgreementCertification] ADD CONSTRAINT [PK_RepaymentAgreementCertification] PRIMARY KEY CLUSTERED  ([RepaymentAgreementCertificationID], [AccountID]) ON [PRIMARY]
GO
