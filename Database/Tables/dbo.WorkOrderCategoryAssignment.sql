CREATE TABLE [dbo].[WorkOrderCategoryAssignment]
(
[WorkOrderCategoryAssignmentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[PickListItemID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkOrderCategoryAssignment] ADD CONSTRAINT [PK_WorkOrderCategoryAssignment] PRIMARY KEY CLUSTERED  ([WorkOrderCategoryAssignmentID], [AccountID]) ON [PRIMARY]
GO
