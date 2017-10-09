CREATE TABLE [dbo].[CreditReportingPerson]
(
[CreditReportingPersonID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[IntegrationPartnerItemID] [int] NOT NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CreditBureau] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SubscriptionSource] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CancelledLeaseID] [uniqueidentifier] NULL,
[IsActive] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CreditReportingPerson] ADD CONSTRAINT [PK_CreditReportingPerson] PRIMARY KEY CLUSTERED  ([CreditReportingPersonID], [AccountID]) ON [PRIMARY]
GO
