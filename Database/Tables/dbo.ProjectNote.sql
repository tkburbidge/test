CREATE TABLE [dbo].[ProjectNote]
(
[ProjectNoteID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ProjectID] [uniqueidentifier] NOT NULL,
[PhaseID] [uniqueidentifier] NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Date] [date] NOT NULL,
[Timestamp] [datetime] NOT NULL CONSTRAINT [DF_ProjectNote_Timestamp] DEFAULT (getutcdate()),
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Note] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProjectNote] ADD CONSTRAINT [PK_ProjectNote] PRIMARY KEY CLUSTERED  ([ProjectNoteID], [AccountID]) ON [PRIMARY]
GO
