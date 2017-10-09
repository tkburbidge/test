CREATE TABLE [dbo].[AffordableProgramTableGroup]
(
[AffordableProgramTableGroupID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsHUD] [bit] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AffordableProgramTableGroup] ADD CONSTRAINT [PK_AffordableProgramTableGroup] PRIMARY KEY CLUSTERED  ([AffordableProgramTableGroupID], [AccountID]) ON [PRIMARY]
GO
