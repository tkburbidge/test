CREATE TABLE [dbo].[FormLetterField]
(
[FormLetterFieldID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[FormLetterID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsCustomField] [bit] NOT NULL,
[OrderBy] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[FormLetterField] ADD CONSTRAINT [PK_FormLetterField] PRIMARY KEY CLUSTERED  ([FormLetterFieldID], [AccountID]) ON [PRIMARY]
GO
