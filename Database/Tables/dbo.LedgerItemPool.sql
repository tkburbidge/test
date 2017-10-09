CREATE TABLE [dbo].[LedgerItemPool]
(
[LedgerItemPoolID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[LedgerItemTypeID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Amount] [money] NULL,
[IsDeleted] [bit] NOT NULL,
[SquareFootage] [int] NULL CONSTRAINT [DF__LedgerIte__Squar__2630A1B7] DEFAULT ((0)),
[MarketingDescription] [nvarchar] (400) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IncludeInOnlineApplication] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LedgerItemPool] ADD CONSTRAINT [PK_AmenityServicePool] PRIMARY KEY CLUSTERED  ([LedgerItemPoolID], [AccountID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[LedgerItemPool] WITH NOCHECK ADD CONSTRAINT [FK_AmenityServicePool_AmenityServiceType] FOREIGN KEY ([LedgerItemTypeID], [AccountID]) REFERENCES [dbo].[LedgerItemType] ([LedgerItemTypeID], [AccountID])
GO
ALTER TABLE [dbo].[LedgerItemPool] NOCHECK CONSTRAINT [FK_AmenityServicePool_AmenityServiceType]
GO
