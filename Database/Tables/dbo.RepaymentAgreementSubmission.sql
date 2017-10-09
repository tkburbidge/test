CREATE TABLE [dbo].[RepaymentAgreementSubmission]
(
[RepaymentAgreementSubmissionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RepaymentAgreementID] [uniqueidentifier] NOT NULL,
[HUDStatus] [varchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[BeginningAgreementAmount] [int] NOT NULL,
[AgreementChangeAmount] [int] NOT NULL,
[EndingAgreementAmount] [int] NOT NULL,
[BeginningBalance] [int] NOT NULL,
[TotalPayment] [int] NOT NULL,
[EndingBalance] [int] NOT NULL,
[AmountRetained] [int] NOT NULL,
[AmountRequested] [int] NOT NULL,
[PaidAmount] [int] NULL
) ON [PRIMARY]
GO
