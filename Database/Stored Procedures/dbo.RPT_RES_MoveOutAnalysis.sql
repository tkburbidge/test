SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE PROCEDURE [dbo].[RPT_RES_MoveOutAnalysis]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate date null,
		EndDate date null,
		WasNULL bit not null)
	
	-- Get the end date and the start date
	-- Start date will be the end date of the same period a year
	-- prior plus one day
	--DECLARE @endDate DATE = (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
	--DECLARE @startDate DATE = (SELECT EndDate FROM AccountingPeriod WHERE DATEPART(MONTH, EndDate) = DATEPART(MONTH, @endDate)
	--																	AND DATEPART(Year, EndDate) = DATEPART(Year, DATEADD(year, -1, @endDate))
	--																	AND AccountID = @accountID)
	
	INSERT #PropertiesAndDates 
		SELECT	pIDs.Value, null, pap.EndDate, 0
			FROM @propertyIDs pIDs
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
				
	UPDATE #PropertiesAndDates SET StartDate = (SELECT pap.EndDate 
													FROM PropertyAccountingPeriod pap
													WHERE DATEPART(MONTH, pap.EndDate) = DATEPART(MONTH, #PropertiesAndDates.EndDate)
													  AND DATEPART(YEAR, pap.EndDate) = DATEPART(YEAR, DATEADD(year, -1, #PropertiesAndDates.EndDate))
													  AND pap.PropertyID = #PropertiesAndDates.PropertyID)
																		
	-- if the start period is not defined then set the start date to the end date less one year plus one day
	--IF (@startDate IS NULL)
	--BEGIN
	--	SET @startDate = DATEADD(year, -1, (DATEADD(day, 1, @endDate)))
	--END				
	--ELSE
	--BEGIN
	--	SET @startDate = DATEADD(DAY, 1, @startDate)
	--END
	
	UPDATE #PropertiesAndDates SET StartDate = DATEADD(YEAR, -1, (DATEADD(DAY, 1, EndDate))), WasNULL = 1
		WHERE StartDate IS NULL
		
	UPDATE #PropertiesAndDates SET StartDate = DATEADD(DAY, 1, StartDate)
		WHERE WasNULL = 0	
	
	SELECT DISTINCT 			
			p.Name AS 'PropertyName',
			p.PropertyID,	
			plic.Name AS 'CategoryName',								
			pl.ReasonForLeaving,			
			ap.EndDate 'PeriodEndDate',
			COUNT(DISTINCT l.LeaseID) AS 'MoveOuts'
		FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON p.PropertyID = b.PropertyID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID		
			INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID						
			--Join in PickListItem for the category
			INNER JOIN PickListItem pli on pli.Name = pl.ReasonForLeaving AND pli.[Type] = 'ReasonForLeaving' AND pli.AccountID = @accountID
			LEFT JOIN PickListItemCategory plic on plic.PickListItemCategoryID = pli.PickListItemCategoryID
			--LEFT JOIN AccountingPeriod ap ON ap.AccountID = @accountID AND pl.MoveOutDate >= ap.StartDate AND pl.MoveOutDate <= ap.EndDate
			LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pl.MoveOutDate >= pap.StartDate AND pl.MoveOutDate <= pap.EndDate
			LEFT JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID
			INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
		WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
								  FROM PersonLease pl2
								  WHERE pl2.LeaseID = l.LeaseID
									AND pl.ResidencyStatus IN ('Former', 'Evicted')
								  ORDER BY pl2.MoveOutDate DESC)
		  --AND pl.MoveOutDate >= @startDate
		  --AND pl.MoveOutDate <= @endDate
		  AND pl.MoveOutDate >= #pad.StartDate
		  AND pl.MoveOutDate <= #pad.EndDate
		  AND pl.ResidencyStatus IN ('Former', 'Evicted')
		  AND l.LeaseStatus IN ('Former', 'Evicted')
		GROUP BY ap.EndDate, ap.Name, p.Name, p.PropertyID, pl.ReasonForLeaving, plic.Name

END








GO
