SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 11, 2015
-- Updated:		Nov 18, 2015
-- Description:	Main sproc for Lexington Property Summary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_S2_WAR] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
	
AS

DECLARE @previousMonthStartDate date
DECLARE @previousMonthEndDate date
DECLARE @currentMonthStartDate date
DECLARE @objectIDs GuidCollection
--DECLARE @accountingPeriodID uniqueidentifier
DECLARE @myPropertyIDs GuidCollection
--DECLARE @monthStartDate date

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate date null,
		EndDate date null)
	
	
	INSERT #PropertiesAndDates 
		SELECT	pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	
	CREATE TABLE #MyProperties (
		Sequence int identity,
		PropertyID uniqueidentifier not null,
		AccountingPeriodID uniqueidentifier null)
	
	CREATE TABLE #MyFinalNumbers (
		PropertyID uniqueidentifier not null,
		Property nvarchar(50) null,
		Abbreviation nvarchar(8) null,
		Units int null,
		NumberOccupied int null,
		PhysicalOccupancyPercent decimal(7, 2) null,
		TotalVacant int null,
		VacantPreleased int null,
		VacantsMadeReady int null,
		LeasedPercent decimal(7, 2) null,		--WAIT
		ApprovedLeases int null,				--WAIT		
		LeasesCaptured int null,
		CancelledDenied int null,
		Loss2Lease money null,
		SquareFeet int null,
		GPR money null,
		NTV int null,
		NTVPreleased int null,
		TrafficToDate int null,
		MoveIns int null,
		MoveOuts int null)
		
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
		
	CREATE TABLE #VacantUnits (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitStatus nvarchar(30) null)
		
	CREATE TABLE #ObjectsForBalances (
		ObjectID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		Balance money null)
		
	CREATE TABLE #ExpiringLeases (
		LeaseID uniqueidentifier not null,
		NextLeaseID uniqueidentifier null,
		PropertyID uniqueidentifier not null,
		Signed int null)
		
	CREATE TABLE #NewApprovedLeases (
		PropertyID uniqueidentifier not null,
		Unit nvarchar(100) not null,
		LeaseID uniqueidentifier not null,
		ApprovalDate date null)

	--SET @monthStartDate = (SELECT DATEADD(month, DATEDIFF(month, 0, @endDate), 0))
		
	INSERT #MyProperties
		SELECT pIDs.Value, pap.AccountingPeriodID
			FROM @propertyIDs pIDs
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID
				INNER JOIN #PropertiesAndDates #pd ON pIds.Value = #pd.PropertyID
			WHERE pap.StartDate <= #pd.EndDate
			  AND pap.EndDate >= #pd.EndDate

	CREATE TABLE #AllOurAccountingPeriods (
		Seq int identity,
		AccountingPeriodID uniqueidentifier not null)

	IF (@accountingPeriodID IS NULL)
	BEGIN
		INSERT #AllOurAccountingPeriods
			SELECT DISTINCT AccountingPeriodID
				FROM #MyProperties
	END
	ELSE
	BEGIN
		INSERT #AllOurAccountingPeriods VALUES (@accountingPeriodID)
	END

	DECLARE @myCtr int = 1
	DECLARE @myMaxCtr int = (SELECT MAX(Seq) FROM #AllOurAccountingPeriods)

	WHILE (@myCtr <= @myMaxCtr)
	BEGIN
		SET @accountingPeriodID = (SELECT AccountingPeriodID FROM #AllOurAccountingPeriods WHERE Seq = @myCtr)
		INSERT @myPropertyIDs 
			SELECT PropertyID 
				FROM #MyProperties
				WHERE AccountingPeriodID = @accountingPeriodID
		INSERT #LeasesAndUnits
			EXEC GetConsolodatedOccupancyNumbers @accountID, @endDate, @accountingPeriodID, @myPropertyIDs
		DELETE @myPropertyIDs
		SET @myCtr = @myCtr + 1
	END

	INSERT #MyFinalNumbers
		SELECT Value, Property.Name, Property.Abbreviation, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null		-- 16 nulls here! AND now eight more!
			FROM @propertyIDs pids
				INNER JOIN Property ON pids.Value = Property.PropertyID
				
	--SET @currentMonthStartDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @endDate), 0)
	--SET @previousMonthStartDate = DATEADD(month, DATEDIFF(month, 0, @endDate)-1, 0)
	--SET @previousMonthEndDate = DATEADD(DAY, -1, @currentMonthStartDate)

	-- GOOD
	UPDATE #MyFinalNumbers SET Units = (SELECT COUNT(UnitID) 
											FROM #LeasesAndUnits
											WHERE PropertyID = #MyFinalNumbers.PropertyID
											GROUP BY PropertyID)
	-- GOOD										
	UPDATE #MyFinalNumbers SET NumberOccupied = (SELECT COUNT(UnitID)
													FROM #LeasesAndUnits
													WHERE OccupiedUnitLeaseGroupID IS NOT NULL
													  AND PropertyID = #MyFinalNumbers.PropertyID
													GROUP BY PropertyID)
	-- GOOD													
	UPDATE #MyFinalNumbers SET TotalVacant = (SELECT COUNT(UnitID)
												  FROM #LeasesAndUnits
												  WHERE OccupiedUnitLeaseGroupID IS NULL
												    AND PropertyID = #MyFinalNumbers.PropertyID
												  GROUP BY PropertyID)
	
	-- GOOD
	UPDATE #MyFinalNumbers SET VacantPreleased = ISNULL((SELECT COUNT(UnitID)
															FROM #LeasesAndUnits
															WHERE PendingUnitLeaseGroupID IS NOT NULL
																AND OccupiedUnitLeaseGroupID IS NULL
																AND PropertyID = #MyFinalNumbers.PropertyID
															GROUP BY PropertyID), 0)

	-- GOOD
	UPDATE #MyFinalNumbers SET NTVPreleased = ISNULL((SELECT COUNT(UnitID)
															FROM #LeasesAndUnits
															WHERE PendingUnitLeaseGroupID IS NOT NULL
																AND OccupiedUnitLeaseGroupID IS NOT NULL
																AND OccupiedMoveOutDate IS NOT NULL
																AND PropertyID = #MyFinalNumbers.PropertyID
															GROUP BY PropertyID), 0)

	-- GOOD												  
	UPDATE #MyFinalNumbers SET NTV = ISNULL((SELECT COUNT(UnitID)
										  FROM #LeasesAndUnits
										  WHERE 
											OccupiedUnitLeaseGroupID IS NOT NULL
											AND OccupiedNTVDate IS NOT NULL
										    AND PropertyID = #MyFinalNumbers.PropertyID
										  GROUP BY PropertyID), 0)
	
	-- GOOD
	-- Not Returned, but does it need to be?											  
	UPDATE #MyFinalNumbers SET PhysicalOccupancyPercent = 100.0 * (CAST(NumberOccupied AS DECIMAL(7, 2)) / CAST(Units AS DECIMAL(7, 2)))
		WHERE #MyFinalNumbers.Units <> 0
											
	INSERT #VacantUnits 
		SELECT #lau.PropertyID, UnitID, [UStat].[Status]
			FROM #LeasesAndUnits #lau
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #lau.PropertyID
				CROSS APPLY GetUnitStatusByUnitID(#lau.UnitID, #pad.EndDate) [UStat]
			WHERE #lau.OccupiedUnitLeaseGroupID IS NULL
			
	UPDATE #MyFinalNumbers SET VacantsMadeReady = ISNULL((SELECT COUNT(UnitID) 
															FROM #VacantUnits #va
															WHERE UnitStatus = 'Ready'
															  AND PropertyID = #MyFinalNumbers.PropertyID
															GROUP BY PropertyID), 0)
	CREATE TABLE #ApplicationsThisMonth (
		PropertyID uniqueidentifier not null,
		LeaseID uniqueidentifier not null,
		UnitNumber nvarchar(100))

	INSERT #ApplicationsThisMonth 
		SELECT DISTINCT ut.PropertyID, l.LeaseID, u.Number
			FROM Lease l 
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID 
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID 
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = ut.PropertyID
				LEFT JOIN PersonLease lAppLastMonth ON l.LeaseID = lAppLastMonth.LeaseID AND lAppLastMonth.ApplicationDate < #pad.StartDate			
			WHERE lAppLastMonth.PersonLeaseID IS NULL 
			  AND l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)
			  AND pl.ApplicationDate >= #pad.StartDate AND pl.ApplicationDate <= #pad.EndDate
				--AND ulg.PreviousUnitLeaseGroupID IS NULL
				
	-- GOOD
	UPDATE #MyFinalNumbers SET LeasesCaptured = (SELECT COUNT(DISTINCT LeaseID)
													FROM #ApplicationsThisMonth 
													WHERE PropertyID = #MyFinalNumbers.PropertyID)

	-- GOOD
	UPDATE #MyFinalNumbers SET CancelledDenied = (SELECT COUNT(DISTINCT l.LeaseID)
													FROM Lease l
															INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
															INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
															INNER JOIN Unit u ON ulg.UnitID = u.UnitID
															INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID	
															INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID														
														WHERE pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID	
																	FROM PersonLease 
																	WHERE LeaseID = l.LeaseID
																	ORDER BY MoveOutDate DESC, OrderBy, PersonLeaseID)
															AND l.LeaseStatus IN ('Cancelled', 'Denied')
															AND ut.PropertyID = #MyFinalNumbers.PropertyID
															AND pl.MoveOutDate >= #pad.StartDate
															AND pl.MoveOutDate <= #pad.EndDate
															AND l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate))

	-- GOOD
	UPDATE #MyFinalNumbers SET TrafficToDate = (SELECT COUNT(DISTINCT p.ProspectID)
										  FROM PersonNote pn				
											INNER JOIN Prospect p ON pn.PersonID = p.PersonID																		
											INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = p.PropertyProspectSourceID
											INNER JOIN #PropertiesAndDates #pad ON pps.PropertyID = #pad.PropertyID																					
										  WHERE pn.PersonType = 'Prospect'	

										    AND pn.[Date] >= #pad.StartDate
											AND pn.[Date] <= #pad.EndDate
											AND pn.PropertyID = #MyFinalNumbers.PropertyID
											-- Get the first Prospect note
											AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
																	 FROM PersonNote pn2 																	   
																	 WHERE pn2.PersonID = pn.PersonID
																	       AND pn2.PropertyID = #MyFinalNumbers.PropertyID
																		   AND pn2.PersonType = 'Prospect'
																		   -- Get actual interactions or transfer notes
																		   AND pn2.ContactType <> 'N/A' -- ADD pn2.InteractionType = 'Transfer' to include transfers-- Do not include notes that were not contacts
																	 ORDER BY [Date], [DateCreated])											
											AND pps.PropertyID = #MyFinalNumbers.PropertyID)





	CREATE TABLE #NewAndImprovedUnits (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitFeets int null)

	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		UnitStatus nvarchar(200) not null,
		UnitStatusLedgerItemTypeID uniqueidentifier not null,
		RentLedgerItemTypeID uniqueidentifier not null,
		MarketRent decimal null,
		Amenities nvarchar(MAX) null)

	DECLARE @propertyID uniqueidentifier, @ctr int = 1, @maxCtr int, @ctrEndDate date, @unitIDs GuidCollection
	
	SET @maxCtr = (SELECT MAX(Sequence) FROM #MyProperties)
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @propertyID = PropertyID FROM #MyProperties WHERE Sequence = @ctr
		SET @ctrEndDate = (SELECT EndDate FROM #PropertiesAndDates WHERE PropertyID = @propertyID)
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @ctrEndDate, 0
		SET @ctr = @ctr + 1
	END		

	INSERT #NewAndImprovedUnits
		SELECT ut.PropertyID, #ua.UnitID, ut.SquareFootage
			FROM #UnitAmenities #ua
				INNER JOIN UnitType ut ON #ua.UnitTypeID = ut.UnitTypeID

	UPDATE #MyFinalNumbers SET SquareFeet = (SELECT SUM(UnitFeets)
												FROM #NewAndImprovedUnits 
												WHERE #MyFinalNumbers.PropertyID = #NewAndImprovedUnits.PropertyID
												GROUP BY PropertyID)

	UPDATE #MyFinalNumbers SET GPR = (SELECT SUM(#ua.MarketRent)
										  FROM #UnitAmenities #ua
											  INNER JOIN Unit u ON #ua.UnitID = u.UnitID
											  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
										  WHERE #MyFinalNumbers.PropertyID = ut.PropertyID
										  GROUP BY ut.PropertyID)

	CREATE TABLE #LossToLease (
		PropertyID uniqueidentifier,		
		UnitID uniqueidentifier,
		UnitLeaseGroupID uniqueidentifier,		
		ActualRent money
	)

	INSERT INTO #LossToLease
		SELECT PropertyID, UnitID, OccupiedUnitLeaseGroupID, 0
		FROM #LeasesAndUnits #lau
		WHERE #lau.OccupiedUnitLeaseGroupID IS NOT NULL

	UPDATE #LossToLease SET ActualRent = (SELECT SUM(lli.Amount)
										  FROM UnitLeaseGroup ulg
										    INNER JOIN #PropertiesAndDates #pad ON #LossToLease.PropertyID = #pad.PropertyID
											INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')
											INNER JOIN LeaseLedgerItem lli ON lli.LeaseID = l.LeaseID
											INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
											INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID AND lit.IsRent = 1
										  WHERE ulg.UnitLeaseGroupID = #LossToLease.UnitLeaseGroupID
											AND lli.StartDate <= #pad.EndDate

											AND lli.EndDate >= #pad.EndDate)																				 

	UPDATE #MyFinalNumbers SET Loss2Lease = (SELECT SUM(#ua.MarketRent - #l2l.ActualRent)
												FROM #LossToLease #l2l
													INNER JOIN #UnitAmenities #ua ON #ua.UnitID = #l2l.UnitID
												WHERE	
												  #l2l.PropertyID = #MyFinalNumbers.PropertyID)

	UPDATE #MyFinalNumbers SET MoveIns = (SELECT COUNT(DISTINCT l.LeaseID)					
										FROM Lease l
											INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
											INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
											INNER JOIN Building b ON u.BuildingID = b.BuildingID																						
											INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID																																	
											INNER JOIN #PropertiesAndDates #pad ON b.PropertyID = #pad.PropertyID																					
										WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
																  FROM PersonLease pl2
																  WHERE pl2.LeaseID = l.LeaseID
																	AND pl2.ResidencyStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
																  ORDER BY pl2.MoveInDate, pl2.OrderBy, pl2.PersonID)		
										  AND pl.MoveInDate >= #pad.StartDate
										  AND pl.MoveInDate <= #pad.EndDate
										  AND b.PropertyID = #MyFinalNumbers.PropertyID
										  AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
										  AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
										  AND l.LeaseID = (SELECT TOP 1 LeaseID 
														   FROM Lease
														   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																 AND LeaseStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted')
														   ORDER BY LeaseStartDate, DateCreated))



	UPDATE #MyFinalNumbers SET MoveOuts = (SELECT COUNT(DISTINCT l.LeaseID)
											FROM Lease l
												INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
												INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
												INNER JOIN Building b ON u.BuildingID = b.BuildingID
												INNER JOIN #PropertiesAndDates #pad ON b.PropertyID = #pad.PropertyID												
												INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID										
											WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
																	  FROM PersonLease pl2
																	  WHERE pl2.LeaseID = l.LeaseID
																		AND pl2.ResidencyStatus IN ('Former', 'Evicted')
																	  ORDER BY pl2.MoveOutDate DESC, pl2.OrderBy, pl2.PersonID)		
											  AND pl.MoveOutDate >= #pad.StartDate
												AND pl.MoveOutDate <= #pad.EndDate
												AND b.PropertyID = #MyFinalNumbers.PropertyID
											  AND pl.ResidencyStatus IN ('Former', 'Evicted')
											  AND l.LeaseStatus IN ('Former', 'Evicted'))




	SELECT 
		PropertyID,
		Property AS 'PropertyName',
		Abbreviation AS 'PropertyAbbreviation',
		ISNULL(Units, 0) AS 'TotalUnits',
		ISNULL(NumberOccupied, 0) AS 'OccupiedUnits',
		ISNULL(TotalVacant, 0) AS 'VacantUnits',
		ISNULL(VacantPreleased, 0) AS 'VacantPreleased',
		ISNULL(ApprovedLeases, 0) AS 'ApprovedLeases',		
		ISNULL(NTV, 0) AS 'NoticeToVacate',
		ISNULL(NTVPreleased, 0) AS 'NTVPreleased',
		ISNULL(VacantsMadeReady, 0) AS 'VacantReady',
		ISNULL(SquareFeet, 0) AS 'SquareFootage',
		ISNULL(GPR, 0.00) AS 'GrossPotentialRent',
		ISNULL(LeasesCaptured, 0) AS 'LeasesCaptured',
		ISNULL(CancelledDenied, 0) AS 'CancelledDenied',
		ISNULL(Loss2Lease, 0.00) AS 'Loss2Lease',
		ISNULL(TrafficToDate, 0) AS 'TrafficToDate',
		ISNULL(MoveIns, 0) AS 'MoveIns',
		ISNULL(MoveOuts, 0) AS 'MoveOuts'
		FROM #MyFinalNumbers
	
END
GO
