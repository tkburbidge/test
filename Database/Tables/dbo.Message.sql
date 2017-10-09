CREATE TABLE [dbo].[Message]
(
[MessageID] [uniqueidentifier] NOT NULL,
[AccountID] [bigint] NOT NULL,
[MessageType] [nchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Text] [nchar] (3000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ImageUrl] [nchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ImageLocation] [nchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Message] ADD CONSTRAINT [PK_Message] PRIMARY KEY CLUSTERED  ([MessageID], [AccountID]) ON [PRIMARY]
GO
