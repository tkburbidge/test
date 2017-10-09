SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 28, 2014
-- Description:	Gets the sum of all MarketRents for a given property, grouped by property
-- =============================================
CREATE PROCEDURE [dbo].[GetAllMarketRentsByPropertyID] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	-- Hack to take the first PropertyID but we are only ever calling this with one PropertyID
	DECLARE @propertyID uniqueidentifier = (SELECT TOP 1 Value FROM @propertyIDs)

	CREATE TABLE #MyMarketRents (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		Sequence int null,
		MarketRent money null)

	CREATE TABLE #MyAccountingPeriods (
		Sequence int identity,
		AccountingPeriodID uniqueidentifier not null,
		StartDate date not null,
		EndDate date not null)	 
		
	DECLARE @endDateByACPeriod date = (SELECT EndDate FROM PropertyAccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID AND PropertyID = @propertyID)
	DECLARE @startMonth int = (SELECT DATEPART(MONTH, @endDateByACPeriod))
	DECLARE @startYear int = (SELECT DATEPART(YEAR, @endDateByACPeriod))
	IF (@startMonth = 12)
	BEGIN
		SET @startMonth = 1
		SET @startYear = @startYear + 1				-- This makes the math work when we set startDate a couple of lines later
	END
	ELSE
	BEGIN
		SET @startMonth = @startMonth + 1
	END
	
	DECLARE @startDate date = (SELECT StartDate 
								  FROM PropertyAccountingPeriod
								  WHERE DATEPART(MONTH, EndDate) = @startMonth
								    AND DATEPART(YEAR, EndDate) = @startYear - 1
									AND AccountID = @accountID
									AND PropertyID = @propertyID)
						  
	INSERT #MyAccountingPeriods 
		SELECT AccountingPeriodID, StartDate, EndDate
			FROM PropertyAccountingPeriod
			WHERE StartDate >= @startDate
			  AND EndDate <= @endDateByACPeriod
			  AND AccountID = @accountID
			  AND PropertyID = @propertyID
			ORDER BY StartDate		
		
	INSERT #MyMarketRents
		SELECT p.PropertyID, u.UnitID, #myAPs.Sequence, null
			FROM Property p
				INNER JOIN UnitType ut ON p.PropertyID = ut.PropertyID
				INNER JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN #MyAccountingPeriods #myAPs ON 1=1
				INNER JOIN @propertyIDs pids ON p.PropertyID = pids.Value
			WHERE p.AccountID = @accountID
 
	UPDATE #mmr SET MarketRent = MarketRent.Amount
		FROM #MyMarketRents #mmr
			INNER JOIN #MyAccountingPeriods #myAPs ON #mmr.Sequence = #myAPs.Sequence
			CROSS APPLY GetMarketRentByDate(#mmr.UnitID, #myAPs.EndDate, 1) AS [MarketRent]
			
	SELECT	DISTINCT 
			PropertyID,
			SUM(CASE 
				WHEN (Sequence = 1) THEN MarketRent ELSE 0 END) AS 'Month1MarketRent',
			SUM(CASE 
				WHEN (Sequence = 2) THEN MarketRent ELSE 0 END) AS 'Month2MarketRent',
			SUM(CASE 
				WHEN (Sequence = 3) THEN MarketRent ELSE 0 END) AS 'Month3MarketRent',
			SUM(CASE 
				WHEN (Sequence = 4) THEN MarketRent ELSE 0 END) AS 'Month4MarketRent',
			SUM(CASE 
				WHEN (Sequence = 5) THEN MarketRent ELSE 0 END) AS 'Month5MarketRent',
			SUM(CASE 
				WHEN (Sequence = 6) THEN MarketRent ELSE 0 END) AS 'Month6MarketRent',
			SUM(CASE 
				WHEN (Sequence = 7) THEN MarketRent ELSE 0 END) AS 'Month7MarketRent',
			SUM(CASE 
				WHEN (Sequence = 8) THEN MarketRent ELSE 0 END) AS 'Month8MarketRent',
			SUM(CASE 
				WHEN (Sequence = 9) THEN MarketRent ELSE 0 END) AS 'Month9MarketRent',
			SUM(CASE 
				WHEN (Sequence = 10) THEN MarketRent ELSE 0 END) AS 'Month10MarketRent',
			SUM(CASE 
				WHEN (Sequence = 11) THEN MarketRent ELSE 0 END) AS 'Month11MarketRent',
			SUM(CASE 
				WHEN (Sequence = 12) THEN MarketRent ELSE 0 END) AS 'Month12MarketRent'																																										
		FROM #MyMarketRents
		GROUP BY PropertyID
END
GO
