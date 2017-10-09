SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 16, 2016
-- Description:	Gets the data for the PLP Asset Management Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_PLP_AssetManagement] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier,
	@startDate date = null,
	@endDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
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
			
	CREATE TABLE #OccupiedUnitCount (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		UnitTypeID uniqueidentifier not null,
		UnitTypeName nvarchar(50) null,
		UnitCount int not null,
		AverageSquareFootage int null,
		OccupiedUnitCount int null,
		RentReadyUnits int null,
		MTMLeases int null,
		LeasesExpiring30 int null,
		LeasesExpiring90 int null)

	CREATE TABLE #UnitTypeInfo (
		PropertyID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		HowMany int null,
		Name nvarchar(50) null,
		UnitTypeSquareFootage int null,
		MarketRent money null,
		NetRentalIncome money null)

	CREATE TABLE #Traffic (
		PropertyID uniqueidentifier not null,
		ProspectSourceID uniqueidentifier not null,
		Name nvarchar(200) null,
		UnitTypeID uniqueidentifier null,
		TrafficCount int null,
		TourCount int null,
		MoveInCount int null)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #MarketRentWorksheet (
		PropertyID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null, 
		UnitID uniqueidentifier null,
		LeaseID uniqueidentifier null,
		MarketRent money null,
		ActualRent money null)

	INSERT #PropertiesAndDates
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @endDate, @accountingPeriodID, @propertyIDs

	INSERT #OccupiedUnitCount
		SELECT p.PropertyID, p.Name, ut.UnitTypeID, ut.Name, COUNT(DISTINCT u.UnitID), null, null, null, null, null, null
			FROM Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
				INNER JOIN Property p ON #pad.PropertyID = p.propertyID
			WHERE u.ExcludedFromOccupancy = 0
				AND (u.DateRemoved IS NULL OR u.DateRemoved > #pad.EndDate)
			GROUP BY p.PropertyID, p.Name, ut.UnitTypeID, ut.Name

	UPDATE #OccupiedUnitCount SET AverageSquareFootage = (SELECT SUM(u.SquareFootage)
															  FROM Unit u
															  INNER JOIN Building b ON b.BuildingID = u.BuildingID
															  INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = b.PropertyID
																  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
															  WHERE u.ExcludedFromOccupancy = 0
																AND (u.DateRemoved IS NULL OR u.DateRemoved > #pad.EndDate)
															    AND ut.PropertyID = #OccupiedUnitCount.PropertyID
																AND ut.UnitTypeID = #OccupiedUnitCount.UnitTypeID)

	UPDATE #OccupiedUnitCount SET AverageSquareFootage = AverageSquareFootage / UnitCount

	UPDATE #OccupiedUnitCount SET OccupiedUnitCount = (SELECT COUNT(DISTINCT #lau.UnitID) 
															FROM #LeasesAndUnits #lau
																INNER JOIN Unit u ON #lau.UnitID = u.UnitID
																INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID 
															WHERE #lau.OccupiedUnitLeaseGroupID IS NOT NULL
															  AND #OccupiedUnitCount.PropertyID = ut.PropertyID
															  AND #OccupiedUnitCount.UnitTypeID = ut.UnitTypeID)

	UPDATE #OccupiedUnitCount SET RentReadyUnits = (SELECT COUNT(DISTINCT u.UnitID) 
														FROM Unit u
															INNER JOIN #LeasesAndUnits #lau ON u.UnitID = #lau.UnitID AND #lau.OccupiedUnitLeaseGroupID IS NULL
															INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
															INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
															CROSS APPLY dbo.GetUnitStatusByUnitID(u.UnitID, #pad.EndDate) [UStat]
														 WHERE u.ExcludedFromOccupancy = 0
														   AND (u.DateRemoved IS NULL OR u.DateRemoved > #pad.EndDate)
														   AND [UStat].[Status] = 'Ready'
														   AND #OccupiedUnitCount.PropertyID = #lau.PropertyID
														   AND #OccupiedUnitCount.UnitTypeID = ut.UnitTypeID)

	UPDATE #OccupiedUnitCount SET MTMLeases = (SELECT COUNT(l.LeaseID)
												   FROM Lease l
													   INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
													   INNER JOIN Unit u ON ulg.UnitID = u.UnitID
													   INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
													   INNER JOIN #LeasesAndUnits #lau ON ulg.UnitLeaseGroupID = #lau.OccupiedUnitLeaseGroupID
													   INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
												   WHERE l.LeaseID = (SELECT TOP 1 LeaseID
																		   FROM Lease
																		   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																		     AND LeaseStatus IN ('Current', 'Under Eviction')
																		   ORDER BY LeaseEndDate DESC)

												     AND l.LeaseEndDate < #pad.EndDate
													 AND #OccupiedUnitCount.PropertyID = #lau.PropertyID
													 AND #OccupiedUnitCount.UnitTypeID = ut.UnitTypeID)

	UPDATE #OccupiedUnitCount SET LeasesExpiring30 = (SELECT COUNT(l.LeaseID)
														  FROM Lease l
															  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
															  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
															  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
															  INNER JOIN #LeasesAndUnits #lau ON ulg.UnitLeaseGroupID = #lau.OccupiedUnitLeaseGroupID
															  INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
														  WHERE l.LeaseID = (SELECT TOP 1 LeaseID
																				  FROM Lease
																				  WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																					AND LeaseStatus IN ('Current', 'Under Eviction')
																				  ORDER BY LeaseEndDate DESC)
															AND l.LeaseEndDate > #pad.EndDate
															AND l.LeaseEndDate <= DATEADD(MONTH, 1, #pad.EndDate)
															AND #OccupiedUnitCount.PropertyID = ut.PropertyID
															AND #OccupiedUnitCount.UnitTypeID = ut.UnitTypeID)

	UPDATE #OccupiedUnitCount SET LeasesExpiring90 = (SELECT COUNT(l.LeaseID)
														  FROM Lease l
															  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
															  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
															  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
															  INNER JOIN #LeasesAndUnits #lau ON ulg.UnitLeaseGroupID = #lau.OccupiedUnitLeaseGroupID
															  INNER JOIN #PropertiesAndDates #pad ON #lau.PropertyID = #pad.PropertyID
														  WHERE l.LeaseID = (SELECT TOP 1 LeaseID
																				  FROM Lease
																				  WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																					AND LeaseStatus IN ('Current', 'Under Eviction')
																				  ORDER BY LeaseEndDate DESC)
															AND l.LeaseEndDate > #pad.EndDate
															AND l.LeaseEndDate <= DATEADD(MONTH, 3, #pad.EndDate)
															AND #OccupiedUnitCount.PropertyID = ut.PropertyID
															AND #OccupiedUnitCount.UnitTypeID = ut.UnitTypeID)

	
	INSERT #UnitTypeInfo
		SELECT #pad.PropertyID, ut.UnitTypeID, null, ut.Name, ut.SquareFootage, null, null
			FROM UnitType ut
				INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID

INSERT #MarketRentWorksheet
		SELECT #pad.PropertyID, ut.UnitTypeID, u.UnitID, null, /*[ThisLease].LeaseID,*/ [MarketRent].Amount, null
			FROM UnitType ut
				INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
				INNER JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID AND u.ExcludedFromOccupancy = 0 AND (u.DateRemoved IS NULL OR u.DateRemoved > #pad.EndDate)
				INNER JOIN #LeasesAndUnits #lau ON u.UnitID = #lau.UnitID
				CROSS APPLY dbo.GetMarketRentByDate(u.UnitID, #pad.EndDate, 1) [MarketRent]
				--LEFT JOIN 
				--		(SELECT l.LeaseID, ulg.UnitID
				--			FROM Lease l
				--				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				--			WHERE l.LeaseID = (SELECT TOP 1 LeaseID
				--								   FROM Lease 
				--								   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
				--								     AND LeaseStatus IN ('Current', 'Under Eviction', 'Pending-'))) [ThisLease] ON #lau.UnitID = [ThisLease].UnitID

	UPDATE #MarketRentWorksheet SET LeaseID = (SELECT TOP 1 l.LeaseID
											   FROM Lease l
											    INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
												INNER JOIN #LeasesAndUnits #lau ON #lau.OccupiedUnitLeaseGroupID = l.UnitLeaseGroupID
												INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #lau.PropertyID
											   WHERE l.LeaseStartDate <= #pad.EndDate
													AND l.LeaseEndDate >= #pad.EndDate
													AND ulg.UnitID = #MarketRentWorksheet.UnitID
												ORDER BY l.DateCreated)

	UPDATE #MarketRentWorksheet SET LeaseID = (SELECT TOP 1 l.LeaseID
											   FROM Lease l
											    INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
												INNER JOIN #LeasesAndUnits #lau ON #lau.OccupiedUnitLeaseGroupID = l.UnitLeaseGroupID
												INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #lau.PropertyID
											   WHERE l.LeaseStartDate <= #pad.EndDate													
													AND ulg.UnitID = #MarketRentWorksheet.UnitID
												ORDER BY l.LeaseEndDate DESC)
	WHERE LeaseID IS NULL

	UPDATE #MarketRentWorksheet SET LeaseID = (SELECT TOP 1 #lau.OccupiedLastLeaseID
											   FROM  #LeasesAndUnits #lau
											   WHERE #lau.UnitID = #MarketRentWorksheet.UnitID)
	WHERE LeaseID IS NULL





	UPDATE #MarketRentWorksheet SET ActualRent = (SELECT SUM(lli.Amount)
													  FROM LeaseLedgerItem lli
														  INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
														  INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
														  INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
														  INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
														  INNER JOIN Unit u ON u.UnitID =ulg.UnitID
														  INNER JOIN Building b ON b.BuildingID = u.BuildingID
														  INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = b.PropertyID 
													  WHERE lli.StartDate <= #pad.EndDate
														AND lli.EndDate >= #pad.EndDate
													    AND l.LeaseID = #MarketRentWorksheet.LeaseID)

	UPDATE #UnitTypeInfo SET MarketRent = (SELECT SUM(MarketRent)
											   FROM #MarketRentWorksheet 
											   WHERE UnitTypeID = #UnitTypeInfo.UnitTypeID
											   GROUP BY UnitTypeID)
	
	UPDATE #UnitTypeInfo SET NetRentalIncome = (SELECT SUM(ActualRent)
												   FROM #MarketRentWorksheet 
												   WHERE UnitTypeID = #UnitTypeInfo.UnitTypeID
												   GROUP BY UnitTypeID)

	UPDATE #UnitTypeInfo SET HowMany = (SELECT COUNT(*) 
											FROM Unit u
												INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
												INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
											WHERE u.ExcludedFromOccupancy = 0
											  AND (u.DateRemoved IS NULL OR u.DateRemoved > #pad.EndDate)
											  AND #UnitTypeInfo.UnitTypeID = ut.UnitTypeID
											GROUP BY ut.UnitTypeID)


	UPDATE #UnitTypeInfo SET MarketRent = MarketRent / HowMany WHERE HowMany > 0
	
	
	UPDATE #UnitTypeInfo SET HowMany = (SELECT COUNT(*) 
											FROM Unit u
												INNER JOIN #LeasesAndUnits #lau ON #lau.UnitID = u.UnitID
												INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
											WHERE  #UnitTypeInfo.UnitTypeID = ut.UnitTypeID
												AND #lau.OccupiedUnitLeaseGroupID IS NOT NULL
											GROUP BY ut.UnitTypeID)






	 
	UPDATE #UnitTypeInfo SET NetRentalIncome = NetRentalIncome / HowMany WHERE HowMany > 0

	INSERT #Traffic
		SELECT #pad.PropertyID,	ps.ProspectSourceID, ps.Name, ut.UnitTypeID, 0, 0, 0
			FROM PropertyProspectSource pps
				INNER JOIN #PropertiesAndDates #pad ON pps.PropertyID = #pad.PropertyID
				INNER JOIN ProspectSource ps ON pps.ProspectSourceID = ps.ProspectSourceID
				INNER JOIN UnitType ut ON 1 = 1 AND ut.PropertyID = #pad.PropertyID

	UPDATE #Traffic SET TrafficCount = (SELECT COUNT(pnFirst.PersonNoteID)
											FROM PersonNote pnFirst
												INNER JOIN Prospect pros ON pnFirst.PersonID = pros.PersonID
												INNER JOIN PersonType pt ON pros.PersonID = pt.PersonID AND [Type] = 'Prospect'
												INNER JOIN PropertyProspectSource pps ON pros.PropertyProspectSourceID = pps.PropertyProspectSourceID
												INNER JOIN #PropertiesAndDates #pad ON pps.PropertyID = #pad.PropertyID AND pnFirst.PropertyID = #pad.PropertyID
												INNER JOIN ProspectUnitType put ON pros.ProspectID = put.ProspectID
												INNER JOIN Person pEmp ON pnFirst.CreatedByPersonID = pEmp.PersonID
												INNER JOIN PersonType ptpEmp ON pEmp.PersonID = ptpEmp.PersonID AND ptpEmp.[Type] = 'Employee'
												LEFT JOIN PersonNote pnEarlier ON pros.PersonID = pnEarlier.PersonID AND pnEarlier.[Date] < #pad.StartDate
											WHERE pnFirst.[Date] >= #pad.StartDate
											  AND pnFirst.[Date] <= #pad.EndDate
											  AND pnFirst.ContactType IN ('Face-to-Face', 'Phone', 'Email')
											  AND pnEarlier.PersonNoteID IS NULL
											  AND put.ProspectUnitTypeID = (SELECT TOP 1 ProspectUnitTypeID
																				FROM ProspectUnitType
																				WHERE UnitTypeID = put.UnitTypeID
																				  AND ProspectID = pros.ProspectID)
											  AND pps.ProspectSourceID = #Traffic.ProspectSourceID
											  AND put.UnitTypeID = #Traffic.UnitTypeID)

	UPDATE #Traffic SET TourCount = (SELECT COUNT(pn.PersonNoteID)
											FROM PersonNote pn
												INNER JOIN Prospect pros ON pn.PersonID = pros.PersonID
												INNER JOIN PersonType pt ON pros.PersonID = pt.PersonID AND [Type] = 'Prospect'
												INNER JOIN PropertyProspectSource pps ON pros.PropertyProspectSourceID = pps.PropertyProspectSourceID
												INNER JOIN #PropertiesAndDates #pad ON pps.PropertyID = #pad.PropertyID AND pn.PropertyID = #pad.PropertyID
												INNER JOIN ProspectUnitType put ON pros.ProspectID = put.ProspectID
												INNER JOIN Person pEmp ON pn.CreatedByPersonID = pEmp.PersonID
												INNER JOIN PersonType ptpEmp ON pEmp.PersonID = ptpEmp.PersonID AND ptpEmp.[Type] = 'Employee'
											WHERE pn.[Date] >= #pad.StartDate
											  AND pn.[Date] <= #pad.EndDate
											  AND pn.InteractionType IN ('Unit Shown')
											  AND put.ProspectUnitTypeID = (SELECT TOP 1 ProspectUnitTypeID
																				FROM ProspectUnitType
																				WHERE UnitTypeID = put.UnitTypeID
																				  AND ProspectID = pros.ProspectID)
											  AND pps.ProspectSourceID = #Traffic.ProspectSourceID
											  AND put.UnitTypeID = #Traffic.UnitTypeID)
	

			  
	CREATE TABLE #NewLeases (
		PropertyID uniqueidentifier not null,
		LeaseID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		LeaseStatus nvarchar(50) null,
		LeasingAgentPersonID uniqueidentifier null,
		ProspectID uniqueidentifier null,
		ProspectSourceID uniqueidentifier null,
		MarketRent money null,
		ActualRent money null,
		UnitTypeID uniqueidentifier null)		

	INSERT #NewLeases
		SELECT ut.PropertyID,
			   l.LeaseID,
			   ulg.UnitID,  
			   l.LeaseStatus,
			   l.LeasingAgentPersonID,
			   null, -- ProspectID
			   null, -- PropertyProspectSourceID
			   null, -- MarketRent
			   null, -- ActualRent
			   ut.UnitTypeID
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = ut.PropertyID

			WHERE 		
				-- Make sure we only take into account the first lease in a given unit lease group
				l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)				
				-- Ensure we only get leases that actually applied during the date range
				AND #pad.StartDate <= (SELECT MIN(pl.MoveInDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)
				AND #pad.EndDate >= (SELECT MIN(pl.MoveInDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)  			  			  			  
				-- Make sure we don't take into account transferred residents
				AND ulg.PreviousUnitLeaseGroupID IS NULL					  
				AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
		  		
		-- Update prospect id for main prospects
		UPDATE #NewLeases SET ProspectID = (SELECT TOP 1 pr.ProspectID 
												 FROM Prospect pr													  
													  INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													  INNER JOIN PersonLease pl ON pl.LeaseID = #NewLeases.LeaseID AND pr.PersonID = pl.PersonID
												 WHERE pps.PropertyID = #NewLeases.PropertyID)
													   	
													 
		-- Update prospect id for roommates											 
		UPDATE #NewLeases SET ProspectID = (SELECT TOP 1 pr.ProspectID 
												FROM Prospect pr	
													INNER JOIN ProspectRoommate proroom ON pr.ProspectID = proroom.ProspectID												 
													INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													INNER JOIN PersonLease pl ON pl.LeaseID = #NewLeases.LeaseID AND proroom.PersonID = pl.PersonID
												WHERE pps.PropertyID = #NewLeases.PropertyID)
		WHERE #NewLeases.ProspectID IS NULL

		UPDATE #NewLeases SET ProspectSourceID = (SELECT TOP 1 pps.ProspectSourceID 
													FROM Prospect p
														INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = p.PropertyProspectSourceID
													WHERE p.ProspectID = #NewLeases.ProspectID)

		UPDATE #NewLeases SET ProspectSourceID =  '00000000-0000-0000-0000-000000000000' WHERE ProspectSourceID IS NULL
	
		--UPDATE #NL SET ActualRent = SUM(lli.Amount)
		--	FROM #NewLeases #NL
		--		INNER JOIN LeaseLedgerItem lli ON #NL.LeaseID = lli.LeaseID
		--		INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
		--		INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
		--		INNER JOIN #PropertiesAndDates #pad ON #NL.PropertyID = #pad.PropertyID 
		--	WHERE lli.StartDate <= #pad.EndDate

		--UPDATE #NL SET MarketRent = [MarketRent].Amount
		--	FROM #NewLeases #NL
		--		INNER JOIN #PropertiesAndDates #pad ON #NL.PropertyID = #pad.PropertyID
		--		CROSS APPLY dbo.GetMarketRentByDate(#NL.UnitID, #pad.EndDate, 1) [MarketRent]

		UPDATE #Traffic SET MoveInCount = (SELECT COUNT(*) 
											   FROM #NewLeases
											   WHERE #Traffic.PropertyID = PropertyID
											     AND #Traffic.ProspectSourceID = ProspectSourceID
												 AND #Traffic.UnitTypeID = UnitTypeID) 

		SELECT * 
			FROM #OccupiedUnitCount

		SELECT *
			FROM #UnitTypeInfo
			ORDER BY Name

		SELECT *
			FROM #Traffic
			WHERE TrafficCount <> 0 OR MoveInCount <> 0 OR TourCount <> 0
			ORDER BY Name

END
GO
