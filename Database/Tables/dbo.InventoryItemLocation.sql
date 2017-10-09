CREATE TABLE [dbo].[InventoryItemLocation]
(
[InventoryItemLocationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[InventoryItemID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[TransferredByPersonID] [uniqueidentifier] NOT NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NULL,
[Notes] [nvarchar] (400) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[InventoryItemLocation] ADD CONSTRAINT [PK_InventoryItemLocation] PRIMARY KEY CLUSTERED  ([InventoryItemLocationID], [AccountID]) ON [PRIMARY]
GO
