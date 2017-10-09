CREATE TABLE [dbo].[LeaseLedgerItem]
(
[LeaseLedgerItemID] [uniqueidentifier] NOT NULL,
[LeaseID] [uniqueidentifier] NOT NULL,
[LedgerItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Description] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Amount] [money] NOT NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NOT NULL,
[DateCreated] [datetime] NOT NULL CONSTRAINT [DF_LeaseLedgerItem_DateCreated] DEFAULT (getdate()),
[TaxRateGroupID] [uniqueidentifier] NULL,
[AmenityChargeID] [uniqueidentifier] NULL,
[SpecialID] [uniqueidentifier] NULL,
[SpecialModifiedByPersonID] [uniqueidentifier] NULL,
[PostingDay] [int] NULL,
[IsNonOptionalCharge] [bit] NULL,
[RentalAssistanceCharge] [bit] NOT NULL CONSTRAINT [DF__LeaseLedg__Renta__2DDCB077] DEFAULT ((0)),
[RentalAssistanceSource] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PostToHapLedger] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LeaseLedgerItem] ADD CONSTRAINT [PK_PersonUnitContractAmenityService] PRIMARY KEY CLUSTERED  ([LeaseLedgerItemID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_LeaseLedgerItem_EndDate] ON [dbo].[LeaseLedgerItem] ([EndDate]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_LeaseLedgerItem_LeaseID] ON [dbo].[LeaseLedgerItem] ([LeaseID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_LeaseLedgerItem_LedgerItemID] ON [dbo].[LeaseLedgerItem] ([LedgerItemID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_LeaseLedgerItem_StartDate] ON [dbo].[LeaseLedgerItem] ([StartDate]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LeaseLedgerItem] WITH NOCHECK ADD CONSTRAINT [FK_LeaseLedgerItem_LedgerItem] FOREIGN KEY ([LedgerItemID], [AccountID]) REFERENCES [dbo].[LedgerItem] ([LedgerItemID], [AccountID])
GO
ALTER TABLE [dbo].[LeaseLedgerItem] WITH NOCHECK ADD CONSTRAINT [FK_PersonUnitContractAmenityService_PersonUnitContract] FOREIGN KEY ([LeaseID], [AccountID]) REFERENCES [dbo].[Lease] ([LeaseID], [AccountID])
GO
ALTER TABLE [dbo].[LeaseLedgerItem] NOCHECK CONSTRAINT [FK_LeaseLedgerItem_LedgerItem]
GO
ALTER TABLE [dbo].[LeaseLedgerItem] NOCHECK CONSTRAINT [FK_PersonUnitContractAmenityService_PersonUnitContract]
GO
