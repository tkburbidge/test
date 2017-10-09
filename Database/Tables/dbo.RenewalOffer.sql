CREATE TABLE [dbo].[RenewalOffer]
(
[RenewalOfferID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LeaseID] [uniqueidentifier] NOT NULL,
[RenewalOfferBatchID] [uniqueidentifier] NOT NULL,
[AcceptedRenewalOfferOptionID] [uniqueidentifier] NULL,
[Status] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CurrentRent] [money] NOT NULL,
[CurrentRentConcessions] [money] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RenewalOffer] ADD CONSTRAINT [PK_RenewalOfferLease] PRIMARY KEY CLUSTERED  ([RenewalOfferID], [AccountID]) ON [PRIMARY]
GO
