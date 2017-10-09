CREATE TABLE [dbo].[OwnerDistributionLineItem]
(
[OwnerDistributionLineItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[OwnerDistributionID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[OwnerDistributionLineItem] ADD CONSTRAINT [PK_OwnerDistributionLineItem] PRIMARY KEY CLUSTERED  ([OwnerDistributionLineItemID], [AccountID]) ON [PRIMARY]
GO
