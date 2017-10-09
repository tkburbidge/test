CREATE TABLE [dbo].[DocumentPerson]
(
[DocumentPersonID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[DocumentID] [uniqueidentifier] NOT NULL,
[PersonID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DocumentPerson] ADD CONSTRAINT [PK_DocumentPerson] PRIMARY KEY CLUSTERED  ([DocumentPersonID], [AccountID]) ON [PRIMARY]
GO
