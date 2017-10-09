SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Olsen
-- Create date: 1/10/2014
-- Description:	Get property status
-- =============================================
CREATE PROCEDURE [dbo].[GetPropertyStatus]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
-- SET NOCOUNT ON added to prevent extra result sets from
-- interfering with SELECT statements.
SET NOCOUNT ON;
		
	-- Create temp table with all data needed
	CREATE TABLE #PropertyStatus 
	(
		PropertyID uniqueidentifier,
		PropertyAbbreviation nvarchar(100),		
		CurrentPeriodName nvarchar(100),
		CurrentPeriodStartDate date,
		CurrentPeriodEndDate date,
		RecurringChargesPosted bit,	
		LastLateFeePostedDate date null,
		UnclosedPeriodCount int,
		OldestUnclosedPeriodName nvarchar(100) null
	)		
		
	-- CurrentPeriod, Recurring Charges
	INSERT INTO #PropertyStatus
		SELECT p.PropertyID, p.Abbreviation, ap.Name, pap.StartDate, pap.EndDate, pap.RecurringChargesPosted, null, 0, ''
			FROM Property p
			INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyAccountingPeriodID = p.CurrentPropertyAccountingPeriodID
			INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = pap.AccountingPeriodID
		WHERE p.AccountID = @accountID
			AND p.PropertyID IN (SELECT Value FROM @propertyIDs)
		ORDER BY p.Abbreviation

	-- Last Late Fee Posted
	DECLARE @lateFeeLedgerItemTypeID uniqueidentifier = (SELECT LateFeeLedgerItemTypeID
														 FROM Settings
														 WHERE AccountID = @accountID)			
					
	UPDATE #PropertyStatus SET LastLateFeePostedDate = (SELECT MAX(t.TransactionDate)
														FROM [Transaction] t				
														INNER JOIN PropertyLateFeeSchedule plfs ON plfs.PropertyID = #PropertyStatus.PropertyID
														INNER JOIN LateFeeSchedule lfs ON lfs.LateFeeScheduleID = plfs.LateFeeScheduleID AND lfs.IsRentSchedule = 1
														WHERE t.PropertyID = #PropertyStatus.PropertyID
															AND t.LedgerItemTypeID = lfs.LedgerItemTypeID
															AND t.TransactionDate >= #PropertyStatus.CurrentPeriodStartDate
															AND t.TransactionDate <= #PropertyStatus.CurrentPeriodEndDate)				
		
	-- Unclosed Period Count														
	UPDATE #PropertyStatus SET UnclosedPeriodCount = (SELECT COUNT(*)
													  FROM PropertyAccountingPeriod pap														
													  WHERE pap.PropertyID = #PropertyStatus.PropertyID
														AND pap.Closed = 0
														AND pap.EndDate < #PropertyStatus.CurrentPeriodStartDate)
		
							
	-- Oldest Unclosed Period
	UPDATE #PropertyStatus SET OldestUnclosedPeriodName = (SELECT TOP 1 ap.Name
														   FROM PropertyAccountingPeriod pap
															INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = pap.AccountingPeriodID
														   WHERE pap.PropertyID = #PropertyStatus.PropertyID
															AND pap.Closed = 0
															AND pap.EndDate < #PropertyStatus.CurrentPeriodStartDate
														   ORDER BY pap.EndDate)
		
	SELECT * FROM #PropertyStatus					    
    
END
GO
