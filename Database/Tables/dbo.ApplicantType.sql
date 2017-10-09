CREATE TABLE [dbo].[ApplicantType]
(
[ApplicantTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Forms] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsDefault] [bit] NOT NULL,
[DefaultIDNumberType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CollectUnitTypeDeposit] [bit] NOT NULL,
[CollectFeesImmediately] [bit] NOT NULL,
[CollectDepositsImmediately] [bit] NOT NULL,
[AutoScreenApplicant] [bit] NOT NULL,
[AllowInvitingRoommates] [bit] NOT NULL,
[DocuSignLeaseTemplateID] [uniqueidentifier] NULL,
[AutoGenerateLease] [bit] NOT NULL,
[AddressCount] [int] NULL,
[EmploymentCount] [int] NULL,
[LimitNumberOfApplicantsPerApplication] [bit] NOT NULL,
[MaxApplicantCount] [int] NULL,
[NewLeaseSignaturePackageID] [uniqueidentifier] NULL,
[DisplayScreeningResults] [bit] NOT NULL,
[AvailableForOnlineApplication] [bit] NOT NULL,
[OtherIncomeCount] [int] NULL,
[AssetCount] [int] NULL,
[ExpenseCount] [int] NULL,
[RentableItemsIncludeAttachedToUnits] [bit] NOT NULL,
[IsSystem] [bit] NOT NULL,
[ShowRentersInsuranceForm] [bit] NOT NULL,
[RequireRentersInsuranceProof] [bit] NOT NULL,
[IdentificationRequired] [bit] NOT NULL,
[DriversLicenseInfoRequired] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ApplicantType] ADD CONSTRAINT [PK_ApplicantType] PRIMARY KEY CLUSTERED  ([ApplicantTypeID], [AccountID]) ON [PRIMARY]
GO
