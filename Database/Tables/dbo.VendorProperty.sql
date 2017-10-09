CREATE TABLE [dbo].[VendorProperty]
(
[VendorPropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[VendorID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[TaxRateGroupID] [uniqueidentifier] NULL,
[BeginningBalanceYear] [int] NULL,
[BeginningBalance] [money] NULL,
[CustomerNumber] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[VendorProperty] ADD CONSTRAINT [PK_VendorProperty] PRIMARY KEY CLUSTERED  ([VendorPropertyID], [AccountID]) ON [PRIMARY]
GO
