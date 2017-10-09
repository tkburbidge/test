CREATE TABLE [dbo].[TaskAssignment]
(
[TaskAssignmentID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[AlertTaskID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[DateMarkedRead] [date] NULL,
[IsCarbonCopy] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[TaskAssignment] ADD CONSTRAINT [PK_TaskAssignment] PRIMARY KEY CLUSTERED  ([TaskAssignmentID], [AccountID]) ON [PRIMARY]
GO
