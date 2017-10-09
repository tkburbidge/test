CREATE TABLE [dbo].[dm_exec_query_stats_saved]
(
[runtime] [datetime] NOT NULL,
[plan_handle] [varbinary] (64) NOT NULL,
[creation_time] [datetime] NOT NULL,
[statement_start_offset] [int] NOT NULL,
[statement_end_offset] [int] NOT NULL,
[plan_generation_num] [int] NOT NULL,
[execution_count] [bigint] NOT NULL,
[total_worker_time] [bigint] NOT NULL,
[max_worker_time] [bigint] NOT NULL,
[total_physical_reads] [bigint] NOT NULL,
[max_physical_reads] [bigint] NOT NULL,
[total_logical_writes] [bigint] NOT NULL,
[max_logical_writes] [bigint] NOT NULL,
[total_logical_reads] [bigint] NOT NULL,
[max_logical_reads] [bigint] NOT NULL,
[total_elapsed_time] [bigint] NOT NULL,
[max_elapsed_time] [bigint] NOT NULL,
[total_rows] [bigint] NOT NULL,
[max_rows] [bigint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dm_exec_query_stats_saved] ADD CONSTRAINT [PK_dm_exec_query_stats_saved] PRIMARY KEY CLUSTERED  ([runtime], [plan_handle], [statement_start_offset]) ON [PRIMARY]
GO
