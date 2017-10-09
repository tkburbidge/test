CREATE TABLE [dbo].[RentersInsurance]
(
[RentersInsuranceID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UnitLeaseGroupID] [uniqueidentifier] NOT NULL,
[RentersInsuranceType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[OtherProvider] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PolicyNumber] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContactName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContactPhoneNumber] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContactEmail] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[StartDate] [date] NULL,
[ExpirationDate] [date] NULL,
[Coverage] [money] NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IntegrationPartnerItemID] [int] NULL,
[DateCreated] [datetime] NOT NULL CONSTRAINT [DF_RentersInsurance_DateCreated] DEFAULT (getutcdate()),
[CancelDate] [date] NULL,
[ProviderType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ServiceProviderID] [uniqueidentifier] NULL,
[PolicyType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IntegrationPartnerItemPropertyID] [uniqueidentifier] NULL,
[PersonalCoverage] [money] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RentersInsurance] ADD CONSTRAINT [PK_RentersInsurance_1] PRIMARY KEY CLUSTERED  ([RentersInsuranceID], [AccountID]) ON [PRIMARY]
GO
