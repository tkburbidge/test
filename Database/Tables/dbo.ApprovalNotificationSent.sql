CREATE TABLE [dbo].[ApprovalNotificationSent]
(
[ApprovalNotificationSentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[WorkflowRuleID] [uniqueidentifier] NULL,
[Type] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateSent] [datetime] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ApprovalNotificationSent] ADD CONSTRAINT [PK_ApprovalNotificationSent] PRIMARY KEY CLUSTERED  ([ApprovalNotificationSentID], [AccountID]) ON [PRIMARY]
GO
