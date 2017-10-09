CREATE TABLE [dbo].[ProspectSource]
(
[ProspectSourceID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Abbreviation] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsArchived] [bit] NOT NULL,
[ShowOnOnlineApplication] [bit] NOT NULL,
[OnlineApplicationDisplayName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProspectSource] ADD CONSTRAINT [PK_TrafficSource] PRIMARY KEY CLUSTERED  ([ProspectSourceID], [AccountID]) ON [PRIMARY]
GO
