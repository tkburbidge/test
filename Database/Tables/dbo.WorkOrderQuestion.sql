CREATE TABLE [dbo].[WorkOrderQuestion]
(
[WorkOrderQuestionID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Question] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ResponseType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[TopLevel] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WorkOrderQuestion] ADD CONSTRAINT [PK_WorkOrderQuestion] PRIMARY KEY CLUSTERED  ([WorkOrderQuestionID], [AccountID]) ON [PRIMARY]
GO
