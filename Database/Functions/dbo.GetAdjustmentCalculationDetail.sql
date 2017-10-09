SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[GetAdjustmentCalculationDetail] 
(	
	-- Add the parameters for the function here
	@StartDate datetime,
	@EndDate datetime,
	@AssistancePayment int,
	@Negative bit = 0,
	@Zero bit = 0
)
RETURNS @Calculations TABLE(BeginningNoOfDays int NULL, BeginningDailyRate money NULL, NoOfMonths int NULL, MonthlyRate int NULL, 
							EndingNoOfDays int NULL, EndingDailyRate money NULL, Amount int)

AS
BEGIN
	
	IF @AssistancePayment IS NULL
	BEGIN
		SELECT @AssistancePayment = 0
	END

	-- Find which sections are going to have NULL values and do initial insert
	INSERT INTO @Calculations VALUES (
		--BeginningNoOfDays
		CASE 
			WHEN dbo.FirstOfMonth(@StartDate) = @StartDate AND @EndDate < EOMONTH(@StartDate)
			THEN DATEDIFF(D, @StartDate, @EndDate) + 1
			WHEN dbo.FirstOfMonth(@StartDate) <> @StartDate AND @EndDate <= EOMONTH(@StartDate)
			THEN DATEDIFF(D, @StartDate, @EndDate) + 1
			WHEN dbo.FirstOfMonth(@StartDate) <> @StartDate AND @EndDate > EOMONTH(@StartDate)
			THEN DATEDIFF(D, @StartDate, EOMONTH(@StartDate)) + 1
			ELSE NULL END,
		NULL, --BeginningDailyRate
		--NoOfMonths
		CASE
			WHEN @StartDate = dbo.FirstOfMonth(@StartDate) AND @EndDate = EOMONTH(@EndDate)
			THEN DATEDIFF(M, @StartDate, @EndDate) + 1
			WHEN @StartDate <> dbo.FirstOfMonth(@StartDate) AND @EndDate <> EOMONTH(@EndDate)
				 AND dbo.FirstOfMonth(@StartDate) <> dbo.FirstOfMonth(@EndDate)
			THEN DATEDIFF(M, @StartDate, @EndDate) - 1
			ELSE DATEDIFF(M, @StartDate, @EndDate)
		END, 
		NULL, --MonthlyRate
		--EndingNoOfDays
		CASE 
			--It's not on the last day of the last month
			WHEN CAST(@EndDate AS Date) <> EOMONTH(@EndDate) AND 
					@StartDate < dbo.FirstOfMonth(@EndDate) --It starts in a previous month
			THEN DATEDIFF(D, dbo.FirstOfMonth(@EndDate), @EndDate) + 1
			ELSE NULL END,
		NULL, -- EndingDailyRate
		0) --Amount

	-- Now find out the daily rates
	IF @Zero = 0
	BEGIN
		IF (SELECT BeginningNoOfDays FROM @Calculations) IS NOT NULL
		BEGIN
			UPDATE @Calculations SET BeginningDailyRate = 
				ROUND((CAST(@AssistancePayment AS money) / (DATEDIFF(D, dbo.FirstOfMonth(@StartDate), EOMONTH(@StartDate)) + 1)), 2)
		END
		IF (SELECT NoOfMonths FROM @Calculations) <> 0
		BEGIN
			UPDATE @Calculations SET MonthlyRate = @AssistancePayment
		END
		ELSE
		BEGIN
			UPDATE @Calculations SET NoOfMonths = NULL
		END
		IF (SELECT EndingNoOfDays FROM @Calculations) IS NOT NULL
		BEGIN
			UPDATE @Calculations SET EndingDailyRate = 
				ROUND((CAST(@AssistancePayment AS money) / (DATEDIFF(D, dbo.FirstOfMonth(@EndDate), EOMONTH(@EndDate)) + 1)), 2)
		END
	END
	ELSE
	BEGIN
		UPDATE @Calculations SET BeginningDailyRate = CASE WHEN BeginningNoOfDays IS NOT NULL THEN 0 ELSE NULL END, 
								 MonthlyRate = CASE WHEN NoOfMonths IS NOT NULL THEN 0 ELSE NULL END, 
								 EndingDailyRate = CASE WHEN EndingNoOfDays IS NOT NULL THEN 0 ELSE NULL END
	END

	UPDATE @Calculations SET Amount = (SELECT ((ISNULL(BeginningNoOfDays, 0) * ISNULL(BeginningDailyRate, 0)) +
												(ISNULL(NoOfMonths, 0) * ISNULL(MonthlyRate, 0)) +
												(ISNULL(EndingNoOfDays, 0) * ISNULL(EndingDailyRate, 0)))
												* (CASE WHEN @Negative = 1 THEN -1 ELSE 1 END))
	
	UPDATE @Calculations SET NoOfMonths = NULL WHERE NoOfMonths = 0
	UPDATE @Calculations SET MonthlyRate = NULL WHERE MonthlyRate = 0

	RETURN
END
GO
