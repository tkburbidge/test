CREATE TABLE [dbo].[dm_exec_requests_saved]
(
[runtime] [datetime] NOT NULL,
[session_id] [smallint] NOT NULL,
[start_time] [datetime] NOT NULL,
[status] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[command] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[sql_handle] [varbinary] (max) NULL,
[plan_handle] [varbinary] (max) NULL,
[blocking_session_id] [smallint] NULL,
[wait_type] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[wait_time] [int] NOT NULL,
[wait_resource] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[cpu_time] [int] NOT NULL,
[total_elapsed_time] [int] NOT NULL,
[reads] [bigint] NOT NULL,
[writes] [bigint] NOT NULL,
[logical_reads] [bigint] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[dm_exec_requests_saved] ADD CONSTRAINT [PK_dm_exec_requests_saved] PRIMARY KEY CLUSTERED  ([runtime], [session_id]) ON [PRIMARY]
GO
