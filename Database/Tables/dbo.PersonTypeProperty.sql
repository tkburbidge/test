CREATE TABLE [dbo].[PersonTypeProperty]
(
[PersonTypePropertyID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonTypeID] [uniqueidentifier] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[PropertySelected] [bit] NOT NULL,
[PropertiesSelected] [bit] NOT NULL,
[HasAccess] [bit] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PersonTypeProperty] ADD CONSTRAINT [PK_PersonTypeProperty] PRIMARY KEY CLUSTERED  ([PersonTypePropertyID], [AccountID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PersonTypeProperty_PersonTypeID] ON [dbo].[PersonTypeProperty] ([PersonTypeID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_PersonTypeProperty_PropertyID] ON [dbo].[PersonTypeProperty] ([PropertyID]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PersonTypeProperty] WITH NOCHECK ADD CONSTRAINT [FK_PersonProperty_PersonType] FOREIGN KEY ([PersonTypeID], [AccountID]) REFERENCES [dbo].[PersonType] ([PersonTypeID], [AccountID])
GO
ALTER TABLE [dbo].[PersonTypeProperty] WITH NOCHECK ADD CONSTRAINT [FK_PersonProperty_Property] FOREIGN KEY ([PropertyID], [AccountID]) REFERENCES [dbo].[Property] ([PropertyID], [AccountID])
GO
ALTER TABLE [dbo].[PersonTypeProperty] NOCHECK CONSTRAINT [FK_PersonProperty_PersonType]
GO
ALTER TABLE [dbo].[PersonTypeProperty] NOCHECK CONSTRAINT [FK_PersonProperty_Property]
GO
