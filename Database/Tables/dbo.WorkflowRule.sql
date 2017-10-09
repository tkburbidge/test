CREATE TABLE [dbo].[WorkflowRule]
(
[WorkflowRuleID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[WorkflowID] [uniqueidentifier] NOT NULL,
[ApprovalWorkflowGroupID] [uniqueidentifier] NOT NULL,
[GroupOrderBy] [smallint] NOT NULL,
[RuleIsAnded] [bit] NOT NULL,
[IsDeleted] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkflowRule] ADD CONSTRAINT [PK_WorkflowRule] PRIMARY KEY CLUSTERED  ([WorkflowRuleID], [AccountID]) ON [PRIMARY]
GO
