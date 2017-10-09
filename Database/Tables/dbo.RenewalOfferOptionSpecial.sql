CREATE TABLE [dbo].[RenewalOfferOptionSpecial]
(
[RenewalOfferOptionID] [uniqueidentifier] NOT NULL,
[SpecialID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RenewalOfferOptionSpecial] ADD CONSTRAINT [PK_RenewalOfferOptionSpecial] PRIMARY KEY CLUSTERED  ([RenewalOfferOptionID], [SpecialID], [AccountID]) ON [PRIMARY]
GO
