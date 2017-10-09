CREATE TABLE [dbo].[PositivePayFile]
(
[PositivePayFileID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[DateSent] [datetime] NOT NULL,
[FileName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FileContents] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ResentDate] [datetime] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[PositivePayFile] ADD CONSTRAINT [PK_PositivePayFile] PRIMARY KEY CLUSTERED  ([AccountID], [PositivePayFileID]) ON [PRIMARY]
GO
