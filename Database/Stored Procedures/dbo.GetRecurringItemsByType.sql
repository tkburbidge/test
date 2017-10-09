SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 27, 2013
-- Description:	Gets the Recurring Items for a given type
-- =============================================
CREATE PROCEDURE [dbo].[GetRecurringItemsByType]	
	@accountID bigint = null,	
	@itemType nvarchar(50) = null,
	@date date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT RecurringItemID, AccountID, PersonID, Name, AssignedToPersonID
		FROM RecurringItem
		WHERE ItemType = @itemType
		  AND ((@accountID IS NULL) OR (AccountID = @accountID))
		  AND StartDate <= @date
		  AND (EndDate IS NULL OR EndDate >= @date)		  
		  AND Frequency IS NOT NULL
		  AND (Frequency = 'Daily' OR DayToRun IS NOT NULL)
		  AND (
				(Frequency = 'Daily' AND (DATEDIFF(day, StartDate, @date) %  RepeatsEvery) = 0)
				OR (					
					(Frequency = 'Weekly') AND 
					(DayToRun = DATEPART(WEEKDAY, @date)) AND
					((DATEDIFF(DAY, StartDate, @date) % (7 * RepeatsEvery)) < 7)					
				)
				OR (
					(Frequency = 'Monthly') AND
					((DayToRun = DATEPART(DAY, @date))
					  -- Post on last day of month if day to run happens to be greater than last day of month (we save 32 if 'last day' is chosen)
					  OR (DayToRun >= DATEPART(day,EOMONTH(@date)) AND DATEPART(day,EOMONTH(@date)) = DATEPART(day, @date)))
					  ---- Post on 2/28 if the start date is after the 28th and we are in February
					  --OR (DATEPART(MONTH, @date) = 2 AND DATEPART(DAY, @date) = 28 AND DATEPART(DAY, StartDate) >= 28)
					  ---- Post on the 30th if the start date is the 31st of the month and we are in a month with only 30 days
					  --OR (DATEPART(MONTH, @date) IN (4, 6, 9, 11) AND DATEPART(DAY, @date) = 30 AND DATEPART(DAY, StartDate) = 31))
					AND
					((DATEDIFF(MONTH, StartDate, @date) % RepeatsEvery) = 0)
				)
				OR (
					(Frequency = 'Yearly') AND 
					(DATEPART(DAY, @date) = DATEPART(DAY, StartDate)) AND 
					(DATEPART(MONTH, @date) = DATEPART(MONTH, StartDate)) AND
					(DATEDIFF(YEAR, StartDate, @date) % RepeatsEvery = 0)
				)				
			  )	  
END


GO
