SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_CST_ICO_MaintenanceReadyStatistics] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS

DECLARE @accountID bigint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here

	CREATE TABLE #UnitStats (
		UnitID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		UnitNumber nvarchar(50) null,
		MoveOutDate date null,
		ExpectedMakeReadyDate date null,
		ActualMakeReadyDate date null,
		NumberDaysVacant int null,
		MakeReadyDays int null,
		CompletedBy nvarchar(100) null,
		ExpectedMoveInDate date null
		)

	CREATE TABLE #PropertyStats (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(500) null,
		TotalUnits int null,
		TotalOccupiedUnits int null,
		VacantAvailable int null,
		VacantReady int null,
		AverageMakeReadyDays int null,
		MakeReadyThreshold1 int null,
		MakeReadyThreshold2 int null,
		AverageDaysVacant int null
		)

	CREATE TABLE #LeasesAndUnits (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(50) null,
		OccupiedUnitLeaseGroupID uniqueidentifier null,
		OccupiedLastLeaseID uniqueidentifier null,
		OccupiedMoveInDate date null,
		OccupiedNTVDate date null,
		OccupiedMoveOutDate date null,
		OccupiedIsMovedOut bit null,
		PendingUnitLeaseGroupID uniqueidentifier null,
		PendingLeaseID uniqueidentifier null,
		PendingApplicationDate date null,
		PendingMoveInDate date null
		)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null
		)

	INSERT #PropertiesAndDates
		SELECT Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @endDate, @accountingPeriodID, @propertyIDs	


	INSERT #UnitStats
		SELECT	DISTINCT
				u.UnitID,
				p.PropertyID,
				u.Number,
				pl.MoveOutDate,
				null AS 'ExpectedMakeReadyDate',
				null AS 'ActualMakeReadyDate',
				null AS 'NumberDaysVacant',
				null AS 'MakeReadyDays',
				null AS 'CompletedBy',
				null AS 'ExpectedMoveInDate'
			FROM UnitLeaseGroup ulg
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				LEFT JOIN UnitLeaseGroup nulg ON nulg.PreviousUnitLeaseGroupID = ulg.UnitLeaseGroupID				
				LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.MoveOutDate IS NULL
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN Person pr ON pr.PersonID = pl.PersonID
				INNER JOIN #PropertiesAndDates pIDs ON p.PropertyID = pIDs.PropertyID				
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE l.LeaseStatus IN ('Former', 'Evicted')
			  -- Ensure there are not residents on the lease
			  -- without a move out date			
			  AND plmo.PersonLeaseID IS NULL
			  AND (((@accountingPeriodID IS NULL)
				  AND ((SELECT MAX(MoveOutDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) >= @startDate)
				  AND ((SELECT MAX(MoveOutDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) <= @endDate)
				  AND (pl.MoveOutDate >= @startDate)
				  AND (pl.MoveOutDate <= @endDate))
				OR ((@accountingPeriodID IS NOT NULL)
				  AND ((SELECT MAX(MoveOutDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) >= pap.StartDate)
				  AND ((SELECT MAX(MoveOutDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) <= pap.EndDate)
				  AND (pl.MoveOutDate >= pap.StartDate)
				  AND (pl.MoveOutDate <= pap.EndDate)))
			   AND (nulg.UnitLeaseGroupID IS NULL OR 
					-- Or the transferred lease was cancelled
					((SELECT Count(*) FROM Lease WHERE UnitLeaseGroupID = nulg.UnitLeaseGroupID AND LeaseStatus in ('Cancelled', 'Denied')) > 0)
					-- AND there is not a non-cancelled lease that was transferred
					-- (Scenario: Transfers to a new unit and that lease cancels and transfers again
					--			  to a different unit.  In this scenario the above case will have a count
					--			  greater than zero but it will not take into account the second transfer.					
					AND (SELECT COUNT(*) 
						 FROM UnitLeaseGroup 
						 INNER JOIN Lease ON Lease.UnitLeaseGroupID = UnitLeaseGroup.UnitLeaseGroupID
					     WHERE PreviousUnitLeaseGroupID = ulg.UnitLeaseGroupID					     
							AND LeaseStatus NOT IN ('Cancelled', 'Denied')) = 0)
			  -- Get the last lease associated with the 
			  -- UnitLeaseGroup		
			  AND l.LeaseID = (SELECT TOP 1 LeaseID 
							   FROM Lease
							   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
									 AND LeaseStatus IN ('Former', 'Evicted')
							   ORDER BY LeaseEndDate DESC)	

	CREATE TABLE #UnitsWeMadeReady (
		UnitID uniqueidentifier not null,
		MoveOutDate date null,
		UnitNoteID uniqueidentifier null,
		[Date] date null,
		DoneByID uniqueidentifier null
		)

	INSERT #UnitsWeMadeReady
		SELECT #uStats.UnitID, #uStats.MoveOutDate, un.UnitNoteID, un.[Date], un.PersonID
			FROM #UnitStats #uStats
				INNER JOIN UnitNote un ON #uStats.UnitID = un.UnitID
			WHERE un.UnitNoteID = (SELECT TOP 1 UnitNoteID
									   FROM UnitNote
									   WHERE UnitStatusID = (SELECT UnitStatusID FROM UnitStatus WHERE Name = 'Ready' AND AccountID = @accountID)
									     AND [Date] > #uStats.MoveOutDate
										 AND UnitID = #uStats.UnitID)

	UPDATE #us SET ActualMakeReadyDate = un.[Date], CompletedBy = per.PreferredName + ' ' + per.LastName
		FROM #UnitStats #us
			INNER JOIN #UnitsWeMadeReady #unwmd ON #us.UnitID = #unwmd.UnitID AND #us.MoveOutDate = #unwmd.MoveOutDate
			INNER JOIN UnitNote un ON #unwmd.UnitNoteID = un.UnitNoteID
			INNER JOIN Person per ON un.PersonID = per.PersonID
		WHERE #unwmd.UnitNoteID IS NOT NULL

	UPDATE #UnitStats SET ExpectedMakeReadyDate = (SELECT DATEADD(DAY, (SELECT MAX(DaysToComplete) FROM AutoMakeReady WHERE PropertyID = #UnitStats.PropertyID), #UnitStats.MoveOutDate)
													   FROM #UnitStats #us1
													   WHERE #us1.UnitID = #UnitStats.UnitID
													     AND #us1.MoveOutDate = #UnitStats.MoveOutDate)

	UPDATE #UnitStats SET ExpectedMoveInDate = (SELECT TOP 1 pl.MoveInDate
													FROM PersonLease pl
														INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
														INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
													WHERE ulg.UnitID = #UnitStats.UnitID
													  AND pl.MoveInDate >= #UnitStats.ExpectedMakeReadyDate
													ORDER BY pl.MoveInDate)

	UPDATE #UnitStats SET NumberDaysVacant = DATEDIFF(DAY, MoveOutDate, ExpectedMoveInDate)

	UPDATE #UnitStats SET MakeReadyDays = DATEDIFF(DAY, MoveOutDate, ActualMakeReadyDate)

	-- Property Stats Updating Section
	INSERT #PropertyStats 
		SELECT	DISTINCT
				#pad.PropertyID,
				p.Name,
				null,
				null,
				null,
				null,
				null,
				null,
				null,
				null
			FROM #PropertiesAndDates #pad
				INNER JOIN Property p ON #pad.PropertyID = p.PropertyID

	UPDATE #PropertyStats SET TotalUnits = (SELECT COUNT(DISTINCT u.UnitID)
												FROM Unit u
													INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
													INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
												WHERE u.ExcludedFromOccupancy = 0
												  AND u.IsHoldingUnit = 0
												  AND (u.DateRemoved IS NULL OR u.DateRemoved > #pad.EndDate)
												  AND #pad.PropertyID = #PropertyStats.PropertyID)

	UPDATE #PropertyStats SET TotalOccupiedUnits = (SELECT COUNT(DISTINCT #lau.UnitID)
														FROM #LeasesAndUnits #lau
														WHERE OccupiedLastLeaseID IS NOT NULL
														  AND #lau.PropertyID = #PropertyStats.PropertyID)

	UPDATE #PropertyStats SET VacantAvailable = (SELECT COUNT(DISTINCT #lau.UnitID)
													  FROM #LeasesAndUnits #lau
														  INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
													  WHERE #lau.OccupiedLastLeaseID IS NULL
													    AND #lau.PropertyID = #PropertyStats.PropertyID)

	UPDATE #PropertyStats SET VacantReady = (SELECT COUNT(DISTINCT #lau.UnitID)
												 FROM #LeasesAndUnits #lau
													 INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
													 CROSS APPLY dbo.GetUnitStatusByUnitID(#lau.UnitID, #pad.EndDate) [UStat]
												 WHERE #lau.OccupiedLastLeaseID IS NULL
												   AND [UStat].[Status] IN ('Ready')
												   AND #lau.PropertyID = #PropertyStats.PropertyID)

	UPDATE #PropertyStats SET AverageMakeReadyDays = ((CAST((SELECT SUM(MakeReadyDays)
															    FROM #UnitStats
															    WHERE MakeReadyDays IS NOT NULL
															      AND PropertyID = #PropertyStats.PropertyID) AS FLOAT)) /
													  (CAST((SELECT COUNT(DISTINCT UnitID)
																FROM #UnitStats
																WHERE MakeReadyDays IS NOT NULL
																  AND PropertyID = #PropertyStats.PropertyID) AS FLOAT)))

	UPDATE #PropertyStats SET MakeReadyThreshold1 = (SELECT COUNT(DISTINCT #us.UnitID)
													     FROM #UnitStats #us
															  INNER JOIN Settings settins ON settins.AccountID = @accountID
													     WHERE MakeReadyDays <= settins.WorkOrderMaintenanceStatsThreshold1
													       AND PropertyID = #PropertyStats.PropertyID)
													   
	UPDATE #PropertyStats SET MakeReadyThreshold2 = (SELECT COUNT(DISTINCT UnitID)
													     FROM #UnitStats #us
															  INNER JOIN Settings settins ON settins.AccountID = @accountID
													     WHERE MakeReadyDays > settins.WorkOrderMaintenanceStatsThreshold2
													       AND PropertyID = #PropertyStats.PropertyID)
													   
	UPDATE #PropertyStats SET AverageDaysVacant = ((CAST((SELECT SUM(NumberDaysVacant)
															    FROM #UnitStats
															    WHERE NumberDaysVacant IS NOT NULL
															      AND PropertyID = #PropertyStats.PropertyID) AS FLOAT)) /
													  (CAST((SELECT COUNT(DISTINCT UnitID)
																FROM #UnitStats
																WHERE NumberDaysVacant IS NOT NULL
																  AND PropertyID = #PropertyStats.PropertyID) AS FLOAT)))

	SELECT * 
		FROM #UnitStats
		ORDER BY UnitID, MoveOutDate

	SELECT *
		FROM #PropertyStats

		
END
GO
