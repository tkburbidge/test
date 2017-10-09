CREATE TABLE [dbo].[SecurityGLAccountType]
(
[SecurityGLAccountTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[GLAccountType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[HasAccess] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SecurityGLAccountType] ADD CONSTRAINT [PK_SecurityGLAccountType] PRIMARY KEY CLUSTERED  ([SecurityGLAccountTypeID], [AccountID]) ON [PRIMARY]
GO
