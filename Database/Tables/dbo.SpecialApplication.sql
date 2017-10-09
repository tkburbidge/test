CREATE TABLE [dbo].[SpecialApplication]
(
[SpecialApplicationID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[SpecialID] [uniqueidentifier] NOT NULL,
[ObjectID] [uniqueidentifier] NOT NULL,
[ObjectType] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[SpecialApplication] ADD CONSTRAINT [PK_SpecialApplication] PRIMARY KEY CLUSTERED  ([SpecialApplicationID], [AccountID]) ON [PRIMARY]
GO
