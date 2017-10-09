CREATE TABLE [dbo].[PersonType]
(
[PersonTypeID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PersonType] ADD CONSTRAINT [PK_PersonType] PRIMARY KEY CLUSTERED  ([PersonTypeID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PersonType_PersonID] ON [dbo].[PersonType] ([PersonID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PersonType_Type] ON [dbo].[PersonType] ([Type]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PersonType] WITH NOCHECK ADD CONSTRAINT [FK_PersonType_Person] FOREIGN KEY ([PersonID], [AccountID]) REFERENCES [dbo].[Person] ([PersonID], [AccountID])
GO
ALTER TABLE [dbo].[PersonType] NOCHECK CONSTRAINT [FK_PersonType_Person]
GO
