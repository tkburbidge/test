SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
CREATE PROCEDURE [dbo].[RPT_WKO_MaintenanceStats] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @augmentedStartDate DateTime,
			@augmentedEndDate DateTime,
			@loopDate DateTime

	IF @accountingPeriodID IS NOT NULL
	BEGIN
		SELECT @startDate = ap.StartDate, @endDate = ap.EndDate
			FROM AccountingPeriod ap
			WHERE ap.AccountingPeriodID = @accountingPeriodID
	END

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs 
		SELECT Value FROM @propertyIDs

	CREATE TABLE #MaintenanceStats (
		PropertyID				uniqueidentifier		not null,
		WorkOrderID				uniqueidentifier		null,
		[Status]				nvarchar(50)			null,
		ReportedDate			datetime				null,	
		CompletedDate			datetime				null,
		MinutesDifference		int						null)
		
	CREATE TABLE #FinalNumbers (
		PropertyID				uniqueidentifier		not null,
		PropertyName			nvarchar(50)			not null,
		Under8					int						null,
		Over8Under24			int						null,
		Over24Under48			int						null,
		Over48Under72			int						null,
		Over72					int						null,
		NotDoneYet				int						null,
		Unknown					int						null)
	
	-- This is a table that contains a row for each day that falls in our augmented date range (for each property too)
	CREATE TABLE #WorkableHours(
		PropertyID				uniqueidentifier		not null,
		Today					int						not null,
		WorkDate				datetime				not null,
		DayStartTime			time					null,
		DayEndTime				time					null,
		WorkableMinutes			int						not null)

	-- We don't care about Canceled work orders, we don't have to do any reporting on those here
	-- Just put NULL for minutes difference right now, we're going to calculate that later in three seperate queries
	-- Find all of the work orders in the date range, then from those work orders we'll figure out 
	-- which one happens earliest and which happens latest to shrink our date range window
	INSERT #MaintenanceStats
		SELECT wo.PropertyID, wo.WorkOrderID, wo.[Status], wo.ReportedDateTime, wo.CompletedDate, null
			FROM WorkOrder wo
			INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = wo.PropertyID
			WHERE wo.ReportedDate >= @startDate
			  AND wo.ReportedDate <= @endDate
			  AND wo.[Status] NOT IN ('Cancelled')
			  AND wo.UnitNoteID IS NULL
			  AND AccountID = @accountID


	-- Narrow our Date Range Window to encompass the Min and Max Work Order and nothing more
	SELECT @augmentedStartDate = MIN(ReportedDate), @augmentedEndDate = MAX(DATEADD(d, 1, CompletedDate))
	FROM #MaintenanceStats
	WHERE [Status] IN ('Closed', 'Completed')
		  AND CompletedDate IS NOT NULL
	-- Start the loop at the date of the first earliest work order
	SELECT @loopDate = @augmentedStartDate

	--Populate the WorkableHours table with a row for each day in the new augmented date range
	WHILE @loopDate <= @augmentedEndDate
	BEGIN
		INSERT INTO #WorkableHours
			SELECT PropertyID, 
				   DATEPART(dw, @loopDate), 
				   @loopDate,
				   -- Of course we only put in a start time if it actually exists and it's not marked as a full day of maintenance hours
				   CASE 
						WHEN DATEPART(dw, @loopDate) = 1 AND SundayFull = 0 AND SundayStart IS NOT NULL THEN SundayStart
						WHEN DATEPART(dw, @loopDate) = 2 AND MondayFull = 0 AND MondayStart IS NOT NULL THEN MondayStart 
						WHEN DATEPART(dw, @loopDate) = 3 AND TuesdayFull = 0 AND TuesdayStart IS NOT NULL THEN TuesdayStart 
						WHEN DATEPART(dw, @loopDate) = 4 AND WednesdayFull = 0 AND WednesdayStart IS NOT NULL THEN WednesdayStart 
						WHEN DATEPART(dw, @loopDate) = 5 AND ThursdayFull = 0 AND ThursdayStart IS NOT NULL THEN ThursdayStart 
						WHEN DATEPART(dw, @loopDate) = 6 AND FridayFull = 0 AND FridayStart IS NOT NULL THEN FridayStart 
						WHEN DATEPART(dw, @loopDate) = 7 AND SaturdayFull = 0 AND SaturdayStart IS NOT NULL THEN SaturdayStart 
						ELSE NULL
				   END,
				   CASE  
						WHEN DATEPART(dw, @loopDate) = 1 AND SundayFull = 0 AND SundayEnd IS NOT NULL THEN SundayEnd 
						WHEN DATEPART(dw, @loopDate) = 2 AND MondayFull = 0 AND MondayEnd IS NOT NULL THEN MondayEnd 
						WHEN DATEPART(dw, @loopDate) = 3 AND TuesdayFull = 0 AND TuesdayEnd IS NOT NULL THEN TuesdayEnd
						WHEN DATEPART(dw, @loopDate) = 4 AND WednesdayFull = 0 AND WednesdayEnd IS NOT NULL THEN WednesdayEnd
						WHEN DATEPART(dw, @loopDate) = 5 AND ThursdayFull = 0 AND ThursdayEnd IS NOT NULL THEN ThursdayEnd
						WHEN DATEPART(dw, @loopDate) = 6 AND FridayFull = 0 AND FridayEnd IS NOT NULL THEN FridayEnd
						WHEN DATEPART(dw, @loopDate) = 7 AND SaturdayFull = 0 AND SaturdayEnd IS NOT NULL THEN SaturdayEnd
						ELSE NULL
				   END,
				   CASE 
						WHEN DATEPART(dw, @loopDate) = 1 AND SundayFull = 0 AND SundayStart IS NOT NULL AND SundayEnd IS NOT NULL THEN DATEDIFF(MINUTE, SundayStart, SundayEnd)
						WHEN DATEPART(dw, @loopDate) = 2 AND MondayFull = 0 AND MondayStart IS NOT NULL AND MondayEnd IS NOT NULL THEN DATEDIFF(MINUTE, MondayStart, MondayEnd)
						WHEN DATEPART(dw, @loopDate) = 3 AND TuesdayFull = 0 AND TuesdayStart IS NOT NULL AND TuesdayEnd IS NOT NULL THEN DATEDIFF(MINUTE, TuesdayStart, TuesdayEnd)
						WHEN DATEPART(dw, @loopDate) = 4 AND WednesdayFull = 0 AND WednesdayStart IS NOT NULL AND WednesdayEnd IS NOT NULL THEN DATEDIFF(MINUTE, WednesdayStart, WednesdayEnd)
						WHEN DATEPART(dw, @loopDate) = 5 AND ThursdayFull = 0 AND ThursdayStart IS NOT NULL AND ThursdayEnd IS NOT NULL THEN DATEDIFF(MINUTE, ThursdayStart, ThursdayEnd)
						WHEN DATEPART(dw, @loopDate) = 6 AND FridayFull = 0 AND FridayStart IS NOT NULL AND FridayEnd IS NOT NULL THEN DATEDIFF(MINUTE, FridayStart, FridayEnd)
						WHEN DATEPART(dw, @loopDate) = 7 AND SaturdayFull = 0 AND SaturdayStart IS NOT NULL AND SaturdayEnd IS NOT NULL THEN DATEDIFF(MINUTE, SaturdayStart, SaturdayEnd) 
						ELSE 1440 -- Minutes in a 24 hour day, if it's Full = 1 then the whole day counts
				   END
			FROM MaintenanceHours
			WHERE PropertyID IN (SELECT PropertyID FROM #PropertyIDs)
		SELECT @loopDate = DATEADD(d, 1, @loopDate)
	END		

	-- Get the minutes available in the first day, time between the Reported Date and the end of the hours or day
	UPDATE #MaintenanceStats SET MinutesDifference = ISNULL(
		 (SELECT CASE WHEN #wh.DayEndTime IS NULL 
					  THEN DATEDIFF(MINUTE, #ms.ReportedDate, CAST (CAST(#ms.ReportedDate AS DATE) AS DATETIME) + '23:59:59.997') + 1
		  ELSE DATEDIFF(MINUTE, 
				CASE WHEN (CAST(#ms.ReportedDate AS TIME) > #wh.DayStartTime AND CAST(#ms.ReportedDate AS TIME) <= #wh.DayEndTime) 
				     THEN CAST(#ms.ReportedDate AS TIME)
					 WHEN (CAST(#ms.ReportedDate AS TIME) <= #wh.DayStartTime) 
					 THEN CAST(#wh.DayStartTime AS TIME)
					 ELSE #wh.DayEndTime 
				END, #wh.DayEndTime) END
		 FROM #WorkableHours #wh
		 INNER JOIN #MaintenanceStats #ms ON #wh.PropertyID = #ms.PropertyID AND CAST(#ms.ReportedDate AS Date) = CAST(#wh.WorkDate AS Date)
		 WHERE #MaintenanceStats.[Status] IN ('Closed', 'Completed')
			   AND #MaintenanceStats.CompletedDate IS NOT NULL
			   AND DATEPART(DAYOFYEAR, #ms.ReportedDate) <> DATEPART(DAYOFYEAR, #ms.CompletedDate)
			   AND #ms.WorkOrderID = #MaintenanceStats.WorkOrderID)
	 , 0)
	WHERE #MaintenanceStats.[Status] IN ('Closed', 'Completed') AND #MaintenanceStats.CompletedDate IS NOT NULL
	
	-- Get the minutes available in the last day, time between the Hours or Day start and the Completed Date
	UPDATE #MaintenanceStats SET #MaintenanceStats.MinutesDifference = #MaintenanceStats.MinutesDifference + ISNULL(
		(SELECT CASE WHEN ((DATEPART(DAYOFYEAR, #ms.ReportedDate) = DATEPART(DAYOFYEAR, #ms.CompletedDate)) AND (#ms.ReportedDate < #ms.CompletedDate))
					 THEN DATEDIFF(MINUTE, #ms.ReportedDate, #ms.CompletedDate)
					 WHEN ((DATEPART(DAYOFYEAR, #ms.ReportedDate) = DATEPART(DAYOFYEAR, #ms.CompletedDate)) AND (#ms.ReportedDate > #ms.CompletedDate))
					 THEN 0
					 WHEN #wh.DayStartTime IS NULL
				     THEN DATEDIFF(MINUTE, CAST (CAST(#ms.CompletedDate AS DATE) AS DATETIME), #ms.CompletedDate)
		 ELSE DATEDIFF(MINUTE, #wh.DayStartTime,
				CASE WHEN (CAST(#ms.CompletedDate AS TIME) > #wh.DayStartTime AND CAST(#ms.CompletedDate AS TIME) <= #wh.DayEndTime) 
					 THEN CAST(#ms.CompletedDate AS TIME)
					 WHEN (CAST(#ms.CompletedDate AS TIME) > #wh.DayStartTime) 
					 THEN CAST(#wh.DayEndTime AS TIME)
					 WHEN (CAST(#ms.CompletedDate AS TIME) < #wh.DayStartTime)
					 THEN #wh.DayStartTime
					 ELSE #wh.DayStartTime 
				END) END
		 FROM #WorkableHours #wh
		 INNER JOIN #MaintenanceStats #ms ON #wh.PropertyID = #ms.PropertyID AND CAST(#ms.CompletedDate AS Date) = CAST(#wh.WorkDate AS Date)
		 WHERE #MaintenanceStats.[Status] IN ('Closed', 'Completed')
			   AND #MaintenanceStats.CompletedDate IS NOT NULL
			   AND #ms.WorkOrderID = #MaintenanceStats.WorkOrderID)
	 , 0)
	WHERE #MaintenanceStats.[Status] IN ('Closed', 'Completed') AND #MaintenanceStats.CompletedDate IS NOT NULL


	-- Get the middle days, this is easier because we know that we just need the whole day or the whole "Work Day"
	UPDATE #ms
	SET #ms.MinutesDifference = #ms.MinutesDifference + ISNULL(
		(SELECT TOP 1 SUM(WorkableMinutes) FROM #WorkableHours #wh
			WHERE #ms.PropertyID = #wh.PropertyID
				  AND ((#wh.WorkableMinutes = 1440 AND CAST(#wh.WorkDate AS Date) > CAST(#ms.ReportedDate AS Date) AND CAST(#wh.WorkDate AS Date) < CAST(#ms.CompletedDate AS Date)) 
					   OR (CAST(#wh.WorkDate AS Date) > CAST(#ms.ReportedDate AS Date) AND CAST(#wh.WorkDate AS Date) < CAST(#ms.CompletedDate AS Date))))
	 , 0)
	FROM #MaintenanceStats #ms
		  
	INSERT #FinalNumbers 
		SELECT PropertyID, Name, 0, 0, 0, 0, 0, 0, 0	
			FROM Property
			WHERE PropertyID IN (SELECT Value FROM @propertyIDs)
			  AND AccountID = @accountID
			
	UPDATE #FinalNumbers SET Under8 = (SELECT COUNT(*)
										   FROM #MaintenanceStats 
										   WHERE MinutesDifference <= (60 * (SELECT MaintenanceStat1 FROM Settings WHERE AccountID = @accountID))
										     AND PropertyID = #FinalNumbers.PropertyID
										   GROUP BY PropertyID) 
										   
	UPDATE #FinalNumbers SET Over8Under24 = (SELECT COUNT(*)
											     FROM #MaintenanceStats 
											     WHERE MinutesDifference > (60 * (SELECT MaintenanceStat1 FROM Settings WHERE AccountID = @accountID))
												   AND MinutesDifference <= (60 * (SELECT MaintenanceStat2 FROM Settings WHERE AccountID = @accountID))
												   AND PropertyID = #FinalNumbers.PropertyID
											     GROUP BY PropertyID)
										   
	UPDATE #FinalNumbers SET Over24Under48 = (SELECT COUNT(*)
												FROM #MaintenanceStats 
												WHERE MinutesDifference > (60 * (SELECT MaintenanceStat2 FROM Settings WHERE AccountID = @accountID))
												  AND MinutesDifference <= (60 * (SELECT MaintenanceStat3 FROM Settings WHERE AccountID = @accountID))
												  AND PropertyID = #FinalNumbers.PropertyID
												GROUP BY PropertyID) 
										   
	UPDATE #FinalNumbers SET Over48Under72 = (SELECT COUNT(*)
											      FROM #MaintenanceStats 
											      WHERE MinutesDifference > (60 * (SELECT MaintenanceStat3 FROM Settings WHERE AccountID = @accountID))
												   AND MinutesDifference <= (60 * (SELECT MaintenanceStat4 FROM Settings WHERE AccountID = @accountID))
												   AND PropertyID = #FinalNumbers.PropertyID
											      GROUP BY PropertyID) 											   											    										   
	
	UPDATE #FinalNumbers SET Over72 = (SELECT COUNT(*)
										   FROM #MaintenanceStats 
										   WHERE MinutesDifference > (60 * (SELECT MaintenanceStat4 FROM Settings WHERE AccountID = @accountID))
										     AND PropertyID = #FinalNumbers.PropertyID
										   GROUP BY PropertyID) 
										   
	UPDATE #FinalNumbers SET Unknown = (SELECT COUNT(*)
										   FROM #MaintenanceStats 
										   WHERE MinutesDifference IS NULL
										     AND [Status] IN ('Closed', 'Completed')
										     AND PropertyID = #FinalNumbers.PropertyID
										   GROUP BY PropertyID) 
										   
	UPDATE #FinalNumbers SET NotDoneYet = (SELECT COUNT(*)
											   FROM #MaintenanceStats 
											   WHERE MinutesDifference IS NULL
												 AND [Status] NOT IN ('Closed', 'Completed')
												 AND PropertyID = #FinalNumbers.PropertyID
											   GROUP BY PropertyID) 
											   
	SELECT	PropertyID,
			PropertyName,
			ISNULL(Under8, 0) AS 'Under8',
			ISNULL(Over8Under24, 0) AS 'Over8Under24',
			ISNULL(Over24Under48, 0) AS 'Over24Under48',
			ISNULL(Over48Under72, 0) AS 'Over48Under72',
			ISNULL(Over72, 0) AS 'Over72',
			ISNULL(NotDoneYet, 0) AS 'NotDoneYet',
			ISNULL(Unknown, 0) AS 'Unknown'
		FROM #FinalNumbers 
		ORDER BY PropertyName											   									   											   		
END
GO
