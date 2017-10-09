CREATE TABLE [dbo].[CertificationAsset]
(
[CertificationAssetID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[CertificationID] [uniqueidentifier] NOT NULL,
[AssetValueID] [uniqueidentifier] NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Description] [varchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CashValue] [money] NOT NULL,
[AnnualIncome] [money] NOT NULL,
[HudAnnualIncome] [money] NULL,
[CurrentValue] [money] NOT NULL,
[Type] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Status] [varchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[VerificationSources] [varchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateDivested] [date] NULL,
[DateVerified] [date] NULL,
[VerifiedByPersonName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[CertificationAsset] ADD CONSTRAINT [PK__Certific__A4CF96588467DF85] PRIMARY KEY CLUSTERED  ([CertificationAssetID]) ON [PRIMARY]
GO
