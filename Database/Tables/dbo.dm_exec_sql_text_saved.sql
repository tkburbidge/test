CREATE TABLE [dbo].[dm_exec_sql_text_saved]
(
[sql_handle] [varbinary] (64) NOT NULL,
[text] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[dm_exec_sql_text_saved] ADD CONSTRAINT [PK_dm_exec_sql_text_saved] PRIMARY KEY CLUSTERED  ([sql_handle]) ON [PRIMARY]
GO
