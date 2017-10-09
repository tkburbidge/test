CREATE TABLE [dbo].[Special]
(
[SpecialID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[StartDate] [date] NULL,
[EndDate] [date] NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Notes] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CreatedByPersonID] [uniqueidentifier] NOT NULL,
[Period] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [money] NOT NULL,
[AmountType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[StartMonth] [int] NOT NULL,
[Duration] [int] NOT NULL,
[MarketingDescription] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MarketingName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ShowOnAvailability] [bit] NOT NULL,
[IsEditable] [bit] NOT NULL,
[Prorate] [bit] NOT NULL,
[DateType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PriceDisplayType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ApplyToBuildingIDs] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ApplyToFloors] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RenewalOfferBatchID] [uniqueidentifier] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[Special] ADD CONSTRAINT [PK_Special] PRIMARY KEY CLUSTERED  ([SpecialID], [AccountID]) ON [PRIMARY]
GO
