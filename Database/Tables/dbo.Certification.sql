CREATE TABLE [dbo].[Certification]
(
[CertificationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LeaseID] [uniqueidentifier] NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EffectiveDate] [date] NOT NULL,
[RecertificationDate] [date] NOT NULL,
[UtilityAllowance] [int] NULL,
[DateCompleted] [datetime] NULL,
[SignedTicDate] [date] NULL,
[Signed50059Date] [date] NULL,
[NoSignatureReason] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsCorrection] [bit] NOT NULL,
[CorrectionReason] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CorrectionEIVRelated] [bit] NOT NULL,
[TerminationReason] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[HUDTotalTenantPaymentOverride] [money] NULL,
[HUDTotalTenantPaymentOverrideReason] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[HUDTotalTenantPaymentOverridePersonID] [uniqueidentifier] NULL,
[OverIncome] [bit] NOT NULL,
[OwnerSigned50059Date] [datetime] NULL,
[HeadOfHouseholdPersonID] [uniqueidentifier] NULL,
[FromImport] [bit] NOT NULL,
[CorrectedByCertificationID] [uniqueidentifier] NULL,
[FinalTaxCreditAllocationID] [uniqueidentifier] NULL,
[FinalHUDAllocationID] [uniqueidentifier] NULL,
[TaxCreditTenantRent] [money] NULL,
[TaxCreditGrossRent] [money] NULL,
[HUDGrossRent] [money] NULL,
[HUDTenantRent] [money] NULL,
[Section8LIException] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TaxCreditIncomeLimit] [money] NULL,
[TaxCreditOverIncomeLimit] [money] NULL,
[TaxCreditMaxRent] [money] NULL,
[TaxCreditRentalAssistance] [money] NULL,
[HUDAdjustedIncome] [money] NULL,
[HUDTotalTenantPayment] [money] NULL,
[HUDAssistancePayment] [money] NULL,
[HUDUtilityReimbursement] [money] NULL,
[PreviousUnitID] [uniqueidentifier] NULL,
[PreviousBuildingID] [uniqueidentifier] NULL,
[UnitLeaseGroupID] [uniqueidentifier] NOT NULL,
[RentLeaseLedgerItemID] [uniqueidentifier] NULL,
[SubsidyLeaseLeaseLedgerItemID] [uniqueidentifier] NULL,
[TaxCreditRentalAssistanceLedgerItemID] [uniqueidentifier] NULL,
[FlaggedForRepayment] [bit] NOT NULL,
[CreatedDate] [datetime] NOT NULL,
[IsAutoCorrection] [bit] NOT NULL,
[AnticipatedVoucherDate] [datetime] NULL,
[CertificationGroupID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Certification] ADD CONSTRAINT [PK_Certification] PRIMARY KEY CLUSTERED  ([CertificationID], [AccountID]) ON [PRIMARY]
GO
