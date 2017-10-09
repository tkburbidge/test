CREATE TABLE [dbo].[FormLetterCustomField]
(
[FormLetterCustomFieldID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[PropertyID] [uniqueidentifier] NOT NULL,
[Name] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Value] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[FormLetterCustomField] ADD CONSTRAINT [PK_FormLetterCustomField] PRIMARY KEY CLUSTERED  ([FormLetterCustomFieldID], [AccountID]) ON [PRIMARY]
GO
