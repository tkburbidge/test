CREATE TABLE [dbo].[dm_exec_query_plan_saved]
(
[plan_handle] [varbinary] (64) NOT NULL,
[query_plan] [xml] NULL,
[creation_time] [datetime] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[dm_exec_query_plan_saved] ADD CONSTRAINT [PK_dm_exec_query_plan_saved] PRIMARY KEY CLUSTERED  ([plan_handle]) ON [PRIMARY]
GO
