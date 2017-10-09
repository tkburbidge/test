CREATE TABLE [dbo].[VendorPaymentTemplate]
(
[VendorPaymentTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[BankAccountID] [uniqueidentifier] NOT NULL,
[PaymentMethod] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[VendorID] [uniqueidentifier] NOT NULL,
[IsCredit] [bit] NOT NULL,
[Memo] [nvarchar] (75) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RecurringItemID] [uniqueidentifier] NOT NULL,
[DoNotUpdateNextCheckNumber] [bit] NOT NULL,
[Signature1PersonID] [uniqueidentifier] NULL,
[Signature2PersonID] [uniqueidentifier] NULL,
[Amount] [money] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[VendorPaymentTemplate] ADD CONSTRAINT [PK_VendorPayemntTemplate] PRIMARY KEY CLUSTERED  ([VendorPaymentTemplateID], [AccountID]) ON [PRIMARY]
GO
