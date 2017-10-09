CREATE TABLE [dbo].[WorkOrderResponse]
(
[WorkOrderResponseID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[WorkOrderQuestionID] [uniqueidentifier] NOT NULL,
[Answer] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkOrderResponse] ADD CONSTRAINT [PK_WorkOrderResponse] PRIMARY KEY CLUSTERED  ([WorkOrderResponseID], [AccountID]) ON [PRIMARY]
GO
