SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

 

create procedure [dbo].[css_monitor_dmvs]

       @target_duration int = 5000, --milliseconds

       @polling_interval tinyint = 10 --seconds

as

begin

       set nocount on

       declare @runtime datetime

       declare @ms int

       declare @msg varchar(100)

       declare @count int

       declare @rows int

       declare @polling_string varchar(20)

       declare @five_min_count smallint

      

       declare @sqltext as TABLE (

             [sql_handle] [varbinary](64) NOT NULL

       )

 

       declare @plans as TABLE (

             [plan_handle] [varbinary](64) NOT NULL

       )

 

       if @polling_interval < 1 or @polling_interval > 60

       begin

             raiserror ('css_monitor_dmvs: Invalid polling_interval parameter (must be between 1 and 60 seconds',16,1)

             return

       end

      

       if @target_duration < 100 or @target_duration > 60000

       begin

             raiserror ('css_monitor_dmvs: Invalid target_duration parameter (must be between 100 and 60000 milliseconds',16,1)

             return

       end

      

       if @polling_interval = 60

       begin

             set @polling_string = '00:01:00'

             set @five_min_count = 5

       end

       else

       begin

             if @polling_interval >= 10

             begin

                    set @polling_string = '00:00:' + LTRIM(STR(@polling_interval))

             end

             else

             begin

                    set @polling_string = '00:00:0' + LTRIM(STR(@polling_interval))

             end

 

             set @five_min_count = 300 / @polling_interval

       end

      

       set @runtime = GetUTCDate ()

       insert [dbo].[css_monitor_dmv_runs]

             select @runtime, @@SPID

       set @msg = CONVERT(varchar(24),@runtime,121)

       raiserror(@msg,10,1) with nowait

 

       set @count = 1

 

       while (1=1)

       begin

             set @runtime = GetUTCDate ()

             insert dbo.[dm_exec_sessions_saved]

                    select @runtime, session_id, login_time, [host_name], host_process_id, cpu_time,total_elapsed_time, last_request_start_time, last_request_end_time,

                    reads, writes, logical_reads, transaction_isolation_level, row_count, prev_error, open_transaction_count, [login_name]

                    from [sys].[dm_exec_sessions]

                    where prev_error != 0

                    or (open_transaction_count > 0 and session_id != @@SPID)

                    or datediff(ms, last_request_start_time, last_request_end_time) >= @target_duration

      

             --use named transaction to exclude transaction adding rows from inclusion

             begin tran css_monitor_dmvs

                    insert dbo.[dm_tran_active_transactions_saved]

                           select @runtime, transaction_id, [name], transaction_begin_time, transaction_type, transaction_state, transaction_status, transaction_status2

                           from sys.dm_tran_active_transactions

                           where [name] != 'css_monitor_dmvs'

             commit tran

 

             --Insert into exec requests saved each time a query shows as greater than our target duration

             insert into [dbo].[dm_exec_requests_saved]

                    ([runtime], [session_id], [start_time], [status], [command], [sql_handle],

                    [plan_handle], [blocking_session_id], [wait_type], [wait_time], [wait_resource],

                    [cpu_time], [total_elapsed_time], [reads], [writes], [logical_reads])

                    select

                           @runtime as runtime

                           , a.[session_id]

                           , a.[start_time]

                           , a.[status]

                           , a.[command]

                           , a.[sql_handle]

                           , a.[plan_handle]

                           , a.[blocking_session_id]

                           , a.[wait_type]

                           , a.[wait_time]

                           , a.[wait_resource]

                           , a.[cpu_time]

                           , a.[total_elapsed_time]

                           , a.[reads]

                           , a.[writes]

                           , a.[logical_reads]

                    from sys.dm_exec_requests a

                    where a.[total_elapsed_time] >= @target_duration

                           and a.[session_id] != @@SPID

            

             set @rows = @@ROWCOUNT

 

             if @rows > 0

             begin

            

                    insert into [dbo].[dm_exec_query_stats_saved]

                           ([runtime], [plan_handle], [creation_time], [statement_start_offset], [statement_end_offset],

                           [plan_generation_num], [execution_count], [total_worker_time], [max_worker_time],

                           [total_physical_reads], [max_physical_reads], [total_logical_writes], [max_logical_writes],

                           [total_logical_reads], [max_logical_reads], [total_elapsed_time], [max_elapsed_time],

                           [total_rows], [max_rows])

                           select

                                 @runtime as runtime

                                 , b.[plan_handle]

                                 , b.[creation_time]

                                 , b.[statement_start_offset]

                                 , b.[statement_end_offset]

                                 , b.[plan_generation_num]

                                 , b.[execution_count]

                                 , b.[total_worker_time]

                                 , b.[max_worker_time]

                                 , b.[total_physical_reads]

                                 , b.[max_physical_reads]

                                 , b.[total_logical_writes]

                                 , b.[max_logical_writes]

                                 , b.[total_logical_reads]

                                 , b.[max_logical_reads]

                                 , b.[total_elapsed_time]

                                 , b.[max_elapsed_time]

                                 , b.[total_rows]

                                 , b.[max_rows]

                           from sys.dm_exec_query_stats b

                           where b.plan_handle in

                                 (select plan_handle from [dbo].[dm_exec_requests_saved] where [runtime] = @runtime)

                                

                    begin try

                           insert @sqltext ([sql_handle])

                                 select distinct c.[sql_handle]

                                 from [dbo].[dm_exec_requests_saved] c

                                 where c.[sql_handle] not in

                                        (select distinct [sql_handle] from [dbo].[dm_exec_sql_text_saved])

                                        and c.[runtime] = @runtime

                    end try

                    begin catch

                           --do nothing

                    end catch

            

                    insert into [dbo].[dm_exec_sql_text_saved] ([sql_handle], [text])

                           select c.[sql_handle], d.[text]

                           from @sqltext c

                           cross apply sys.dm_exec_sql_text (c.[sql_handle]) d

            

                    --finally, add the plan if it doesn't exist already

                    begin try

                           insert into @plans ([plan_handle])

                                 select distinct e.[plan_handle]

                                 from [dbo].[dm_exec_requests_saved] e

                                 where e.[runtime] = @runtime

                                        and e.[plan_handle] not in (select distinct plan_handle from [dbo].[dm_exec_query_plan_saved])

                    end try

                    begin catch

                           --do nothing

                    end catch

 

                    insert into [dbo].[dm_exec_query_plan_saved] ([plan_handle], [query_plan])

                           select e.[plan_handle], f.query_plan

                           from @plans e

                           cross apply sys.dm_exec_query_plan (e.[plan_handle]) f

 

                    delete @sqltext

                    delete @plans

                   

             end

 

             set @ms = DATEDIFF(ms,@runtime,GETUTCDATE())

 

             if @ms > 1000

             begin

                    insert long_data_collection values (@runtime,@ms)

             end

 

             if @count % @five_min_count = 0

             begin

                    set @msg = CONVERT(varchar(24),@runtime,121)

                    raiserror(@msg,10,1) with nowait

             end

 

             set @count = @count + 1

 

             waitfor delay @polling_string

       end --End of While loop

end --End of procedure definition
GO
