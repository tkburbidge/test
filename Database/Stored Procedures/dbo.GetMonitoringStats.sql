SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[GetMonitoringStats]
	-- Add the parameters for the stored procedure here
	@pastMinutes int = 3
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   CREATE TABLE #Stats (
		DatabaseName nvarchar(100),
		StartTime datetime,
		EndDate datetime, 
		MaxCPU decimal(4,2),
		MaxIO decimal(4,2),
		MaxMemory decimal(4,2),
		AverageCPU decimal(4,2),
		AverageIO decimal(4,2),
		AverageMemory decimal(4,2),
		CurrentRequests int,
		WaitingRequests int,
		MaxWaitTime int,
		ModeWaitType nvarchar(100)
	)


	INSERT INTO #Stats
		SELECT
				db_name(),
				 MIN(end_time) AS StartTime
				,MAX(end_time) AS EndTime
				,MAX(avg_cpu_percent) AS Max_CPU
				,MAX(avg_data_io_percent) AS Max_IO
				,MAX(avg_memory_usage_percent) AS Max_Memory    
				,CAST(AVG(avg_cpu_percent) AS decimal(4,2)) AS Avg_CPU
				--,MIN(avg_cpu_percent) AS Min_CPU
		
				,CAST(AVG(avg_data_io_percent) AS decimal(4,2)) AS Avg_IO
				--,MIN(avg_data_io_percent) AS Min_IO
		
				--,CAST(AVG(avg_log_write_percent) AS decimal(4,2)) AS Avg_LogWrite
				--,MIN(avg_log_write_percent) AS Min_LogWrite
				--,MAX(avg_log_write_percent) AS Max_LogWrite
				,CAST(AVG(avg_memory_usage_percent) AS decimal(4,2)) AS Avg_Memory
				--,MIN(avg_memory_usage_percent) AS Min_Memory  ,
				,0,0,0,''  
		
		FROM sys.dm_db_resource_stats
		WHERE end_time >= DATEADD(MINUTE, -@pastMinutes, GETDATE())

	UPDATE #Stats
		SET
			CurrentRequests = (select (COUNT(*) - 1) from sys.dm_exec_requests),
			WaitingRequests = (select COUNT(*) from sys.dm_exec_requests WHERE wait_type IS NOT NULL),
			MaxWaitTime =(select MAX(wait_time) from sys.dm_exec_requests),
			ModeWaitType = (select TOP 1 wait_type from sys.dm_exec_requests WHERE wait_type IS NOT NULL GROUP BY wait_type ORDER BY COUNT(*) DESC)


	SELECT * FROM #Stats

END
GO
