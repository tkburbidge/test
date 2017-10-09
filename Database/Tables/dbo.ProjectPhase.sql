CREATE TABLE [dbo].[ProjectPhase]
(
[ProjectPhaseID] [uniqueidentifier] NOT NULL,
[ProjectID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[StartDate] [date] NOT NULL,
[EndDate] [date] NULL,
[PhaseManagerPersonID] [uniqueidentifier] NOT NULL,
[StatusPickListItemID] [uniqueidentifier] NOT NULL,
[Notes] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProjectPhase] ADD CONSTRAINT [PK_ProjectPhase] PRIMARY KEY CLUSTERED  ([ProjectPhaseID], [ProjectID]) ON [PRIMARY]
GO
