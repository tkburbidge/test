CREATE TABLE [dbo].[VendorInsurance]
(
[VendorInsuranceID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[VendorID] [uniqueidentifier] NOT NULL,
[Provider] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PolicyNumber] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContactName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContactPhoneNumber] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ContactEmail] [nvarchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ExpirationDate] [date] NOT NULL,
[Coverage] [money] NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Type] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[VendorInsurance] ADD CONSTRAINT [PK_VendorInsurance] PRIMARY KEY CLUSTERED  ([VendorInsuranceID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[VendorInsurance] WITH NOCHECK ADD CONSTRAINT [FK_VendorInsurance_Vendor] FOREIGN KEY ([VendorID], [AccountID]) REFERENCES [dbo].[Vendor] ([VendorID], [AccountID])
GO
ALTER TABLE [dbo].[VendorInsurance] NOCHECK CONSTRAINT [FK_VendorInsurance_Vendor]
GO
