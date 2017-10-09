CREATE TABLE [dbo].[dm_exec_sessions_saved]
(
[runtime] [datetime] NOT NULL,
[session_id] [smallint] NOT NULL,
[login_time] [datetime] NOT NULL,
[host_name] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[host_process_id] [int] NULL,
[cpu_time] [int] NULL,
[total_elapsed_time] [int] NULL,
[last_request_start_time] [datetime] NULL,
[last_request_end_time] [datetime] NULL,
[reads] [bigint] NULL,
[writes] [bigint] NULL,
[logical_reads] [bigint] NULL,
[transaction_isolation_level] [smallint] NULL,
[row_count] [bigint] NULL,
[prev_error] [int] NULL,
[open_transaction_count] [tinyint] NULL,
[login_name] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dm_exec_sessions_saved] ADD CONSTRAINT [dm_exec_sessions_saved_pk] PRIMARY KEY CLUSTERED  ([runtime], [session_id]) ON [PRIMARY]
GO
