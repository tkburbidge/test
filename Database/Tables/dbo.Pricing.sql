CREATE TABLE [dbo].[Pricing]
(
[PricingID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PricingBatchID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LeaseTerm] [int] NOT NULL,
[StartDate] [date] NULL,
[EndDate] [date] NULL,
[BaseRent] [money] NOT NULL,
[Concession] [money] NOT NULL,
[EffectiveRent] [money] NOT NULL,
[ConcessionType] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ConcessionValue] [money] NOT NULL,
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Pricing] ADD CONSTRAINT [PK_Pricing] PRIMARY KEY CLUSTERED  ([PricingID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Pricing_ObjectID] ON [dbo].[Pricing] ([PricingBatchID], [ObjectID], [ObjectType]) ON [PRIMARY]
GO
