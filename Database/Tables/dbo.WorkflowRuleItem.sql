CREATE TABLE [dbo].[WorkflowRuleItem]
(
[WorkflowRuleItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[WorkflowRuleID] [uniqueidentifier] NOT NULL,
[MinimumThreshold] [money] NULL,
[MaximumThreshold] [money] NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[BudgetOverAmount] [money] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkflowRuleItem] ADD CONSTRAINT [PK_WorkflowRuleItem] PRIMARY KEY CLUSTERED  ([WorkflowRuleItemID], [AccountID]) ON [PRIMARY]
GO
