CREATE TABLE [dbo].[ProjectLocation]
(
[ProjectLocationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ProjectID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ObjectName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ProjectPhaseID] [uniqueidentifier] NULL,
[PropertyID] [uniqueidentifier] NULL,
[CompletedDate] [datetime] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProjectLocation] ADD CONSTRAINT [PK_ProjectLocation] PRIMARY KEY CLUSTERED  ([ProjectLocationID], [AccountID]) ON [PRIMARY]
GO
