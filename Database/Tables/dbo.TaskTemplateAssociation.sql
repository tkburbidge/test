CREATE TABLE [dbo].[TaskTemplateAssociation]
(
[TaskTemplateAssociationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[TaskTemplateID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TaskTemplateAssociation] ADD CONSTRAINT [PK_TaskTemplateAssociation] PRIMARY KEY CLUSTERED  ([TaskTemplateAssociationID], [AccountID]) ON [PRIMARY]
GO
