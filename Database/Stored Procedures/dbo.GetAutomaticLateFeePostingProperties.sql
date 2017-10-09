SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Olsen
-- Create date: June 18, 2014
-- Description:	Gets the data needed to post late fees automatically
-- =============================================
CREATE PROCEDURE [dbo].[GetAutomaticLateFeePostingProperties]
	@date date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT p.AccountID, p.PropertyID, p.Name AS 'PropertyName', ap.AccountingPeriodID, lit.Name AS 'LateFeeDescription', p.AutomaticLateFeePostingDelay, p.LateFeeAssessmentIncludePaymentsOnDay
	FROM Property p
	INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID
	INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = pap.AccountingPeriodID
	INNER JOIN Settings s ON s.AccountID = p.AccountID
	INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = s.LateFeeLedgerItemTypeID
    LEFT  JOIN LateFeePostingDate lfpd ON lfpd.PropertyID = p.PropertyID AND lfpd.AccountID = p.AccountID
	  AND datepart(YEAR, lfpd.Date) = datepart(YEAR, @date) AND datepart(MONTH, lfpd.Date) = datepart(MONTH, @date)
	WHERE  
		((p.AutomaticLateFeePostingDelay = 'None' AND pap.StartDate <= @date AND pap.EndDate >= @date)
		 OR (p.AutomaticLateFeePostingDelay = '1 Day' AND pap.StartDate <= DATEADD(DAY, -1, @date) AND pap.EndDate >= DATEADD(DAY, -1, @date)))
		AND pap.Closed = 0
		AND ( 
			 p.AutomaticLateFeeAssessmentPolicy = 'Auto' OR
			 (p.AutomaticLateFeeAssessmentPolicy = 'After Manual' AND pap.LateFeesAccessed = 1)
		)
		AND (
		 p.AutomaticLateFeeAssessmentPolicy != 'Auto' OR  -- In the case of Manual or After Manual we don't ever want to take into account LateFeePostingDate
		 lfpd.Date IS NULL OR
		 datepart(DAY, @date) >= datepart(DAY, lfpd.Date)
		)    

END
GO
