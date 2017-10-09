CREATE TABLE [dbo].[RepaymentAgreementHistory]
(
[RepaymentAgreementHistoryID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RepaymentAgreementID] [uniqueidentifier] NOT NULL,
[Date] [datetime] NOT NULL,
[CreatedByPersonID] [uniqueidentifier] NULL,
[Description] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[RepaymentAgreementHistory] ADD CONSTRAINT [PK_RepaymentAgreementHistory] PRIMARY KEY CLUSTERED  ([RepaymentAgreementHistoryID], [AccountID]) ON [PRIMARY]
GO
