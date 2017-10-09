CREATE TABLE [dbo].[SuretyBond]
(
[SuretyBondID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[UnitLeaseGroupID] [uniqueidentifier] NOT NULL,
[IntegrationPartnerItemID] [int] NULL,
[ProviderName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PartnerBondID] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SuretyBondType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Price] [money] NOT NULL,
[Coverage] [money] NOT NULL,
[PetCoverage] [money] NOT NULL,
[PaidDate] [datetime] NULL,
[DateCreated] [datetime] NOT NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[BondPDFUrl] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[BondEmailUrl] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[BondPaymentUrl] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PaymentReceiptURL] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ScreeningResult] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PreferredLanguage] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Deleted] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SuretyBond] ADD CONSTRAINT [PK_SuretyBond] PRIMARY KEY CLUSTERED  ([SuretyBondID], [AccountID]) ON [PRIMARY]
GO
