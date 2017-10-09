CREATE TABLE [dbo].[WorkOrderTemplateAssociation]
(
[WorkOrderTemplateAssociationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[WorkOrderTemplateID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkOrderTemplateAssociation] ADD CONSTRAINT [PK_WorkOrderTemplateAssociation] PRIMARY KEY CLUSTERED  ([WorkOrderTemplateAssociationID], [AccountID]) ON [PRIMARY]
GO
