SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[RPT_PRTY_CumulativePropertyStatus] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS

DECLARE @i int = 1
DECLARE @iMax int
DECLARE @lilPropertyIDs GuidCollection
DECLARE @lilEndDate date
DECLARE @priorLilEndDate date
DECLARE @accountID bigint

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	CREATE TABLE #AllPropertyInfoEver (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		TotalUnits int null,
		PriorTotalOccupancy int null,					-- not yet
		TotalMoveIns int null,
		TotalMoveOuts int null,
		Traffic int null,								-- not yet
		NewLeases int null,
		CanceledDenied int null,
		NetNewLeases int null,
		CurrentTotalOccupancy int null,
		VacantNotLeased int null,
		VacantLeased int null,
		NTVNotPreleased int null,
		NTVPreleased int null,
		ModelAdminDown int null,
		ExpiredLeases int null,
		RenewedLeases int null,
		TotalSquareFeet int null,
		CurrentMonthBilledRent money null,
		CurrentMonthBilledCharges money null,
		CurrentMonthRentConcessions money null,
		CurrentMonthConcessions money null,
		CurrentMonthCollectedRent money null,
		CurrentMonthDelinquent money null)

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

	CREATE TABLE #LeasesAndUnitsPrior (
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

	CREATE TABLE #UnitsInfo (
		UnitID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		SquareFeet int null,
		UStatus nvarchar(50) null)

	CREATE TABLE #PropertiesAndDates (
		[Sequence] int identity,
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #ObjectsAndBalances (
		ObjectID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		Balance money null)

	INSERT #PropertiesAndDates
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	SET @iMax = (SELECT MAX([Sequence]) FROM #PropertiesAndDates)
	SET @accountID = (SELECT TOP 1 AccountID 
						  FROM Property prop
							  INNER JOIN #PropertiesAndDates #pad ON prop.PropertyID = #pad.PropertyID)

	WHILE (@i <= @iMax)
	BEGIN
		DELETE @lilPropertyIDs
		INSERT @lilPropertyIDs
			SELECT PropertyID FROM #PropertiesAndDates WHERE [Sequence] = @i
		SET @lilEndDate = (SELECT EndDate FROM #PropertiesAndDates WHERE [Sequence] = @i)
		SET @priorLilEndDate = (SELECT StartDate FROM #PropertiesAndDates WHERE [Sequence] = @i)
		SET @priorLilEndDate = DATEADD(DAY, -1, @priorLilEndDate)

		INSERT #LeasesAndUnits
			EXEC GetConsolodatedOccupancyNumbers @accountID, @lilEndDate, null, @lilPropertyIDs	

		INSERT #LeasesAndUnitsPrior
			EXEC GetConsolodatedOccupancyNumbers @accountID, @priorLilEndDate, null, @lilPropertyIDs	

		SET @i = @i + 1
	END

	INSERT #AllPropertyInfoEver
		SELECT #pad.PropertyID, prop.Name, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null -- 23 nulls for now
			FROM #PropertiesAndDates #pad
				INNER JOIN Property prop ON #pad.PropertyID = prop.PropertyID

	INSERT #UnitsInfo
		SELECT  #lau.UnitID, ut.PropertyID, CASE WHEN (u.SquareFootage > 0) THEN u.SquareFootage ELSE ut.SquareFootage END, ISNULL([UStatus].[Status], 'Ready')
			FROM #LeasesAndUnits #lau
				INNER JOIN Unit u ON #lau.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
				OUTER APPLY GetUnitStatusByUnitID(u.UnitID, #pad.EndDate) [UStatus]

	UPDATE #AllPropertyInfoEver SET PriorTotalOccupancy = (SELECT COUNT(DISTINCT #lau.UnitID)
															   FROM #LeasesAndUnitsPrior #lau
															   WHERE OccupiedUnitLeaseGroupID IS NOT NULL
															     AND #lau.PropertyID = #AllPropertyInfoEver.PropertyID)

	UPDATE #AllPropertyInfoEver SET CurrentTotalOccupancy = (SELECT COUNT(DISTINCT #lau.UnitID)
															     FROM #LeasesAndUnits #lau
															     WHERE OccupiedUnitLeaseGroupID IS NOT NULL
															       AND #lau.PropertyID = #AllPropertyInfoEver.PropertyID)

	UPDATE #AllPropertyInfoEver SET TotalUnits = (SELECT COUNT(DISTINCT #lau.UnitID)
													  FROM #LeasesAndUnits #lau
													  WHERE #AllPropertyInfoEver.PropertyID = #lau.PropertyID)

	--UPDATE #AllPropertyInfoEver SET TotalMoveIns = (SELECT COUNT(DISTINCT #lau.UnitID)
	--													FROM #LeasesAndUnits #lau
	--														INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
	--													WHERE #lau.OccupiedMoveInDate >= #pad.StartDate
	--													  AND #lau.OccupiedMoveInDate <= #pad.EndDate
	--													  AND #AllPropertyInfoEver.PropertyID = #lau.PropertyID)

	--UPDATE #AllPropertyInfoEver SET TotalMoveOuts = (SELECT COUNT(DISTINCT #lau.UnitID)
	--													FROM #LeasesAndUnits #lau
	--														INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
	--													WHERE #lau.OccupiedMoveOutDate >= #pad.StartDate
	--													  AND #lau.OccupiedMoveOutDate <= #pad.EndDate
	--													  AND #AllPropertyInfoEver.PropertyID = #lau.PropertyID)

	CREATE TABLE #ResidentActivity (
			[Type] nvarchar(100),
			PropertyID uniqueidentifier,
			UnitTypeID uniqueidentifier,
			UnitType nvarchar(100),
			UnitID uniqueidentifier,
			Unit nvarchar(50),
			PaddedUnitNumber nvarchar(50),
			UnitLeaseGroupID uniqueidentifier,
			LeaseID uniqueidentifier
		)


	INSERT INTO #ResidentActivity
			SELECT DISTINCT 
					'MoveOut',
					p.PropertyID,	
					ut.UnitTypeID,
					ut.Name,
					u.UnitID,
					u.Number,
					u.PaddedNumber,
					l.UnitLeaseGroupID,
					l.LeaseID			
				FROM Lease l
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN Property p ON p.PropertyID = b.PropertyID
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID		
					INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID						
					INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
				WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
										  FROM PersonLease pl2
										  WHERE pl2.LeaseID = l.LeaseID
											AND pl2.ResidencyStatus IN ('Former', 'Evicted')
										  ORDER BY pl2.MoveOutDate DESC, pl2.OrderBy, pl2.PersonID)		
				  AND pl.MoveOutDate >= #pad.StartDate
				  AND pl.MoveOutDate <= #pad.EndDate
				  AND pl.ResidencyStatus IN ('Former', 'Evicted')
				  AND l.LeaseStatus IN ('Former', 'Evicted')
			
	

		INSERT INTO #ResidentActivity
			SELECT DISTINCT 	
					'MoveIn' AS 'Type',					
					p.PropertyID,	
					ut.UnitTypeID,
					ut.Name,
					u.UnitID,
					u.Number,
					u.PaddedNumber,			
					l.UnitLeaseGroupID,
					l.LeaseID									
				FROM Lease l
					INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					INNER JOIN Property p ON p.PropertyID = b.PropertyID
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID		
					INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID																		
					INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID					
				WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
										  FROM PersonLease pl2
										  WHERE pl2.LeaseID = l.LeaseID
											AND pl2.ResidencyStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
										  ORDER BY pl2.MoveInDate, pl2.OrderBy, pl2.PersonID)		
				  AND pl.MoveInDate >= #pad.StartDate
				  AND pl.MoveInDate <= #pad.EndDate
				  AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
				  AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
				  AND l.LeaseID = (SELECT TOP 1 LeaseID 
								   FROM Lease
								   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
										 AND LeaseStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted')
								   ORDER BY LeaseStartDate, DateCreated)

	UPDATE #AllPropertyInfoEver SET TotalMoveIns = (SELECT COUNT(*) 
									 FROM #ResidentActivity #ra
									 WHERE #ra.PropertyiD = #AllPropertyInfoEver.PropertyID
										AND #ra.[Type] = 'MoveIn')

	UPDATE #AllPropertyInfoEver SET TotalMoveOuts = (SELECT COUNT(*) 
									 FROM #ResidentActivity #ra
									 WHERE #ra.PropertyiD = #AllPropertyInfoEver.PropertyID
										AND #ra.[Type] = 'MoveOut')


	--UPDATE #AllPropertyInfoEver SET NewLeases = (SELECT COUNT(DISTINCT l.LeaseID)
	--												 FROM Lease l
	--													 INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--													 INNER JOIN #LeasesAndUnits #lau ON ulg.UnitID = #lau.UnitID
	--													 INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
	--												  WHERE l.LeaseStartDate >= #pad.StartDate
	--												    AND l.LeaseStartDate <= #pad.EndDate
	--													AND #AllPropertyInfoEver.PropertyID = #pad.PropertyID)

	CREATE TABLE #Applicants (
			[Type] nvarchar(100),
			PropertyID uniqueidentifier,
			UnitTypeID uniqueidentifier,
			UnitType nvarchar(100),
			UnitID uniqueidentifier,
			Unit nvarchar(50),
			PaddedUnitNumber nvarchar(50),
			UnitLeaseGroupID uniqueidentifier,
			LeaseID uniqueidentifier,
			IsRenewal bit					
		)

		-- NewApplication
		INSERT INTO #Applicants
			SELECT 
				'NewApplication' AS 'Type',
				p.PropertyID,
				ut.UnitTypeID,
				ut.Name,
				u.UnitID,
				u.Number,
				u.PaddedNumber,
				l.UnitLeaseGroupID,
				l.LeaseID,
				0
			FROM Lease l
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID		
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID				
			WHERE pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID	
													FROM PersonLease 
													WHERE LeaseID = l.LeaseID
													ORDER BY ApplicationDate, OrderBy, PersonLeaseID)
				AND pl.ApplicationDate >= #pad.StartDate
				AND pl.ApplicationDate <= #pad.EndDate


		---- Approved Application
		--INSERT INTO #Applicants
		--	SELECT 
		--		'ApprovedApplication' AS 'Type',
		--		p.PropertyID,
		--		ut.UnitTypeID,
		--		ut.Name,
		--		u.UnitID,
		--		u.Number,
		--		u.PaddedNumber,
		--		l.UnitLeaseGroupID,
		--		l.LeaseID,
		--		0
		--	FROM Lease l
		--		INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
		--		INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
		--		INNER JOIN Unit u ON ulg.UnitID = u.UnitID
		--		INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
		--		INNER JOIN Property p ON ut.PropertyID = p.PropertyID		
		--		INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID				
		--		INNER JOIN PersonNote pn ON pl.PersonID = pn.PersonID AND pn.PropertyID = #pad.PropertyID AND pn.InteractionType = 'Approved' 
		--	WHERE pl.PersonLeaseID = (SELECT TOP 1 pl1.PersonLeaseID	
		--										FROM PersonLease pl1
		--											INNER JOIN PersonNote pn1 on pl1.PersonID = pn1.personID
		--										WHERE pl1.LeaseID = l.LeaseID
		--											AND pn1.PropertyID = p.PropertyID
		--											AND pl1.ApprovalStatus = 'Approved'
		--											AND pn1.InteractionType = 'Approved'
		--										ORDER BY pn1.[Date] ASC, pl1.ApplicationDate, pl1.OrderBy, pl1.PersonLeaseID)
		--		AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID
		--							   FROM PersonNote pn2
		--							   WHERE pn2.PersonID = pl.PersonID
		--								AND pn2.InteractionType = 'Approved'
		--								AND pn2.PropertyID = #pad.PropertyID
		--								AND pn2.DateCreated > l.DateCreated -- Approval is after the lease is created. This accounts for transferred leases. Don't want to show a transferred lease as approved 2 years before
		--							   ORDER BY pn2.[Date] ASC)
		--		AND pn.[Date] >= #pad.StartDate
		--		AND pn.[Date] <= #pad.EndDate				
		--		AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
		--						 FROM Lease l2 
		--						 WHERE l2.UnitLeaseGroupID = l.UnitLeaseGroupID
		--						 ORDER by l2.DateCreated)

		-- Cancelled and Denied Applications
		INSERT INTO #Applicants
			SELECT 
				'CancelledDeniedApplication' AS 'Type',
				p.PropertyID,
				ut.UnitTypeID,
				ut.Name,
				u.UnitID,
				u.Number,
				u.PaddedNumber,
				l.UnitLeaseGroupID,
				l.LeaseID,				
				0 AS 'IsRenewal'				
			FROM Lease l
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID		
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID				
			WHERE pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID	
						FROM PersonLease 
						WHERE LeaseID = l.LeaseID
						ORDER BY MoveOutDate DESC, OrderBy, PersonLeaseID)
				AND l.LeaseStatus IN ('Cancelled', 'Denied')
				AND pl.MoveOutDate >= #pad.StartDate
				AND pl.MoveOutDate <= #pad.EndDate

	INSERT INTO #Applicants
			SELECT 
				'SignedApplication' AS 'Type',
				p.PropertyID,
				ut.UnitTypeID,
				ut.Name,
				u.UnitID,
				u.Number,
				u.PaddedNumber,
				l.UnitLeaseGroupID,
				l.LeaseID,				
				0 AS 'Renewal'		
			FROM Lease l
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID		
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID				
			WHERE pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID	
										FROM PersonLease 
										WHERE LeaseID = l.LeaseID
											AND LeaseSignedDate IS NOT NULL
										ORDER BY LeaseSignedDate, OrderBy, PersonLeaseID)
				AND l.LeaseStatus NOT IN ('Cancelled', 'Denied')
				AND pl.LeaseSignedDate >= #pad.StartDate
				AND pl.LeaseSignedDate <= #pad.EndDate

	UPDATE #Applicants SET IsRenewal = 1 WHERE LeaseID <> (SELECT TOP 1 LeaseID 
															   FROM Lease 
															   WHERE UnitLeaseGroupID = #Applicants.UnitLeaseGroupID
															   ORDER BY LeaseStartDate, DateCreated)

	UPDATE #Applicants SET [Type] = REPLACE([Type], 'Application', 'Renewal') WHERE IsRenewal = 1

	--select * from #Applicants

	UPDATE #AllPropertyInfoEver SET NewLeases = (SELECT COUNT(*) 
												FROM #Applicants #a
												WHERE #a.PropertyID = #AllPropertyInfoEver.PropertyID
												AND #a.[Type] = 'NewApplication')


	UPDATE #AllPropertyInfoEver SET CanceledDenied = (SELECT COUNT(*) 
												FROM #Applicants #a
												WHERE #a.PropertyID = #AllPropertyInfoEver.PropertyID
												AND #a.[Type] = 'CancelledDeniedApplication'
												AND #a.IsRenewal = 0)

	UPDATE #AllPropertyInfoEver SET RenewedLeases = (SELECT COUNT(*) 
												FROM #Applicants #a
												WHERE #a.PropertyID = #AllPropertyInfoEver.PropertyID
												AND #a.[Type] = 'SignedRenewal'
												AND #a.IsRenewal = 1)

												

	
	--UPDATE #AllPropertyInfoEver SET CanceledDenied = (SELECT COUNT(DISTINCT l.LeaseID)
	--													 FROM Lease l
	--														 INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--														 INNER JOIN #LeasesAndUnits #lau ON ulg.UnitID = #lau.UnitID
	--														 INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
	--													  WHERE l.LeaseStartDate >= #pad.StartDate
	--														AND l.LeaseStartDate <= #pad.EndDate
	--														AND l.LeaseStatus IN ('Cancelled', 'Denied')
	--														AND #AllPropertyInfoEver.PropertyID = #pad.PropertyID)

	UPDATE #AllPropertyInfoEver SET VacantNotLeased = (SELECT COUNT(DISTINCT #lau.UnitID)
															FROM #LeasesAndUnits #lau
															WHERE OccupiedUnitLeaseGroupID IS NULL
															  AND PendingUnitLeaseGroupID IS NULL
															  AND #lau.PropertyID = #AllPropertyInfoEver.PropertyID)

	UPDATE #AllPropertyInfoEver SET VacantLeased = (SELECT COUNT(DISTINCT #lau.UnitID)
														FROM #LeasesAndUnits #lau
														WHERE OccupiedUnitLeaseGroupID IS NULL
														  AND PendingUnitLeaseGroupID IS NOT NULL
														  AND #lau.PropertyID = #AllPropertyInfoEver.PropertyID)

	UPDATE #AllPropertyInfoEver SET NTVNotPreleased = (SELECT COUNT(DISTINCT #lau.UnitID)
														   FROM #LeasesAndUnits #lau
															   INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
														   WHERE #lau.OccupiedUnitLeaseGroupID IS NOT NULL 
																AND #lau.OccupiedMoveOutDate IS NOT NULL
																AND #lau.PendingUnitLeaseGroupID IS NULL
																AND #lau.OccupiedNTVDate <= #pad.EndDate
																AND #lau.PropertyID = #AllPropertyInfoEver.PropertyID)

	UPDATE #AllPropertyInfoEver SET NTVPreleased = (SELECT COUNT(DISTINCT #lau.UnitID)
														FROM #LeasesAndUnits #lau
															INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
														WHERE #lau.OccupiedUnitLeaseGroupID IS NOT NULL 
															AND #lau.OccupiedMoveOutDate IS NOT NULL
															AND #lau.PendingUnitLeaseGroupID IS NOT NULL
															AND #lau.OccupiedNTVDate <= #pad.EndDate
															AND #lau.PropertyID = #AllPropertyInfoEver.PropertyID)

	UPDATE #AllPropertyInfoEver SET ModelAdminDown = (SELECT COUNT(DISTINCT #lau.UnitID)
														  FROM #LeasesAndUnits #lau
															  INNER JOIN #UnitsInfo #ui ON #lau.UnitID = #ui.UnitID
														  WHERE #ui.UStatus IN ('Model', 'Down', 'Admin')
														    AND #lau.PropertyID = #AllPropertyInfoEver.PropertyID)

	UPDATE #AllPropertyInfoEver SET TotalSquareFeet = (SELECT SUM(#ui.SquareFeet)
														   FROM #LeasesAndUnits #lau
															   INNER JOIN #UnitsInfo #ui ON #lau.UnitID = #ui.UnitID
														   WHERE #ui.PropertyID = #AllPropertyInfoEver.PropertyID)

	UPDATE #AllPropertyInfoEver SET ExpiredLeases = (SELECT COUNT(DISTINCT l.LeaseID)
														 FROM Lease l
															 INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
															 INNER JOIN #LeasesAndUnits #lau ON ulg.UnitID = #lau.UnitID
															 INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
														 WHERE l.LeaseEndDate >= #pad.StartDate
														   AND l.LeaseEndDate <= #pad.EndDate
														   AND l.LeaseStatus NOT IN ('Canceled', 'Denied')
														   AND #pad.PropertyID = #AllPropertyInfoEver.PropertyID)

	--UPDATE #AllPropertyInfoEver SET RenewedLeases = (SELECT COUNT(DISTINCT newL.LeaseID)
	--													 FROM Lease newL
	--														 INNER JOIN UnitLeaseGroup ulg ON newL.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--														 INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStartDate < newL.LeaseStartDate
	--														 INNER JOIN #LeasesAndUnits #lau ON ulg.UnitID = #lau.UnitID
	--														 INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
	--													 WHERE newL.LeaseStartDate >= #pad.StartDate
	--													   AND newL.LeaseEndDate <= #pad.EndDate
	--													   AND newL.LeaseStatus IN ('Current', 'Pending Renewal')
	--													   AND #pad.PropertyID = #AllPropertyInfoEver.PropertyID)

	--UPDATE #AllPropertyInfoEver SET CurrentMonthBilledRent = (SELECT SUM(lli.Amount)
	--															  FROM LeaseLedgerItem lli
	--																  INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
	--																  INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
	--																  INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
	--																  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--																  INNER JOIN #LeasesAndUnits #lau ON ulg.UnitID = #lau.UnitID
	--																  INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
	--															  WHERE lli.StartDate <= #pad.EndDate
	--															    AND lli.EndDate >= #pad.EndDate
	--																AND #AllPropertyInfoEver.PropertyID = #pad.PropertyID)

	--UPDATE #AllPropertyInfoEver SET CurrentMonthRentConcessions = (SELECT SUM(lli.Amount)
	--																  FROM LeaseLedgerItem lli
	--																	  INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
	--																	  INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
	--																	  INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRecurringMonthlyRentConcession = 1
	--																	  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--																	  INNER JOIN #LeasesAndUnits #lau ON ulg.UnitID = #lau.UnitID
	--																	  INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
	--																  WHERE lli.StartDate <= #pad.EndDate
	--																	AND lli.EndDate >= #pad.EndDate
	--																	AND #AllPropertyInfoEver.PropertyID = #pad.PropertyID)
	
	UPDATE #AllPropertyInfoEver SET CurrentMonthBilledRent = ISNULL((SELECT SUM(t.Amount)
													FROM [Transaction] t
														INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
																				AND tt.[Group] IN ('Lease', 'Prospect', 'Non-Resident Account', 'WOIT Account')
																				AND tt.Name = 'Charge'
														INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID and lit.IsRent = 1																					
														 INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID																																	
													WHERE t.PropertyID = #AllPropertyInfoEver.PropertyID
													  AND t.TransactionDate >= #pad.StartDate
													  AND t.TransactionDate <= #pad.EndDate), 0)

	UPDATE #AllPropertyInfoEver SET CurrentMonthBilledCharges = ISNULL((SELECT SUM(t.Amount)
												FROM [Transaction] t
													INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
																			AND tt.[Group] IN ('Lease', 'Prospect', 'Non-Resident Account', 'WOIT Account')
																			AND tt.Name = 'Charge'																																
														INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID																																	
												WHERE t.PropertyID = #AllPropertyInfoEver.PropertyID
													AND t.TransactionDate >= #pad.StartDate
													AND t.TransactionDate <= #pad.EndDate), 0)

	UPDATE #AllPropertyInfoEver SET CurrentMonthRentConcessions = ISNULL((SELECT SUM(Amount)
																			FROM (SELECT DISTINCT p.PaymentID, p.Amount
																					FROM Payment p
																						INNER JOIN [PaymentTransaction] pt ON pt.PaymentID = p.PaymentID
																						INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
																						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
																												AND tt.[Group] IN ('Lease', 'Prospect', 'Non-Resident Account', 'WOIT Account')
																												AND tt.Name = 'Credit'
																						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID AND lit.IsRecurringMonthlyRentConcession = 1
																						INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
																					WHERE t.PropertyID = #AllPropertyInfoEver.PropertyID
																					  AND p.[Date] >= #pad.StartDate
																					  AND p.[Date] <= #pad.EndDate) AS Credits), 0)

	UPDATE #AllPropertyInfoEver SET CurrentMonthConcessions = ISNULL((SELECT SUM(Amount)
																			FROM (SELECT DISTINCT p.PaymentID, p.Amount
																					FROM Payment p
																						INNER JOIN [PaymentTransaction] pt ON pt.PaymentID = p.PaymentID
																						INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
																						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
																												AND tt.[Group] IN ('Lease', 'Prospect', 'Non-Resident Account', 'WOIT Account')
																												AND tt.Name = 'Credit'																						
																						INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
																					WHERE t.PropertyID = #AllPropertyInfoEver.PropertyID
																					  AND p.[Date] >= #pad.StartDate
																					  AND p.[Date] <= #pad.EndDate) AS Credits), 0)


	CREATE TABLE #MyTempPayments (
		PropertyID uniqueidentifier not null,
		PaymentID uniqueidentifier not null,
		Amount money null,
		[Date] date null)

	INSERT #MyTempPayments 
		SELECT DISTINCT t.PropertyID, t.TransactionID, t.Amount, t.TransactionDate--pay.PaymentID, pay.Amount, pay.[Date]
			FROM Payment pay
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Payment') AND tt.[Group] IN ('Lease', 'Prospect', 'Non-Resident Account', 'WOIT Account')
				INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsPayment = 1
				INNER JOIN [Transaction] at ON at.TransactionID = t.AppliesToTransactionID
				INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = at.LedgerItemTypeID AND alit.IsRent = 1
				INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
				LEFT JOIN [Transaction] rt ON rt.ReversesTransactionID = t.TransactionID
			WHERE at.[TransactionDate] >= #pad.StartDate 
				AND at.[TransactionDate] <= #pad.EndDate				
				AND rt.TransactionID IS NULL

	UPDATE #AllPropertyInfoEver SET CurrentMonthCollectedRent = ISNULL((SELECT SUM(#mtp.Amount)
																		FROM #MyTempPayments #mtp														
																		WHERE #mtp.PropertyID = #AllPropertyInfoEver.PropertyID), 0)
	
	--UPDATE #AllPropertyInfoEver SET CurrentMonthCollectedRent = (SELECT SUM(ta.Amount)
	--																 FROM [Transaction] t
	--																	 INNER JOIN [Transaction] ta ON t.TransactionID = ta.AppliesToTransactionID
	--																	 INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
	--																	 INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
	--																	 LEFT JOIN [Transaction] tar ON ta.TransactionID = tar.ReversesTransactionID
	--																 WHERE t.TransactionDate >= #pad.StartDate
	--																   AND t.TransactionDate <= #pad.EndDate
	--																   AND tar.TransactionID IS NULL
	--																   AND #AllPropertyInfoEver.PropertyID = #pad.PropertyID)

	CREATE TABLE #ObjectsForBalances (
		ObjectID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		Date date not null,
		Balance money null)

	INSERT #ObjectsForBalances	
			SELECT DISTINCT ObjectID, #pad.PropertyID, #pad.EndDate, null
				FROM [Transaction] t
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = t.PropertyID
				INNER JOIN TransactionType tt ON tt.TransactionTypeID = t.TransactionTypeID
				WHERE TransactionDate <= #pad.EndDate
					AND t.AccountID = @accountID
					AND tt.[Group] IN ('Prospect', 'Non-Resident Account', 'WOIT Account', 'Lease')

	UPDATE #ObjectsForBalances SET Balance = (SELECT [BAL].Balance
												  FROM #ObjectsForBalances #ofb
												      CROSS APPLY GetObjectBalance2(null, #ofb.Date, #ofb.ObjectID, 0, #ofb.PropertyID) [BAL]
												  WHERE #ofb.ObjectID = #ObjectsForBalances.ObjectID
													AND #ofb.PropertyID = #ObjectsForBalances.PropertyID)

	DELETE FROM #ObjectsForBalances WHERE Balance <= 0
	
	--INSERT #ObjectsAndBalances
	--	SELECT DISTINCT(t.ObjectID), t.PropertyID, [MonthBalance].Balance
	--		FROM [Transaction] t
	--			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] IN ('Lease')		-- Instructions say, current month deliquent rent.
	--			INNER JOIN #PropertiesAndDates #pad ON t.PropertyID = #pad.PropertyID
	--			CROSS APPLY GetObjectBalance(#pad.StartDate, #pad.EndDate, t.ObjectID, 0, @propertyIDs) [MonthBalance]
	--		WHERE t.TransactionDate >= DATEADD(MONTH, -2, #pad.StartDate)
	

	UPDATE #AllPropertyInfoEver SET CurrentMonthDelinquent = (
																SELECT SUM(ISNULL(Balance, 0))
																FROM #ObjectsForBalances #ofb
																WHERE #ofb.PropertyID = #AllPropertyInfoEver.PropertyID
															 )
	
	UPDATE #AllPropertyInfoEver SET Traffic = (SELECT COUNT(DISTINCT prst.ProspectID)
												FROM Prospect prst
													INNER JOIN PropertyProspectSource pps ON prst.PropertyProspectSourceID = pps.PropertyProspectSourceID
													INNER JOIN #PropertiesAndDates #pad ON pps.PropertyID = #pad.PropertyID
												WHERE pps.PropertyID = #AllPropertyInfoEver.PropertyID
													AND (#pad.StartDate <= (SELECT TOP 1 pn1.[Date] 
																			FROM PersonNote pn1											  
																			WHERE pn1.PersonID = prst.PersonID
																			  AND pn1.PropertyID = pps.PropertyID
																			  AND PersonType = 'Prospect'
																			  AND ContactType <> 'N/A' -- Do not include notes that were not contacts
																			ORDER BY [Date] ASC, [DateCreated] ASC))
												  AND (#pad.EndDate >= (SELECT TOP 1 pn1.[Date] 
																			FROM PersonNote pn1											  
																			WHERE pn1.PersonID = prst.PersonID
																			  AND pn1.PropertyID = pps.PropertyID
																			  AND PersonType = 'Prospect'
																			  AND ContactType <> 'N/A' -- Do not include notes that were not contacts
																			ORDER BY [Date] ASC, [DateCreated] ASC)))

	--Non Null Return Values
	UPDATE #AllPropertyInfoEver SET CurrentMonthCollectedRent = ISNULL(CurrentMonthCollectedRent, 0)
	UPDATE #AllPropertyInfoEver SET CurrentMonthDelinquent = ISNULL(CurrentMonthDelinquent, 0)
	UPDATE #AllPropertyInfoEver SET CurrentMonthBilledRent = ISNULL(CurrentMonthBilledRent, 0)
	UPDATE #AllPropertyInfoEver SET CurrentMonthConcessions = ISNULL(CurrentMonthConcessions, 0)
	UPDATE #AllPropertyInfoEver SET CurrentMonthBilledCharges = ISNULL(CurrentMonthBilledCharges, 0)
	UPDATE #AllPropertyInfoEver SET CurrentMonthRentConcessions = ISNULL(CurrentMonthRentConcessions, 0)
	UPDATE #AllPropertyInfoEver SET NewLeases = ISNULL(NewLeases, 0)
	UPDATE #AllPropertyInfoEver SET CanceledDenied = ISNULL(CanceledDenied, 0)
	UPDATE #AllPropertyInfoEver SET NetNewLeases = ISNULL(NewLeases, 0) - ISNULL(CanceledDenied, 0)
	UPDATE #AllPropertyInfoEver SET Traffic = ISNULL(Traffic, 0)
	UPDATE #AllPropertyInfoEver SET TotalSquareFeet = ISNULL(TotalSquareFeet, 0)


	SELECT * 
		FROM #AllPropertyInfoEver
		ORDER BY PropertyName
END
GO
