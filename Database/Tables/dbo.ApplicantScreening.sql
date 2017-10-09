CREATE TABLE [dbo].[ApplicantScreening]
(
[ApplicantScreeningID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UnitLeaseGroupID] [uniqueidentifier] NOT NULL,
[LeaseID] [uniqueidentifier] NOT NULL,
[RequestorPersonID] [uniqueidentifier] NOT NULL,
[DateRequested] [date] NULL,
[IntegrationPartnerItemID] [int] NOT NULL,
[ApplicationID] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Status] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Notes] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ApplicationDecision] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsTransferred] [bit] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[ApplicantScreening] ADD CONSTRAINT [PK_ApplicantScreening] PRIMARY KEY CLUSTERED  ([ApplicantScreeningID], [AccountID]) ON [PRIMARY]
GO
