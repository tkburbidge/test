CREATE TABLE [dbo].[Service]
(
[ServiceID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Nearest] [bit] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Detail] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DistanceTo] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Comment] [nvarchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Service] ADD CONSTRAINT [PK_Service] PRIMARY KEY CLUSTERED  ([ServiceID], [AccountID]) ON [PRIMARY]
GO
