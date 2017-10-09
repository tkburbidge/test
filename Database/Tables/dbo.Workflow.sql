CREATE TABLE [dbo].[Workflow]
(
[WorkflowID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCreated] [date] NOT NULL,
[WorkflowType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ExpenseTypeID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Workflow] ADD CONSTRAINT [PK_WorkFlow] PRIMARY KEY CLUSTERED  ([WorkflowID], [AccountID]) ON [PRIMARY]
GO
