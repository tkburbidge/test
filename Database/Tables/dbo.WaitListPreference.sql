CREATE TABLE [dbo].[WaitListPreference]
(
[WaitListPersonID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[WaitListPreference] ADD CONSTRAINT [PK_WaitListPreference] PRIMARY KEY CLUSTERED  ([WaitListPersonID], [ObjectID]) ON [PRIMARY]
GO
