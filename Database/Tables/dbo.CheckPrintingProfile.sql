CREATE TABLE [dbo].[CheckPrintingProfile]
(
[CheckPrintingProfileID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SignatureLineText] [nvarchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SignatureLines] [int] NOT NULL,
[VoucherLine2] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PrintCheckNumber] [bit] NOT NULL,
[PrintCompanyInfo] [bit] NOT NULL,
[PrintBankInfo] [bit] NOT NULL,
[PrintMICRLine] [bit] NOT NULL,
[CheckNumberTopOffset] [int] NOT NULL,
[CheckNumberLeftOffset] [int] NOT NULL,
[DateTopOffset] [int] NOT NULL,
[DateLeftOffset] [int] NOT NULL,
[PayToTopOffset] [int] NOT NULL,
[PayToLeftOffset] [int] NOT NULL,
[WrittenAmountTopOffset] [int] NOT NULL,
[WrittenAmountLeftOffset] [int] NOT NULL,
[PayToAddressTopOffset] [int] NOT NULL,
[PayToAddressLeftOffset] [int] NOT NULL,
[MemoTopOffset] [int] NOT NULL,
[MemoLeftOffset] [int] NOT NULL,
[CompanyInfoTopOffset] [int] NOT NULL,
[CompanyInfoLeftOffset] [int] NOT NULL,
[BankInfoTopOffset] [int] NOT NULL,
[BankInfoLeftOffset] [int] NOT NULL,
[MICRTopOffset] [int] NOT NULL,
[MICRLeftOffset] [int] NOT NULL,
[SignatureTopOffset] [int] NOT NULL,
[SignatureLeftOffset] [int] NOT NULL,
[Voucher1TopOffset] [int] NOT NULL,
[Voucher1LeftOffset] [int] NOT NULL,
[Voucher2TopOffset] [int] NOT NULL,
[Voucher2LeftOffset] [int] NOT NULL,
[PrintDateLine] [bit] NOT NULL,
[PrintPayToLabel] [bit] NOT NULL,
[PrintPayToLine] [bit] NOT NULL,
[PrintAmountLabel] [bit] NOT NULL,
[PrintAmountLine] [bit] NOT NULL,
[PrintTextAmountLine] [bit] NOT NULL,
[PrintMemoLabel] [bit] NOT NULL,
[PrintMemoLine] [bit] NOT NULL,
[AmountLeftOffset] [int] NOT NULL,
[AmountTopOffset] [int] NOT NULL,
[Signature1LeftOffset] [int] NOT NULL,
[Signature1TopOffset] [int] NOT NULL,
[Signature2LeftOffset] [int] NOT NULL,
[Signature2TopOffset] [int] NOT NULL,
[VendorCustomerNumberTopOffset] [int] NOT NULL,
[VendorCustomerNumberLeftOffset] [int] NOT NULL,
[PrintVendorCustomerNumber] [bit] NOT NULL,
[SecondSignatureThreshold] [money] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CheckPrintingProfile] ADD CONSTRAINT [PK_CheckPrintingProfile] PRIMARY KEY CLUSTERED  ([CheckPrintingProfileID], [AccountID]) ON [PRIMARY]
GO