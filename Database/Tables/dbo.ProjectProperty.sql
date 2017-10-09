CREATE TABLE [dbo].[ProjectProperty]
(
[ProjectPropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ProjectID] [uniqueidentifier] NOT NULL,
[PropertyOrGroupID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[ProjectProperty] ADD CONSTRAINT [PK_ProjectProperty] PRIMARY KEY CLUSTERED  ([ProjectPropertyID], [AccountID]) ON [PRIMARY]
GO
