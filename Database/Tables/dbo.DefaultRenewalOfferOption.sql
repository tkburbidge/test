CREATE TABLE [dbo].[DefaultRenewalOfferOption]
(
[DefaultRenewalOfferOptionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LeaseTermID] [uniqueidentifier] NULL,
[LeaseTermDuration] [int] NULL,
[RenewalOfferBatchID] [uniqueidentifier] NOT NULL,
[AdjustmentAmount] [money] NOT NULL,
[AdjustmentType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[MinimumRent] [money] NULL,
[MaximumRent] [money] NULL,
[IsBaseOption] [bit] NOT NULL,
[AdjustmentStartValue] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DefaultRenewalOfferOption] ADD CONSTRAINT [PK_DefaultRenewalOfferOption] PRIMARY KEY CLUSTERED  ([DefaultRenewalOfferOptionID], [AccountID]) ON [PRIMARY]
GO
