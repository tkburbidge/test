CREATE TABLE [dbo].[RenewalOfferOption]
(
[RenewalOfferOptionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RenewalOfferID] [uniqueidentifier] NOT NULL,
[LeaseTermID] [uniqueidentifier] NULL,
[LeaseTermDuration] [int] NULL,
[Rent] [money] NOT NULL,
[IsBaseOption] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RenewalOfferOption] ADD CONSTRAINT [PK_RenewalOfferOption] PRIMARY KEY CLUSTERED  ([RenewalOfferOptionID], [AccountID]) ON [PRIMARY]
GO
