SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Aug. 25, 2016
-- Description:	Wasatch Daily Roll Up Sproc
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_WSTCH_DailyRollUp] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null,
	@startDate date null,
	@endDate date null
AS

DECLARE @accountID bigint
DECLARE @thisDate date
DECLARE @minDate date
DECLARE @maxDate date
DECLARE @i int = 1
DECLARE @iMax int
DECLARE @propertyID uniqueidentifier = null
DECLARE @AREndDate date = null
DECLARE @ARPrevEndDate date = null

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #WasatchDailySummary (
		PropertyID uniqueidentifier not null,
		Today date null,
		PhoneTraffic int null,
		EmailTraffic int null,
		PhysicalTraffic int null,
		ApplicationsReceived int null,
		ApplicationsApproved int null,
		ApplicationsCancelled int null,
		ApplicationsDenied int null,
		Renewals int null,
		LeaseExpirations int null,
		TotalUnits int null,
		OccupiedUnits int null,
		MoveIns int null,
		MoveOuts int null,
		OnNoticeRented int null,
		OnNoticeUnrented int null,
		VacantRented int null,
		VacantUnrented int null,
		CurrentMonthRentAR money null,
		LastMonthRentAR money null)

	CREATE TABLE #AgedReceivablesByPonytail (	
		ReportDate date NOT NULL,
		PropertyName nvarchar(100) NOT NULL,	
		PropertyID uniqueidentifier NOT NULL,
		Unit nvarchar(50) NULL,
		PaddedUnit nvarchar(50) NULL,
		ObjectID uniqueidentifier NOT NULL,
		ObjectType nvarchar(25) NOT NULL,	
		LeaseID uniqueidentifier  NULL,
		Names nvarchar(250) NULL,	
		TransactionID uniqueidentifier NULL,
		PaymentID uniqueidentifier NULL,
		TransactionType nvarchar(50) NOT NULL,		
		TransactionDate datetime NOT NULL,
		LedgerItemType nvarchar(50) NULL,
		Total money NULL,		
		PrepaymentsCredits money NULL,
		Reason nvarchar(500) NULL)

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
		PendingMoveInDate date null)

	CREATE TABLE #PropertiesAndDates (
		[Sequence] int identity,
		PropertyID uniqueidentifier null,
		StartDate date null,
		EndDate date null)

	INSERT #PropertiesAndDates
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	SET @minDate = (SELECT MIN(StartDate) FROM #PropertiesAndDates)
	SET @maxDate = (SELECT MAX(EndDate) FROM #PropertiesAndDates)
	SET @thisDate = @minDate
	SET @accountID = (SELECT AccountID FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)

	WHILE (@thisDate <= @maxDate)
	BEGIN
		INSERT #WasatchDailySummary
			SELECT	PropertyID, @thisDate, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				FROM #PropertiesAndDates 
				WHERE @thisDate >= StartDate
				  AND @thisDate <= EndDate

		TRUNCATE TABLE #LeasesAndUnits

		IF (@accountingPeriodID IS NULL)
		BEGIN
			SET @accountingPeriodID = (SELECT TOP 1 AccountingPeriodID 
										   FROM AccountingPeriod
										   WHERE StartDate <= @maxDate
										     AND EndDate <= @maxDate)
		END

		INSERT #LeasesAndUnits
			EXEC GetConsolodatedOccupancyNumbers @accountID, @thisDate, @accountingPeriodID, @propertyIDs

		UPDATE #WasatchDailySummary SET OnNoticeRented = (SELECT COUNT(DISTINCT #lau.UnitID)
																FROM #LeasesAndUnits #lau
																WHERE #lau.OccupiedNTVDate <= @thisDate
																AND #lau.OccupiedMoveOutDate > @thisDate
																AND #lau.PendingLeaseID IS NOT NULL
																AND #lau.PropertyID = #WasatchDailySummary.PropertyID
																AND @thisDate = #WasatchDailySummary.Today)

		UPDATE #WasatchDailySummary SET OnNoticeUnrented = (SELECT COUNT(DISTINCT #lau.UnitID)
																FROM #LeasesAndUnits #lau
																WHERE #lau.OccupiedNTVDate IS NOT NULL
																	AND #lau.OccupiedMoveOutDate > @thisDate
																    AND #lau.PendingLeaseID IS NULL
																	AND #lau.PropertyID = #WasatchDailySummary.PropertyID
																	AND @thisDate = #WasatchDailySummary.Today)

		UPDATE #WasatchDailySummary SET VacantRented = (SELECT COUNT(DISTINCT #lau.UnitID)
															FROM #LeasesAndUnits #lau
															WHERE #lau.OccupiedUnitLeaseGroupID IS NULL
																AND #lau.PendingLeaseID IS NOT NULL
																AND #lau.PropertyID = #WasatchDailySummary.PropertyID
																AND @thisDate = #WasatchDailySummary.Today)

		UPDATE #WasatchDailySummary SET VacantUnrented = (SELECT COUNT(DISTINCT #lau.UnitID)
																FROM #LeasesAndUnits #lau
																WHERE #lau.OccupiedUnitLeaseGroupID IS NULL
																AND #lau.PendingLeaseID IS NULL
																AND #lau.PropertyID = #WasatchDailySummary.PropertyID
																AND @thisDate = #WasatchDailySummary.Today)

		UPDATE #WasatchDailySummary SET OccupiedUnits = (SELECT COUNT(DISTINCT #lau.UnitID)
															 FROM #LeasesAndUnits #lau
															 WHERE #lau.OccupiedUnitLeaseGroupID IS NOT NULL
															   AND (#lau.OccupiedMoveOutDate IS NULL OR #lau.OccupiedMoveOutDate > @thisDate)
															   AND #WasatchDailySummary.PropertyID = #lau.PropertyID
															   AND #WasatchDailySummary.Today = @thisDate)

		SET @thisDate = DATEADD(DAY, 1, @thisDate)
	END

	SET @thisDate = DATEADD(DAY, -1, @thisDate)

	UPDATE #WasatchDailySummary SET PhoneTraffic = (SELECT COUNT(DISTINCT pros.ProspectID)
														FROM Prospect pros
															INNER JOIN PersonNote pn ON pros.FirstPersonNoteID = pn.PersonNoteID
															INNER JOIN #PropertiesAndDates #pad ON pn.PropertyID = #pad.PropertyID AND pn.[Date] = #WasatchDailySummary.Today
														WHERE #pad.PropertyID = #WasatchDailySummary.PropertyID
														  AND pn.ContactType = 'Phone')

	UPDATE #WasatchDailySummary SET EmailTraffic = (SELECT COUNT(DISTINCT pros.ProspectID)
														FROM Prospect pros
															INNER JOIN PersonNote pn ON pros.FirstPersonNoteID = pn.PersonNoteID
															INNER JOIN #PropertiesAndDates #pad ON pn.PropertyID = #pad.PropertyID AND pn.[Date] = #WasatchDailySummary.Today
														WHERE #pad.PropertyID = #WasatchDailySummary.PropertyID
														  AND pn.ContactType = 'Email')

	UPDATE #WasatchDailySummary SET PhysicalTraffic = (SELECT COUNT(DISTINCT pros.ProspectID)
															FROM Prospect pros
																INNER JOIN PersonNote pn ON pros.FirstPersonNoteID = pn.PersonNoteID
																INNER JOIN #PropertiesAndDates #pad ON pn.PropertyID = #pad.PropertyID AND pn.[Date] = #WasatchDailySummary.Today
															WHERE #pad.PropertyID = #WasatchDailySummary.PropertyID
															  AND pn.ContactType = 'Face-to-Face')

	UPDATE #WasatchDailySummary SET ApplicationsReceived = (SELECT COUNT(DISTINCT l.LeaseID)
															   FROM Lease l
																   INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																   INNER JOIN Unit u ON ulg.UnitID = u.UnitID
																   INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
																   INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
																   INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ApplicationDate = #WasatchDailySummary.Today
																   LEFT JOIN Lease prevL ON ulg.UnitLeaseGroupID = prevL.UnitLeaseGroupID AND prevL.LeaseCreated < l.LeaseCreated
															   WHERE ulg.PreviousUnitLeaseGroupID IS NULL
																 AND prevL.LeaseID IS NULL
																 AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																							 FROM PersonLease
																							 WHERE LeaseID = l.LeaseID
																							 ORDER BY ApplicationDate)
																 AND #pad.PropertyID = #WasatchDailySummary.PropertyID)


	UPDATE #WasatchDailySummary SET ApplicationsApproved = (SELECT COUNT(DISTINCT ulg.UnitLeaseGroupID)
											  FROM UnitLeaseGroup ulg
												  INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
												  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ApprovalStatus = 'Approved'
												  INNER JOIN PersonNote pn ON pl.PersonID = pn.PersonID
												  INNER JOIN #PropertiesAndDates #pad ON pn.PropertyID = #pad.PropertyID
																					AND pn.[Date] >= #WasatchDailySummary.Today
																					AND pn.InteractionType = 'Approved'
																					AND pn.DateCreated > l.DateCreated
												  LEFT JOIN (SELECT	pl1.LeaseID, pn1.PersonNoteID, pn1.[Date], pn1.DateCreated
																 FROM PersonLease pl1
																	 INNER JOIN PersonNote pn1 ON pl1.PersonID = pn1.PersonID
																 WHERE pn1.InteractionType = 'Approved') [pnPrior] ON pnPrior.LeaseID = l.LeaseID
																															AND pnPrior.[Date] < #WasatchDailySummary.Today
																															AND pnPrior.DateCreated > l.DateCreated
												WHERE #pad.PropertyID = #WasatchDailySummary.PropertyID
												  AND pnPrior.PersonNoteID IS NULL
												  AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
																   FROM Lease l2
																   WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																   ORDER BY l2.LeaseStartDate))

	UPDATE #WasatchDailySummary SET ApplicationsCancelled = (SELECT COUNT(DISTINCT l.LeaseID)
										  FROM Lease l
											  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
											  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
											  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
											  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
											  INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
											  LEFT JOIN PersonLease plMONull ON l.LeaseID = plMONull.LeaseID AND plMONull.MoveOutDate > #WasatchDailySummary.Today
										  WHERE (pl.MoveOutDate = #WasatchDailySummary.Today)
											AND l.LeaseStatus IN ('Cancelled')											
											AND plMONull.PersonLeaseID IS NULL
										    AND #pad.PropertyID = #WasatchDailySummary.PropertyID
											AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
																   FROM Lease l2
																   WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																   ORDER BY l2.LeaseStartDate))

	UPDATE #WasatchDailySummary SET ApplicationsDenied = (SELECT COUNT(DISTINCT l.LeaseID)
										  FROM Lease l
											  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
											  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
											  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
											  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
											  INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
											  LEFT JOIN PersonLease plMONull ON l.LeaseID = plMONull.LeaseID AND plMONull.MoveOutDate > #WasatchDailySummary.Today
										  WHERE pl.MoveOutDate = #WasatchDailySummary.Today
											AND l.LeaseStatus IN ('Denied')											
											AND plMONull.PersonLeaseID IS NULL
										    AND #pad.PropertyID = #WasatchDailySummary.PropertyID
											AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
																   FROM Lease l2
																   WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																   ORDER BY l2.LeaseStartDate))	

	UPDATE #WasatchDailySummary SET MoveIns = (SELECT COUNT(DISTINCT ulg.UnitLeaseGroupID)
											  FROM UnitLeaseGroup ulg
												  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
												  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
												  INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
												  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
												  INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
																					AND pl.MoveInDate = #WasatchDailySummary.Today
												  LEFT JOIN (SELECT	pl1.LeaseID, pl1.PersonLeaseID, pl1.MoveInDate
																 FROM PersonLease pl1) [plPrior] ON plPrior.LeaseID = l.LeaseID
																					AND plPrior.MoveInDate < #WasatchDailySummary.Today 
												  LEFT JOIN Lease lPrior ON ulg.UnitLeaseGroupID = lPrior.UnitLeaseGroupID
																					AND lPrior.LeaseStartDate < l.LeaseStartDate
												WHERE #pad.PropertyID = #WasatchDailySummary.PropertyID
												  AND plPrior.PersonLeaseID IS NULL
												  AND lPrior.LeaseID IS NULL
												  AND l.LeaseStatus NOT IN ('Pending Approval', 'Pending Transfer', 'Pending Renewal', 'Cancelled', 'Denied'))

	UPDATE #WasatchDailySummary SET MoveOuts = (SELECT COUNT(DISTINCT ulg.UnitLeaseGroupID)
											  FROM UnitLeaseGroup ulg
												  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
												  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
												  INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
												  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
												  INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
																					AND pl.MoveOutDate = #WasatchDailySummary.Today
												  LEFT JOIN (SELECT	pl1.LeaseID, pl1.PersonLeaseID, pl1.MoveOutDate
																 FROM PersonLease pl1) [plAfter] ON [plAfter].LeaseID = l.LeaseID
																					AND [plAfter].MoveOutDate > #WasatchDailySummary.Today
												  LEFT JOIN PersonLease plNull ON l.LeaseID = plNull.LeaseID AND plNull.MoveOutDate IS NULL 
												  --LEFT JOIN Lease lPrior ON ulg.UnitLeaseGroupID = lPrior.UnitLeaseGroupID
														--							AND lPrior.LeaseStartDate < l.LeaseStartDate
												WHERE #pad.PropertyID = #WasatchDailySummary.PropertyID
												  AND [plAfter].PersonLeaseID IS NULL
												  AND plNull.LeaseID IS NULL
												  AND l.LeaseStatus IN ('Evicted', 'Former'))
																   
	UPDATE #WasatchDailySummary SET TotalUnits = (SELECT COUNT(DISTINCT u.UnitID)
													  FROM Unit u
														  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
														  INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
													  WHERE u.IsHoldingUnit = 0
													    AND u.ExcludedFromOccupancy = 0
														--AND (u.DateRemoved IS NULL OR u.DateRemoved > #pad.EndDate)
														)

	UPDATE #WasatchDailySummary SET LeaseExpirations = (SELECT COUNT(DISTINCT l.LeaseID)
															FROM Lease l
																INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																INNER JOIN Unit u ON ulg.UnitID = u.UnitID
																INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
																INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
															WHERE l.LeaseEndDate >= #pad.StartDate 
															  AND l.LeaseEndDate <= #pad.EndDate
															  AND #pad.PropertyID = #WasatchDailySummary.PropertyID)

	UPDATE #WasatchDailySummary SET Renewals = (SELECT COUNT(DISTINCT l.LeaseID)
													FROM Lease l
														INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
														INNER JOIN Unit u ON ulg.UnitID = u.UnitID
														INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
														INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
														INNER JOIN Lease prevl ON ulg.UnitLeaseGroupID = prevl.UnitLeaseGroupID AND prevl.LeaseStartDate < l.LeaseStartDate
														INNER JOIN PersonLease plMin ON l.LeaseID = plMin.LeaseID 
														LEFT JOIN PersonLease plNull ON l.LeaseID = plNull.LeaseID AND plNull.LeaseSignedDate < plMin.LeaseSignedDate
													WHERE plNull.PersonLeaseID IS NULL
													  AND plMin.LeaseSignedDate = #WasatchDailySummary.Today
													  AND #pad.PropertyID = #WasatchDailySummary.PropertyID)

	IF (@accountingPeriodID IS NOT NULL)
	BEGIN
		SET @AREndDate = (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
		SET @ARPrevEndDate = (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = (SELECT TOP 1 AccountingPeriodID
																								   FROM AccountingPeriod
																								   WHERE EndDate < @AREndDate
																								   ORDER BY EndDate DESC))
	END
	ELSE
	BEGIN
		SET @AREndDate = @endDate
		SET @ARPrevEndDate = DATEADD(MONTH, -1, @endDate)
		IF ((DATEPART(DAY, DATEADD(DAY, 1, @endDate))) = 1)				-- @endDate is the last day of the month.  DateMath will not work as we want!
		BEGIN
			WHILE ((DATEPART(DAY, DATEADD(DAY, 1, @ARPrevEndDate))) > 1)
			BEGIN
				SET @ARPrevEndDate = DATEADD(DAY, 1, @ARPrevEndDate)
			END
		END
	END

	INSERT #AgedReceivablesByPonytail
		EXEC RPT_TNS_AgedReceivables @AREndDate, @propertyIDs

	UPDATE #WasatchDailySummary SET CurrentMonthRentAR = ISNULL((SELECT SUM(Total)
																     FROM #AgedReceivablesByPonytail
																     WHERE PropertyID = #WasatchDailySummary.PropertyID), 0)

	TRUNCATE TABLE #AgedReceivablesByPonytail

	INSERT #AgedReceivablesByPonytail
		EXEC RPT_TNS_AgedReceivables @ARPrevEndDate, @propertyIDs

	UPDATE #WasatchDailySummary SET LastMonthRentAR = ISNULL((SELECT SUM(Total)
																  FROM #AgedReceivablesByPonytail
																  WHERE PropertyID = #WasatchDailySummary.PropertyID), 0)


	SELECT *
		FROM #WasatchDailySummary
		ORDER BY Today, PropertyID


END
GO
