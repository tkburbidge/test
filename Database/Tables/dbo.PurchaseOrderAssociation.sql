CREATE TABLE [dbo].[PurchaseOrderAssociation]
(
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[PurchaseOrderID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PurchaseOrderAssociation] ADD CONSTRAINT [PK_PurchaseOrderAssociation] PRIMARY KEY CLUSTERED  ([ObjectID], [AccountID], [PurchaseOrderID]) ON [PRIMARY]
GO
