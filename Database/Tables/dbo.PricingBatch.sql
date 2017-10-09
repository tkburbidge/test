CREATE TABLE [dbo].[PricingBatch]
(
[PricingBatchID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[IntegrationPartnerID] [int] NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[DatePosted] [date] NOT NULL,
[IsArchived] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PricingBatch] ADD CONSTRAINT [PK_PricingBatch] PRIMARY KEY CLUSTERED  ([PricingBatchID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PricingBatch_IntegrationPartnerID] ON [dbo].[PricingBatch] ([PricingBatchID], [IntegrationPartnerID]) ON [PRIMARY]
GO
