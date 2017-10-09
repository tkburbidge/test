CREATE TABLE [dbo].[TaskTemplate]
(
[TaskTemplateID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[RecurringItemID] [uniqueidentifier] NOT NULL,
[AssignedByPersonID] [uniqueidentifier] NOT NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Importance] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Subject] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Message] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DaysUntilDue] [int] NOT NULL,
[IsAssignedtoPeople] [bit] NOT NULL,
[IsGroupTask] [bit] NOT NULL,
[IsCopiedToPeople] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TaskTemplate] ADD CONSTRAINT [PK_TaskTemplate] PRIMARY KEY CLUSTERED  ([TaskTemplateID], [AccountID]) ON [PRIMARY]
GO
