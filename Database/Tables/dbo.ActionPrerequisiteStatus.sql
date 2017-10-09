CREATE TABLE [dbo].[ActionPrerequisiteStatus]
(
[ActionPrerequisiteStatusID] [uniqueidentifier] NOT NULL,
[ActionPrerequisiteItemID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCompleted] [date] NULL,
[CompletedByPersonID] [uniqueidentifier] NULL,
[IsOverridden] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ActionPrerequisiteStatus] ADD CONSTRAINT [PK_ActionPrerequisiteStatus] PRIMARY KEY CLUSTERED  ([ActionPrerequisiteStatusID], [AccountID]) ON [PRIMARY]
GO
