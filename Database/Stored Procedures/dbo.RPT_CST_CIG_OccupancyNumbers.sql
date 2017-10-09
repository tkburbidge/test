SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 19, 2015
-- Description:	Gets the Custom CIG Occupancy Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_CIG_OccupancyNumbers] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PropertiesAndPeriods (
		Sequence					int null,
		PropertyID					uniqueidentifier not null,
		AccountingPeriodID			uniqueidentifier null,
		StartDate					date null,
		EndDate						date null,
		TotalDaysInPeriod			int null,
		MonthDatePart				int null
		)

	CREATE TABLE #Units (
		UnitID						uniqueidentifier not null,
		PropertyID					uniqueidentifier not null
		)
		
	CREATE TABLE #Activity (
		UnitID						uniqueidentifier not null,
		UnitLeaseGroupID			uniqueidentifier null,
		MoveInDate					date null,
		MoveOutDate					date null
		)
		
	CREATE TABLE #UnitDays (
		OrderMe						int identity,
		UnitID						uniqueidentifier not null,
		UnitLeaseGroupID			uniqueidentifier null,
		Sequence					int null,
		MoveInDate					date null,
		MoveOutDate					date null,
		VacantDays					int null,
		MonthDatePart				int null,
		DaysInMonth					int null
		)
		
	CREATE TABLE #ConsolodatedUnitDays (
		PropertyID					uniqueidentifier not null,
		UnitID						uniqueidentifier not null,
		--UnitLeaseGroupID			uniqueidentifier null,
		Sequence					int null,
		VacantDays					int null,
		DaysInMonth					int null
		)
		
	CREATE TABLE #SuperConsolodatedFinalNumbers (
		PropertyID					uniqueidentifier not null,
		UnitID						uniqueidentifier not null,
		Month1						int null,
		Month2						int null,
		Month3						int null,
		Month4						int null,
		Month5						int null,
		Month6						int null,
		Month7						int null,
		Month8						int null,
		Month9						int null,
		Month10						int null,
		Month11						int null,
		Month12						int null
		)
		
	CREATE TABLE #SuperConsolodatedFinalNumbers2 (
		PropertyID					uniqueidentifier not null,
		PropertyName				nvarchar(50) not null,
		Month1						decimal(7, 5) null,
		Month2						decimal(7, 5) null,
		Month3						decimal(7, 5) null,
		Month4						decimal(7, 5) null,
		Month5						decimal(7, 5) null,
		Month6						decimal(7, 5) null,
		Month7						decimal(7, 5) null,
		Month8						decimal(7, 5) null,
		Month9						decimal(7, 5) null,
		Month10						decimal(7, 5) null,
		Month11						decimal(7, 5) null,
		Month12						decimal(7, 5) null
		)

		
	DECLARE @minDate date
	DECLARE @datePartMonth int = (SELECT DATEPART(MONTH, (SELECT TOP 1 EndDate 
															FROM PropertyAccountingPeriod 
															WHERE AccountingPeriodID = @accountingPeriodID
															ORDER BY EndDate)))
														
	DECLARE @datePartYear int = (SELECT DATEPART(YEAR, (SELECT TOP 1 EndDate 
															FROM PropertyAccountingPeriod 
															WHERE AccountingPeriodID = @accountingPeriodID
															ORDER BY EndDate)))
														
	SET @minDate = ISNULL((SELECT TOP 1 StartDate
						FROM PropertyAccountingPeriod
						WHERE DATEPART(YEAR, StartDate) + 1 = @datePartYear
						  AND DATEPART(MONTH, StartDate) = @datePartMonth
						  AND AccountID = @accountID
						ORDER BY StartDate), (SELECT MIN(StartDate) FROM PropertyAccountingPeriod WHERE AccountID = @accountID))

	
		
	INSERT #PropertiesAndPeriods
		SELECT TOP (12 * (SELECT COUNT(*) FROM @propertyIDs)) 
					CASE WHEN ((12 + DATEPART(MONTH, pap.EndDate) - @datePartMonth) > 12) THEN (12 + DATEPART(MONTH, pap.EndDate) - @datePartMonth) - 12
					ELSE (12 + DATEPART(MONTH, pap.EndDate) - @datePartMonth) END,
					pap.PropertyID, pap.AccountingPeriodID, pap.StartDate, pap.EndDate, DATEDIFF(DAY, pap.StartDate, pap.EndDate) + 1, DATEPART(MONTH, pap.EndDate)
			FROM PropertyAccountingPeriod pap
				INNER JOIN @propertyIDs pIDs ON pap.PropertyID = pIDs.Value
			WHERE pap.EndDate <= (SELECT EndDate 
									FROM PropertyAccountingPeriod
									WHERE AccountingPeriodID = @accountingPeriodID
									  AND PropertyID = pap.PropertyID)
			  AND pap.StartDate > @minDate
			ORDER BY pap.EndDate DESC
			
	INSERT #Units 
		SELECT DISTINCT u.UnitID, ut.PropertyID
			FROM Unit u 
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertiesAndPeriods #pads ON ut.PropertyID = #pads.PropertyID
			WHERE u.ExcludedFromOccupancy = 0
			  AND u.IsHoldingUnit = 0
			  AND (u.DateRemoved IS NULL OR u.DateRemoved > #pads.EndDate)
	INSERT #Activity 
		SELECT	#u.UnitID,
				ulg.UnitLeaseGroupID,
				(SELECT MIN(pl.MoveInDate)
					FROM PersonLease pl
					WHERE pl.LeaseID = l.LeaseID
					  AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted')) AS 'MoveInDate',
				(SELECT MAX(pl.MoveOutDate)
					FROM PersonLease pl
						LEFT JOIN PersonLease plmoNULL ON pl.LeaseID = plmoNULL.LeaseID AND plmoNULL.MoveOutDate IS NULL
					WHERE pl.LeaseID = l.LeaseID
					  AND pl.ResidencyStatus IN ('Former', 'Evicted')
					  AND plmoNULL.PersonLeaseID IS NULL
					  AND l.LeaseStatus IN ('Former', 'Evicted'))
			FROM #Units #u
				LEFT JOIN UnitLeaseGroup ulg ON #u.UnitID = ulg.UnitID
				LEFT JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			ORDER BY #u.UnitID, 'MoveInDate'
			
	INSERT #UnitDays
		SELECT	#act.UnitID, 
				#act.UnitLeaseGroupID, 
				#pap.Sequence, 
				-- Figure out the MoveInDate for this Unit, and this UnitLease
				CASE WHEN ((#act.MoveInDate <= #pap.StartDate) AND (#act.MoveOutDate IS NULL OR #act.MoveOutDate >= #pap.StartDate))
					THEN #pap.StartDate
					ELSE CASE WHEN (#act.MoveInDate >= #pap.StartDate AND #act.MoveInDate <= #pap.EndDate)
							THEN #act.MoveInDate 
							ELSE null 
							END 
					END,
				-- Figure out the MoveOutDate for this Unit, and this UnitLease
				CASE WHEN ((#act.MoveOutDate IS NULL OR #act.MoveOutDate >= #pap.EndDate) AND #act.MoveInDate <= #pap.EndDate)
					THEN #pap.EndDate
					ELSE CASE WHEN (#act.MoveOutDate >= #pap.StartDate AND #act.MoveOutDate <= #pap.EndDate)
							THEN #act.MoveOutDate
							ELSE null
							END
					END,
				0, 
				#pap.MonthDatePart,
				DATEDIFF(DAY, #pap.StartDate, #pap.EndDate)+1
			FROM #Activity #act
				INNER JOIN #Units #u ON #act.UnitID = #u.UnitID
				INNER JOIN #PropertiesAndPeriods #pap ON #u.PropertyID = #pap.PropertyID
			ORDER BY #act.UnitID, #act.MoveInDate, #pap.Sequence
			
-- Vacant at the start of the month, moved in part way through the month.  Doesn't worry about move out!				
	UPDATE #ud SET VacantDays = ISNULL(#ud.VacantDays, 0) + DATEDIFF(DAY, #pap.StartDate, #ud.MoveInDate)
		FROM #UnitDays #ud
			INNER JOIN #Units #u ON #ud.UnitID = #u.UnitID
			INNER JOIN #PropertiesAndPeriods #pap ON #u.PropertyID = #pap.PropertyID AND #ud.Sequence = #pap.Sequence
		WHERE #ud.MoveInDate > #pap.StartDate
		  AND #ud.MoveInDate < #pap.EndDate
		  AND #ud.OrderMe = (SELECT TOP 1 OrderMe
								FROM #UnitDays
								WHERE UnitID = #ud.UnitID
								  AND Sequence = #ud.Sequence
								  AND MoveInDate IS NOT NULL
								ORDER BY OrderMe) 
		
-- Account for days when moved out before the end of the month.				
	UPDATE #ud SET VacantDays = ISNULL(#ud.VacantDays, 0) + DATEDIFF(DAY, #ud.MoveOutDate, #pap.EndDate)
		FROM #UnitDays #ud
			INNER JOIN #Units #u ON #ud.UnitID = #u.UnitID
			INNER JOIN #PropertiesAndPeriods #pap ON #u.PropertyID = #pap.PropertyID AND #ud.Sequence = #pap.Sequence
		WHERE #ud.MoveOutDate > #pap.StartDate
		  AND #ud.MoveOutDate < #pap.EndDate
		  AND #ud.OrderMe = (SELECT TOP 1 OrderMe
								FROM #UnitDays
								WHERE UnitID = #ud.UnitID
								  AND Sequence = #ud.Sequence
								  AND MoveOutDate IS NOT NULL
								ORDER BY OrderMe DESC) 

		
-- Vacant periods in the middle of any given month!
	UPDATE #udMO SET VacantDays = ISNULL(#udMO.VacantDays, 0) + (CASE WHEN (DATEDIFF(DAY, #udMI.MoveOutDate, #udMO.MoveInDate) > 0)
																	 THEN DATEDIFF(DAY, #udMI.MoveOutDate, #udMO.MoveInDate) - 1
																	 ELSE 0
																	 END)
		FROM #UnitDays #udMO
			INNER JOIN #UnitDays #udMI ON #udMO.UnitID = #udMI.UnitID AND #udMO.Sequence = #udMI.Sequence AND #udMO.OrderMe > #udMI.OrderMe
			INNER JOIN #Units #u ON #udMO.UnitID = #u.UnitID
			INNER JOIN #PropertiesAndPeriods #pap ON #u.PropertyID = #pap.PropertyID AND #udMO.Sequence = #pap.Sequence
		WHERE #udMO.MoveInDate >= #pap.StartDate
		  AND #udMO.MoveOutDate <= #pap.EndDate
		  AND #udMI.MoveInDate >= #pap.StartDate
		  AND #udMI.MoveOutDate <= #pap.EndDate	
		  AND #udMI.OrderMe = (SELECT TOP 1 OrderMe	
								   FROM #UnitDays 
								   WHERE UnitID = #udMO.UnitID
								     AND Sequence = #udMO.Sequence	
								     AND MoveOutDate IS NOT NULL
								     AND MoveInDate IS NOT NULL
								     AND OrderMe < #udMO.OrderMe
								   ORDER BY OrderMe DESC)					  
								  
	UPDATE #UnitDays SET VacantDays = DaysInMonth
		WHERE MoveInDate IS NULL
		  AND MoveOutDate IS NULL	
		  
	INSERT #ConsolodatedUnitDays 
		SELECT	#u.PropertyID,
				#ud.UnitID, 
				#ud.Sequence,
				CASE WHEN (#ud.DaysInMonth - (ISNULL(SUM(#ud.VacantDays), 0)) < #ud.DaysInMonth)
					THEN ISNULL(SUM(#ud.VacantDays), 0)
					ELSE 0
					END,
				#ud.DaysInMonth
			FROM #UnitDays #ud
				INNER JOIN #Units #u ON #ud.UnitID = #u.UnitID
			WHERE #ud.MoveInDate IS NOT NULL
			  AND #ud.MoveOutDate IS NOT NULL	
			GROUP BY #ud.UnitID, #ud.Sequence, #ud.DaysInMonth, #u.PropertyID
			
	INSERT #ConsolodatedUnitDays 
		SELECT	DISTINCT
				#u.PropertyID,
				#ud.UnitID,
				#ud.Sequence,
				#ud.VacantDays,
				#ud.DaysInMonth
			FROM #UnitDays #ud
				INNER JOIN #Units #u ON #ud.UnitID = #u.UnitID
				LEFT JOIN (SELECT NEWID() AS 'AreYouInHereAlready', #udX.UnitID, #udX.Sequence
								FROM #ConsolodatedUnitDays #udX) AS [AreWeThereYet] ON #ud.UnitID = [AreWeThereYet].UnitID AND #ud.Sequence = [AreWeThereYet].Sequence
			WHERE [AreWeThereYet].AreYouInHereAlready IS NULL


--select * from #Activity
--select * from #UnitDays order by OrderMe
--select * from #ConsolodatedUnitDays order by UnitID, Sequence

	--INSERT #SuperConsolodatedFinalNumbers
	--	SELECT	DISTINCT
	--			#u.PropertyID,
	--			#cud.UnitID,
	--			(SELECT VacantDays FROM #ConsolodatedUnitDays WHERE UnitID = #cud.UnitID AND Sequence = 1) AS 'Month1',
	--			(SELECT VacantDays FROM #ConsolodatedUnitDays WHERE UnitID = #cud.UnitID AND Sequence = 2) AS 'Month2',
	--			(SELECT VacantDays FROM #ConsolodatedUnitDays WHERE UnitID = #cud.UnitID AND Sequence = 3) AS 'Month3',
	--			(SELECT VacantDays FROM #ConsolodatedUnitDays WHERE UnitID = #cud.UnitID AND Sequence = 4) AS 'Month4',
	--			(SELECT VacantDays FROM #ConsolodatedUnitDays WHERE UnitID = #cud.UnitID AND Sequence = 5) AS 'Month5',
	--			(SELECT VacantDays FROM #ConsolodatedUnitDays WHERE UnitID = #cud.UnitID AND Sequence = 6) AS 'Month6',
	--			(SELECT VacantDays FROM #ConsolodatedUnitDays WHERE UnitID = #cud.UnitID AND Sequence = 7) AS 'Month7',
	--			(SELECT VacantDays FROM #ConsolodatedUnitDays WHERE UnitID = #cud.UnitID AND Sequence = 8) AS 'Month8',
	--			(SELECT VacantDays FROM #ConsolodatedUnitDays WHERE UnitID = #cud.UnitID AND Sequence = 9) AS 'Month9',
	--			(SELECT VacantDays FROM #ConsolodatedUnitDays WHERE UnitID = #cud.UnitID AND Sequence = 10) AS 'Month10',
	--			(SELECT VacantDays FROM #ConsolodatedUnitDays WHERE UnitID = #cud.UnitID AND Sequence = 11) AS 'Month11',
	--			(SELECT VacantDays FROM #ConsolodatedUnitDays WHERE UnitID = #cud.UnitID AND Sequence = 12) AS 'Month12'
	--		FROM #ConsolodatedUnitDays #cud
	--			INNER JOIN #Units #u ON #cud.UnitID = #u.UnitID
				
	INSERT #SuperConsolodatedFinalNumbers2
		SELECT	DISTINCT
				#u.PropertyID,
				p.Name AS 'PropertyName',
				ISNULL((SELECT 1.00000 - (SUM(CAST(ISNULL(VacantDays, 0) AS decimal(7, 5))) / SUM(CAST(ISNULL(DaysInMonth, 0) AS decimal(7, 5)))) FROM #ConsolodatedUnitDays WHERE PropertyID = #u.PropertyID AND Sequence = 1 GROUP BY PropertyID), 0.00) AS 'Month1',
				ISNULL((SELECT 1.00000 - (SUM(CAST(ISNULL(VacantDays, 0) AS decimal(7, 5))) / SUM(CAST(ISNULL(DaysInMonth, 0) AS decimal(7, 5)))) FROM #ConsolodatedUnitDays WHERE PropertyID = #u.PropertyID AND Sequence = 2 GROUP BY PropertyID), 0.00) AS 'Month2',
				ISNULL((SELECT 1.00000 - (SUM(CAST(ISNULL(VacantDays, 0) AS decimal(7, 5))) / SUM(CAST(ISNULL(DaysInMonth, 0) AS decimal(7, 5)))) FROM #ConsolodatedUnitDays WHERE PropertyID = #u.PropertyID AND Sequence = 3 GROUP BY PropertyID), 0.00) AS 'Month3',
				ISNULL((SELECT 1.00000 - (SUM(CAST(ISNULL(VacantDays, 0) AS decimal(7, 5))) / SUM(CAST(ISNULL(DaysInMonth, 0) AS decimal(7, 5)))) FROM #ConsolodatedUnitDays WHERE PropertyID = #u.PropertyID AND Sequence = 4 GROUP BY PropertyID), 0.00) AS 'Month4',
				ISNULL((SELECT 1.00000 - (SUM(CAST(ISNULL(VacantDays, 0) AS decimal(7, 5))) / SUM(CAST(ISNULL(DaysInMonth, 0) AS decimal(7, 5)))) FROM #ConsolodatedUnitDays WHERE PropertyID = #u.PropertyID AND Sequence = 5 GROUP BY PropertyID), 0.00) AS 'Month5',
				ISNULL((SELECT 1.00000 - (SUM(CAST(ISNULL(VacantDays, 0) AS decimal(7, 5))) / SUM(CAST(ISNULL(DaysInMonth, 0) AS decimal(7, 5)))) FROM #ConsolodatedUnitDays WHERE PropertyID = #u.PropertyID AND Sequence = 6 GROUP BY PropertyID), 0.00) AS 'Month6',
				ISNULL((SELECT 1.00000 - (SUM(CAST(ISNULL(VacantDays, 0) AS decimal(7, 5))) / SUM(CAST(ISNULL(DaysInMonth, 0) AS decimal(7, 5)))) FROM #ConsolodatedUnitDays WHERE PropertyID = #u.PropertyID AND Sequence = 7 GROUP BY PropertyID), 0.00) AS 'Month7',
				ISNULL((SELECT 1.00000 - (SUM(CAST(ISNULL(VacantDays, 0) AS decimal(7, 5))) / SUM(CAST(ISNULL(DaysInMonth, 0) AS decimal(7, 5)))) FROM #ConsolodatedUnitDays WHERE PropertyID = #u.PropertyID AND Sequence = 8 GROUP BY PropertyID), 0.00) AS 'Month8',
				ISNULL((SELECT 1.00000 - (SUM(CAST(ISNULL(VacantDays, 0) AS decimal(7, 5))) / SUM(CAST(ISNULL(DaysInMonth, 0) AS decimal(7, 5)))) FROM #ConsolodatedUnitDays WHERE PropertyID = #u.PropertyID AND Sequence = 9 GROUP BY PropertyID), 0.00) AS 'Month9',
				ISNULL((SELECT 1.00000 - (SUM(CAST(ISNULL(VacantDays, 0) AS decimal(7, 5))) / SUM(CAST(ISNULL(DaysInMonth, 0) AS decimal(7, 5)))) FROM #ConsolodatedUnitDays WHERE PropertyID = #u.PropertyID AND Sequence = 10 GROUP BY PropertyID), 0.00) AS 'Month10',
				ISNULL((SELECT 1.00000 - (SUM(CAST(ISNULL(VacantDays, 0) AS decimal(7, 5))) / SUM(CAST(ISNULL(DaysInMonth, 0) AS decimal(7, 5)))) FROM #ConsolodatedUnitDays WHERE PropertyID = #u.PropertyID AND Sequence = 11 GROUP BY PropertyID), 0.00) AS 'Month11',
				ISNULL((SELECT 1.00000 - (SUM(CAST(ISNULL(VacantDays, 0) AS decimal(7, 5))) / SUM(CAST(ISNULL(DaysInMonth, 0) AS decimal(7, 5)))) FROM #ConsolodatedUnitDays WHERE PropertyID = #u.PropertyID AND Sequence = 12 GROUP BY PropertyID), 0.00) AS 'Month12'
			FROM #ConsolodatedUnitDays #cud
				INNER JOIN #Units #u ON #cud.UnitID = #u.UnitID
				INNER JOIN Property p ON #u.PropertyID = p.PropertyID
			GROUP BY #u.PropertyID, p.Name
				
	--SELECT *
	--	FROM #SuperConsolodatedFinalNumbers
	--	ORDER BY PropertyID, UnitID
		
	SELECT *
		FROM #SuperConsolodatedFinalNumbers2
		ORDER BY PropertyID
	
END
GO
