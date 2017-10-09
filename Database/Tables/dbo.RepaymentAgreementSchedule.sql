CREATE TABLE [dbo].[RepaymentAgreementSchedule]
(
[RepaymentAgreementScheduleID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RepaymentAgreementID] [uniqueidentifier] NOT NULL,
[DueDate] [datetime] NOT NULL,
[Amount] [int] NOT NULL,
[RepaymentAgreementChargeTransactionID] [uniqueidentifier] NULL,
[ActualPayDate] [datetime] NULL,
[PaymentMade] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RepaymentAgreementSchedule] ADD CONSTRAINT [PK_RepaymentAgreementSchedule] PRIMARY KEY CLUSTERED  ([RepaymentAgreementScheduleID], [AccountID]) ON [PRIMARY]
GO
