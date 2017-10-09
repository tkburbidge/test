CREATE TABLE [dbo].[WorkOrderNextQuestion]
(
[WorkOrderNextQuestionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[WorkOrderResponseID] [uniqueidentifier] NOT NULL,
[NextWorkOrderQuestionID] [uniqueidentifier] NOT NULL,
[OrderBy] [smallint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkOrderNextQuestion] ADD CONSTRAINT [PK_WorkOrderNextQuestion] PRIMARY KEY CLUSTERED  ([WorkOrderNextQuestionID], [AccountID]) ON [PRIMARY]
GO
