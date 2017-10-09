CREATE TABLE [dbo].[RenewalOfferBatch]
(
[RenewalOfferBatchID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[MinExpirationDate] [date] NULL,
[MaxExpirationDate] [date] NOT NULL,
[DateCreated] [date] NOT NULL,
[IncludeLeasesOnNotice] [bit] NOT NULL,
[IncludeLeasesWithExpiredOffers] [bit] NOT NULL,
[ValidRangeFixedStart] [date] NULL,
[ValidRangeFixedEnd] [date] NULL,
[ValidRangeRelativeStart] [int] NULL,
[ValidRangeRelativeEnd] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[RenewalOfferBatch] ADD CONSTRAINT [PK_RenewalOfferBatch] PRIMARY KEY CLUSTERED  ([RenewalOfferBatchID], [AccountID]) ON [PRIMARY]
GO
