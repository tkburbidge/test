CREATE TABLE [dbo].[WorkflowRuleApproval]
(
[WorkflowRuleApprovalID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[WorkflowRuleID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ApproverPersonID] [uniqueidentifier] NULL,
[DateNotified] [date] NULL,
[DateApproved] [date] NULL,
[Status] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Note] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsArchived] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkflowRuleApproval] ADD CONSTRAINT [PK_WorkflowRuleApproval] PRIMARY KEY CLUSTERED  ([WorkflowRuleApprovalID], [AccountID]) ON [PRIMARY]
GO
