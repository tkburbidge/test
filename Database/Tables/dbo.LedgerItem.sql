CREATE TABLE [dbo].[LedgerItem]
(
[LedgerItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[LedgerItemPoolID] [uniqueidentifier] NULL,
[AttachedToUnitID] [uniqueidentifier] NULL,
[Description] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Amount] [money] NOT NULL,
[IsDown] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LedgerItem] ADD CONSTRAINT [PK_AmenityService] PRIMARY KEY CLUSTERED  ([LedgerItemID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_LedgerItem_LedgerItemPoolID] ON [dbo].[LedgerItem] ([LedgerItemPoolID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_LedgerItem_LedgerItemTypeID] ON [dbo].[LedgerItem] ([LedgerItemTypeID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LedgerItem] WITH NOCHECK ADD CONSTRAINT [FK_AmenityService_AmenityServiceType] FOREIGN KEY ([LedgerItemTypeID], [AccountID]) REFERENCES [dbo].[LedgerItemType] ([LedgerItemTypeID], [AccountID])
GO
ALTER TABLE [dbo].[LedgerItem] WITH NOCHECK ADD CONSTRAINT [FK_LedgerItem_LedgerItemPool] FOREIGN KEY ([LedgerItemPoolID], [AccountID]) REFERENCES [dbo].[LedgerItemPool] ([LedgerItemPoolID], [AccountID])
GO
ALTER TABLE [dbo].[LedgerItem] NOCHECK CONSTRAINT [FK_AmenityService_AmenityServiceType]
GO
ALTER TABLE [dbo].[LedgerItem] NOCHECK CONSTRAINT [FK_LedgerItem_LedgerItemPool]
GO
