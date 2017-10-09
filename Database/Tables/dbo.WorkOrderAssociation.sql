CREATE TABLE [dbo].[WorkOrderAssociation]
(
[WorkOrderAssociationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[WorkOrderID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkOrderAssociation] ADD CONSTRAINT [PK_WorkOrderAssociation] PRIMARY KEY CLUSTERED  ([WorkOrderAssociationID], [AccountID]) ON [PRIMARY]
GO
