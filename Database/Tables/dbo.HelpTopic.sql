CREATE TABLE [dbo].[HelpTopic]
(
[Topic] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Url] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[HelpTopic] ADD CONSTRAINT [PK_HelpTopic] PRIMARY KEY CLUSTERED  ([Topic]) ON [PRIMARY]
GO
