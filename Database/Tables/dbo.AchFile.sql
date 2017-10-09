CREATE TABLE [dbo].[AchFile]
(
[AchFileID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[DateCreated] [datetime] NOT NULL,
[CreatedByPersonID] [uniqueidentifier] NOT NULL,
[BankAccountID] [uniqueidentifier] NOT NULL,
[FileIDModifier] [nvarchar] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FileHeaderReferenceCode] [nvarchar] (8) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FileText] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[AchFile] ADD CONSTRAINT [PK_AchFile] PRIMARY KEY CLUSTERED  ([AchFileID], [AccountID]) ON [PRIMARY]
GO
