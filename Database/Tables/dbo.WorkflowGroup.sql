CREATE TABLE [dbo].[WorkflowGroup]
(
[WorkflowGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsDeleted] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkflowGroup] ADD CONSTRAINT [PK_WorkflowGroup] PRIMARY KEY CLUSTERED  ([WorkflowGroupID], [AccountID]) ON [PRIMARY]
GO
