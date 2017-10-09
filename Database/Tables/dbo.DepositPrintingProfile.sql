CREATE TABLE [dbo].[DepositPrintingProfile]
(
[DepositPrintingProfileID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PrintCompanyInfo] [bit] NOT NULL,
[PrintSignature] [bit] NOT NULL,
[PrintBankInfo] [bit] NOT NULL,
[PrintMICRLine] [bit] NOT NULL,
[PrintFractionalNumber] [bit] NOT NULL,
[PrintTotalNumberDeposits] [bit] NOT NULL,
[PrintGrandTotal] [bit] NOT NULL,
[CompanyInfoTopOffset] [int] NOT NULL,
[CompanyInfoLeftOffset] [int] NOT NULL,
[DateTopOffset] [int] NOT NULL,
[DateLeftOffset] [int] NOT NULL,
[SignatureTopOffset] [int] NOT NULL,
[SignatureLeftOffset] [int] NOT NULL,
[BankInfoTopOffset] [int] NOT NULL,
[BankInfoLeftOffset] [int] NOT NULL,
[MICRTopOffset] [int] NOT NULL,
[MICRLeftOffset] [int] NOT NULL,
[FractionalNumberTopOffset] [int] NOT NULL,
[FractionalNumberLeftOffset] [int] NOT NULL,
[FirstCheckColumnTopOffset] [int] NOT NULL,
[FirstCheckColumnLeftOffset] [int] NOT NULL,
[SecondCheckColumnTopOffset] [int] NOT NULL,
[SecondCheckColumnLeftOffset] [int] NOT NULL,
[ThirdCheckColumnTopOffset] [int] NOT NULL,
[ThirdCheckColumnLeftOffset] [int] NOT NULL,
[TotalNumberDepositsTopOffset] [int] NOT NULL,
[TotalNumberDepositsLeftOffset] [int] NOT NULL,
[GrandTotalTopOffset] [int] NOT NULL,
[GrandTotalLeftOffset] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DepositPrintingProfile] ADD CONSTRAINT [PK_DepositPrintingProfile] PRIMARY KEY CLUSTERED  ([DepositPrintingProfileID], [AccountID]) ON [PRIMARY]
GO
