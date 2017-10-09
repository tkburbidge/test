CREATE TABLE [dbo].[DefaultRenewalOfferOptionSpecial]
(
[DefaultRenewalOfferOptionID] [uniqueidentifier] NOT NULL,
[SpecialID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DefaultRenewalOfferOptionSpecial] ADD CONSTRAINT [PK_DefaultRenewalOfferOptionSpecial] PRIMARY KEY CLUSTERED  ([DefaultRenewalOfferOptionID], [SpecialID], [AccountID]) ON [PRIMARY]
GO
