CREATE TABLE [dbo].[FormLetter]
(
[FormLetterID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[Name] [nvarchar] (150) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Category] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DocumentID] [uniqueidentifier] NOT NULL,
[PropertyOrGroupID] [uniqueidentifier] NULL,
[VerificationLetterID] [int] NULL,
[IsSystem] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[FormLetter] ADD CONSTRAINT [PK_FormLetter] PRIMARY KEY CLUSTERED  ([FormLetterID], [AccountID]) ON [PRIMARY]
GO
