CREATE TABLE [dbo].[AlertTask]
(
[AlertTaskID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AssignedByPersonID] [uniqueidentifier] NULL,
[ObjectID] [uniqueidentifier] NULL,
[ObjectType] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Type] [nvarchar] (8) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Importance] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateAssigned] [date] NOT NULL,
[DateMarkedRead] [date] NULL,
[DateDeleted] [date] NULL,
[DateStarted] [date] NULL,
[DateDue] [date] NULL,
[DateCompleted] [date] NULL,
[NotifiedViaEmail] [bit] NOT NULL,
[Subject] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Message] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TaskStatus] [nvarchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TimeToComplete] [decimal] (8, 3) NULL,
[PercentComplete] [int] NULL,
[CompletedPersonID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AlertTask] ADD CONSTRAINT [PK_Alert] PRIMARY KEY CLUSTERED  ([AlertTaskID], [AccountID]) ON [PRIMARY]
GO
