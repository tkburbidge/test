CREATE TABLE [dbo].[OwnerProperty]
(
[OwnerPropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[OwnerID] [uniqueidentifier] NOT NULL,
[VendorPropertyID] [uniqueidentifier] NOT NULL,
[DistributionGLAccountID] [uniqueidentifier] NOT NULL,
[EquityGLAccountID] [uniqueidentifier] NOT NULL,
[DateInactive] [date] NULL,
[PaymentMethod] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[OwnerProperty] ADD CONSTRAINT [PK_OwnerPropertyID] PRIMARY KEY CLUSTERED  ([OwnerPropertyID], [AccountID]) ON [PRIMARY]
GO
