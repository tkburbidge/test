CREATE TABLE [dbo].[SecurityGLAccount]
(
[SecurityGLAccountID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[GLAccountID] [uniqueidentifier] NOT NULL,
[HasAccess] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SecurityGLAccount] ADD CONSTRAINT [PK_SecurityGLAccount] PRIMARY KEY CLUSTERED  ([SecurityGLAccountID], [AccountID]) ON [PRIMARY]
GO
