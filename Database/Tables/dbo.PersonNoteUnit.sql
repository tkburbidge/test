CREATE TABLE [dbo].[PersonNoteUnit]
(
[PersonNoteUnitID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PersonNoteID] [uniqueidentifier] NOT NULL,
[UnitID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[PersonNoteUnit] ADD CONSTRAINT [PK_PersonNoteUnit] PRIMARY KEY CLUSTERED  ([PersonNoteUnitID], [AccountID]) ON [PRIMARY]
GO
