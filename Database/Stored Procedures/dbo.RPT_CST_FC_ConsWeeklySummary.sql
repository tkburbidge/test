SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 16, 2016
-- Description:	First Choice custom consolodated weekly summary report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_FC_ConsWeeklySummary] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Occupancy (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) null,
		Units int null,
		OccupiedUnits int null,						
		Vacant int null,
		VacantRented int null,
		VacantUnrented int null,
		TotalNotices int null,
		NoticeRented int null,
		NoticeUnrented int null,
		VacantReady int null)

	CREATE TABLE #Activity (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) null,
		MoveIns int null,
		MoveOuts int null,
		Notice int null)

	CREATE TABLE #Traffic (				-- Note - Traffic is a great movie too!
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) null,
		Traffic int null,
		Shows int null, 
		Applied int null,
		Unqualified int null,
		Approved int null,
		Denied int null,
		PendingApproval int null)

	CREATE TABLE #NewLeases (
		PropertyID uniqueidentifier null,
		NewLeases int null,
		CanceledDeniedLeases int null)

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
		PropertyID uniqueidentifier null,
		DefinedStartDate date null,
		StartDate date null,
		EndDate date null)

	INSERT #PropertiesAndDates
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)			
			FROM @propertyIDs pIDs
			LEFT JOIN PropertyAccountingPeriod pap ON pap.PropertyID = pIDs.Value AND pap.AccountingPeriodID = @accountingPeriodID

	

	INSERT #Occupancy
		SELECT PropertyID, null, null, null, null, null, null, null, null, null, null
			FROM #PropertiesAndDates

	INSERT #Activity
		SELECT PropertyID, null, null, null, null
			FROM #PropertiesAndDates	
			
	INSERT #Traffic
		SELECT PropertyID, null, null, null, null, null, null, null, null
			FROM #PropertiesAndDates

	INSERT #NewLeases 
		SELECT PropertyID, null, null
			FROM #PropertiesAndDates

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @endDate, @accountingPeriodID, @propertyIDs	

	-- do logic to see if approved or not
	ALTER TABLE #LeasesAndUnits ADD IsApproved bit null	

	UPDATE #LeasesAndUnits SET IsApproved = (SELECT CASE WHEN (pn.PersonNoteID IS NOT NULL) THEN 1 
														 ELSE 0 END
												   FROM UnitLeaseGroup ulg
														INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
														INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
														INNER JOIN #PropertiesAndDates #pad ON #LeasesAndUnits.PropertyID = #pad.PropertyID
														LEFT JOIN PersonNote pn ON pl.PersonID = pn.PersonID AND pn.PropertyID = #LeasesAndUnits.PropertyID
																											 AND pn.InteractionType = 'Approved'
																									 		 AND pl.ApprovalStatus = 'Approved'
																											 AND pn.Date <= #pad.EndDate
												   WHERE ulg.UnitLeaseGroupID = #LeasesAndUnits.PendingUnitLeaseGroupID
												     AND pn.DateCreated > l.DateCreated
													 --AND #CurrentOccupants.OccupiedUnitLeaseGroupID IS NULL
													 AND #LeasesAndUnits.PendingUnitLeaseGroupID IS NOT NULL
													 AND pl.PersonLeaseID = (SELECT TOP 1 pl1.PersonLeaseID	
																				FROM PersonLease pl1
																					INNER JOIN PersonNote pn1 on pl1.PersonID = pn1.personID
																				WHERE pl1.LeaseID = l.LeaseID
																					AND pn1.PropertyID = #LeasesAndUnits.PropertyID
																					AND pl1.ApprovalStatus = 'Approved'
																					AND pn1.InteractionType = 'Approved'
																				ORDER BY pn1.[Date] ASC, pl1.ApplicationDate, pl1.OrderBy, pl1.PersonLeaseID)
													AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID
																			   FROM PersonNote pn2
																			   WHERE pn2.PersonID = pl.PersonID
																				AND pn2.InteractionType = 'Approved'
																				AND pn2.PropertyID = #LeasesAndUnits.PropertyID
																				AND pn2.DateCreated > l.DateCreated -- Approval is after the lease is created. This accounts for transferred leases. Don't want to show a transferred lease as approved 2 years before
																			   ORDER BY pn2.[Date] ASC)) 

	UPDATE #lau
		SET #lau.IsApproved = 1
	FROM #LeasesAndUnits #lau
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = #lau.PendingUnitLeaseGroupID AND ulg.PreviousUnitLeaseGroupID IS NOT NULL
	--WHERE IsApproved IS NULL

	UPDATE #LeasesAndUnits SET IsApproved = 0 WHERE IsApproved IS NULL

	UPDATE #Occupancy SET Units = (SELECT COUNT(DISTINCT UnitID)
									   FROM #LeasesAndUnits 
									   WHERE PropertyID = #Occupancy.PropertyID)

	UPDATE #Occupancy SET Vacant = (SELECT COUNT(*)
											  FROM #LeasesAndUnits 
											  WHERE OccupiedUnitLeaseGroupID IS NULL											    
												AND PropertyID = #Occupancy.PropertyID)

	UPDATE #Occupancy SET VacantRented = (SELECT COUNT(*)
											  FROM #LeasesAndUnits 
											  WHERE OccupiedUnitLeaseGroupID IS NULL
											    AND PendingUnitLeaseGroupID IS NOT NULL
												AND PropertyID = #Occupancy.PropertyID
												AND IsApproved = 1)

	UPDATE #Occupancy SET VacantUnrented = (SELECT COUNT(*) 
												FROM #LeasesAndUnits
												WHERE OccupiedUnitLeaseGroupID IS NULL
												  AND PendingUnitLeaseGroupID IS NULL
												  AND PropertyID = #Occupancy.PropertyID)

	UPDATE #Occupancy SET NoticeRented = (SELECT COUNT(*)
											  FROM #LeasesAndUnits
												INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #LeasesAndUnits.PropertyID
											  WHERE OccupiedUnitLeaseGroupID IS NOT NULL
											    AND OccupiedMoveOutDate IS NOT NULL
												AND PendingUnitLeaseGroupID IS NOT NULL
												AND OccupiedNTVDate <= #pad.EndDate
												AND #LeasesAndUnits.PropertyID = #Occupancy.PropertyID
												AND IsApproved = 1)

	UPDATE #Occupancy SET NoticeUnrented = (SELECT COUNT(*)
											    FROM #LeasesAndUnits
													INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #LeasesAndUnits.PropertyID
											    WHERE OccupiedUnitLeaseGroupID IS NOT NULL
											      AND OccupiedMoveOutDate IS NOT NULL
												  AND PendingUnitLeaseGroupID IS NULL
												  AND OccupiedNTVDate <= #pad.EndDate
												  AND #LeasesAndUnits.PropertyID = #Occupancy.PropertyID)

	UPDATE #Occupancy SET TotalNotices = (SELECT COUNT(*)
											    FROM #LeasesAndUnits
													INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #LeasesAndUnits.PropertyID
											    WHERE OccupiedUnitLeaseGroupID IS NOT NULL
											      AND OccupiedMoveOutDate IS NOT NULL												  
												  AND OccupiedNTVDate <= #pad.EndDate
												  AND #LeasesAndUnits.PropertyID = #Occupancy.PropertyID)

	
	UPDATE #Occupancy SET OccupiedUnits = (SELECT COUNT(DISTINCT UnitID)
											  FROM #LeasesAndUnits
											  WHERE OccupiedUnitLeaseGroupID IS NOT NULL
											    AND #Occupancy.PropertyID = PropertyID)

	UPDATE #Occupancy SET VacantReady = (SELECT COUNT(*) 
												FROM #LeasesAndUnits #lau
												INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #lau.PropertyID
												CROSS APPLY GetUnitStatusByUnitID(#lau.UnitID, #pad.EndDate) us
												WHERE OccupiedUnitLeaseGroupID IS NULL												 
												  AND #lau.PropertyID = #Occupancy.PropertyID
												  AND us.[Status] IN ('Ready'))

	UPDATE #Traffic SET PendingApproval = (SELECT COUNT(*)
											  FROM #LeasesAndUnits
											  WHERE PendingUnitLeaseGroupID IS NOT NULL
												AND PropertyID = #Traffic.PropertyID
												AND IsApproved = 0)													

	--SELECT * FROM #LeasesAndUnits order by unitnumber

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

	UPDATE #Activity SET MoveIns = (SELECT COUNT(*) 
									 FROM #ResidentActivity #ra
									 WHERE #ra.PropertyiD = #Activity.PropertyID
										AND #ra.[Type] = 'MoveIn')

	UPDATE #Activity SET MoveOuts = (SELECT COUNT(*) 
									 FROM #ResidentActivity #ra
									 WHERE #ra.PropertyiD = #Activity.PropertyID
										AND #ra.[Type] = 'MoveOut')

	--UPDATE #Activity SET MoveIns = (SELECT COUNT(DISTINCT l.LeaseID)
	--									FROM Lease l
	--										INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--										INNER JOIN Unit u ON ulg.UnitID = u.UnitID
	--										INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	--										INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
	--										INNER JOIN PersonLease plMI ON l.LeaseID = plMI.LeaseID AND plMI.MoveInDate >= #pad.StartDate AND plMI.MoveInDate <= #pad.EndDate
	--										LEFT JOIN PersonLease plMINull ON l.LeaseID = plMINull.LeaseID AND plMINull.MoveInDate < #pad.StartDate
	--									WHERE #pad.PropertyID = #Activity.PropertyID
	--									  AND plMINull.PersonLeaseID IS NULL)

	--UPDATE #Activity SET MoveOuts = (SELECT COUNT(DISTINCT l.LeaseID)
	--									FROM Lease l
	--										INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--										INNER JOIN Unit u ON ulg.UnitID = u.UnitID
	--										INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	--										INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
	--										INNER JOIN PersonLease plMO ON l.LeaseID = plMO.LeaseID AND plMO.MoveOutDate >= #pad.StartDate AND plMO.MoveOutDate <= #pad.EndDate
	--										LEFT JOIN PersonLease plMONull ON l.LeaseID = plMONull.LeaseID AND plMONull.MoveOutDate > #pad.EndDate
	--									WHERE #pad.PropertyID = #Activity.PropertyID
	--									  AND plMONull.PersonLeaseID IS NULL)

	--UPDATE #Activity SET Notice = (SELECT COUNT(DISTINCT l.LeaseID)
	--									FROM Lease l
	--										INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--										INNER JOIN Unit u ON ulg.UnitID = u.UnitID
	--										INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	--										INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
	--										INNER JOIN PersonLease plNo ON l.LeaseID = plNo.LeaseID AND plNo.NoticeGivenDate >= #pad.StartDate AND plNo.NoticeGivenDate <= #pad.EndDate
	--										LEFT JOIN PersonLease plNoNull ON l.LeaseID = plNoNull.LeaseID AND plNoNull.NoticeGivenDate < #pad.StartDate
	--									WHERE #pad.PropertyID = #Activity.PropertyID
	--									  AND plNoNull.PersonLeaseID IS NULL)

	UPDATE #Traffic SET Traffic = (SELECT COUNT(DISTINCT pros.ProspectID)
									   FROM Prospect pros
										   INNER JOIN PersonNote pn ON pros.FirstPersonNoteID = pn.PersonNoteID
										   INNER JOIN #PropertiesAndDates #pad ON pn.PropertyID = #pad.PropertyID AND pn.[Date] >= #pad.StartDate AND pn.[Date] <= #pad.EndDate
									   WHERE #pad.PropertyID = #Traffic.PropertyID)

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


		-- Approved Application
		INSERT INTO #Applicants
			SELECT 
				'ApprovedApplication' AS 'Type',
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
				INNER JOIN PersonNote pn ON pl.PersonID = pn.PersonID AND pn.PropertyID = #pad.PropertyID AND pn.InteractionType = 'Approved' 
			WHERE pl.PersonLeaseID = (SELECT TOP 1 pl1.PersonLeaseID	
												FROM PersonLease pl1
													INNER JOIN PersonNote pn1 on pl1.PersonID = pn1.personID
												WHERE pl1.LeaseID = l.LeaseID
													AND pn1.PropertyID = p.PropertyID
													AND pl1.ApprovalStatus = 'Approved'
													AND pn1.InteractionType = 'Approved'
												ORDER BY pn1.[Date] ASC, pl1.ApplicationDate, pl1.OrderBy, pl1.PersonLeaseID)
				AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID
									   FROM PersonNote pn2
									   WHERE pn2.PersonID = pl.PersonID
										AND pn2.InteractionType = 'Approved'
										AND pn2.PropertyID = #pad.PropertyID
										AND pn2.DateCreated > l.DateCreated -- Approval is after the lease is created. This accounts for transferred leases. Don't want to show a transferred lease as approved 2 years before
									   ORDER BY pn2.[Date] ASC)
				AND pn.[Date] >= #pad.StartDate
				AND pn.[Date] <= #pad.EndDate				
				AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
								 FROM Lease l2 
								 WHERE l2.UnitLeaseGroupID = l.UnitLeaseGroupID
								 ORDER by l2.DateCreated)

	UPDATE #Applicants SET IsRenewal = 1 WHERE LeaseID <> (SELECT TOP 1 LeaseID 
															   FROM Lease 
															   WHERE UnitLeaseGroupID = #Applicants.UnitLeaseGroupID
															   ORDER BY LeaseStartDate, DateCreated)

	UPDATE #Applicants SET [Type] = REPLACE([Type], 'Application', 'Renewal') WHERE IsRenewal = 1

	UPDATE #Traffic SET Applied = (SELECT COUNT(*) 
									FROM #Applicants #a
									WHERE #a.PropertyID = #Traffic.PropertyID
									AND #a.[Type] = 'NewApplication')
	
	UPDATE #Traffic SET Approved = (SELECT COUNT(*) 
										FROM #Applicants #a
										WHERE #a.PropertyID = #Traffic.PropertyID
										AND #a.[Type] = 'ApprovedApplication')

	--UPDATE #Traffic SET Applied = (SELECT COUNT(DISTINCT l.LeaseID)
	--								   FROM Lease l
	--									   INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--									   INNER JOIN Unit u ON ulg.UnitID = u.UnitID
	--									   INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	--									   INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
	--									   INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ApplicationDate >= #pad.StartDate AND pl.ApplicationDate <= #pad.EndDate
	--									   LEFT JOIN Lease prevL ON ulg.UnitLeaseGroupID = prevL.UnitLeaseGroupID AND prevL.LeaseCreated < l.LeaseCreated
	--								   WHERE ulg.PreviousUnitLeaseGroupID IS NULL
	--								     AND prevL.LeaseID IS NULL
	--									 AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
	--																 FROM PersonLease
	--																 WHERE LeaseID = l.LeaseID
	--																 ORDER BY ApplicationDate)
	--								     AND #pad.PropertyID = #Traffic.PropertyID)

	--UPDATE #Traffic SET PendingApproval = (SELECT COUNT(DISTINCT l.LeaseID)
	--											FROM Lease l
	--												INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--												INNER JOIN Unit u ON ulg.UnitID = u.UnitID
	--												INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	--												INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
	--												INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
	--												LEFT JOIN PersonNote pnApp ON pl.PersonID = pnApp.PersonID AND pnApp.InteractionType = 'Approved'
	--											WHERE l.LeaseStatus = 'Pending'
	--											  AND pnApp.PersonNoteID IS NULL
	--											  AND #pad.PropertyID = #Traffic.PropertyID)

/*
	UPDATE #Traffic SET Unqualified = (SELECT COUNT(DISTINCT pros.ProspectID)
												   FROM Prospect pros
												INNER JOIN PropertyProspectSource pps ON pros.PropertyProspectSourceID = pps.PropertyProspectSourceID
												INNER JOIN #PropertiesAndDates #pad ON pps.PropertyID = #pad.PropertyID AND pros.LostDate >= #pad.StartDate AND pros.LostDate <= #pad.EndDate
												INNER JOIN PickListItem pli ON pros.LostReasonPickListItemID = pli.PickListItemID
												INNER JOIN PickListItemCategory plic ON pli.PickListItemCategoryID = plic.PickListItemCategoryID AND plic.Unqualified = 1
									   WHERE #pad.PropertyID = #Traffic.PropertyID)

	UPDATE #Traffic SET Approved = (SELECT COUNT(DISTINCT #lau.PendingUnitLeaseGroupID)
										FROM #LeasesAndUnits #lau
											INNER JOIN Lease l ON #lau.PendingUnitLeaseGroupID = l.UnitLeaseGroupID
											INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ApprovalStatus IN ('Approved')
										WHERE #Traffic.PropertyID = #lau.PropertyID)

	UPDATE #Traffic SET Denied = (SELECT COUNT(DISTINCT l.LeaseID)
									  FROM Lease l
										  INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
										  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
										  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
										  INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
										  INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
										  LEFT JOIN PersonLease plMONull ON l.LeaseID = plMONull.LeaseID AND plMONull.MoveOutDate > #pad.EndDate
									  WHERE (pl.MoveOutDate >= #pad.StartDate AND pl.MoveOutDate <= #pad.EndDate)
									    AND l.LeaseStatus IN ('Denied')
										AND plMONull.PersonLeaseID IS NULL
									    AND #pad.PropertyID = #Traffic.PropertyID)
*/

	--UPDATE #NewLeases SET NewLeases = (SELECT COUNT(DISTINCT l.LeaseID)
	--									   FROM Lease l
	--										   INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--										   INNER JOIN Unit u ON ulg.UnitID = u.UnitID
	--										   INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	--										   INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
	--										   INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
	--										   LEFT JOIN PersonLease plSignedBefore ON l.LeaseID = plSignedBefore.LeaseID AND plSignedBefore.LeaseSignedDate < #pad.StartDate
	--										WHERE pl.LeaseSignedDate >= #pad.StartDate
	--										  AND pl.LeaseSignedDate <= #pad.EndDate
	--										  AND plSignedBefore.PersonLeaseID IS NULL
	--										  AND #NewLeases.PropertyID = #pad.PropertyID
	--										  AND l.LeaseStatus IN ('Pending', 'Current', 'Under Eviction', 'Former', 'Evicted')
	--										  )

	--UPDATE #NewLeases SET CanceledDeniedLeases = (SELECT COUNT(DISTINCT l.LeaseID)
	--												   FROM Lease l
	--													   INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--													   INNER JOIN Unit u ON ulg.UnitID = u.UnitID
	--													   INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	--													   INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
	--													   INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
	--													   LEFT JOIN PersonLease plSignedBefore ON l.LeaseID = plSignedBefore.LeaseID AND plSignedBefore.LeaseSignedDate < #pad.StartDate
	--													WHERE pl.LeaseSignedDate >= #pad.StartDate
	--													  AND pl.LeaseSignedDate <= #pad.EndDate
	--													  AND plSignedBefore.PersonLeaseID IS NULL
	--													  AND #NewLeases.PropertyID = #pad.PropertyID
	--													  AND l.LeaseStatus IN ('Cancelled', 'Denied'))

	UPDATE #Occupancy SET PropertyName = (SELECT prop.Name FROM Property prop WHERE #Occupancy.PropertyID = prop.PropertyID)

	SELECT	DISTINCT
			#occ.PropertyName AS 'PropertyName',
			#occ.PropertyID AS 'PropertyID',
			ISNULL(#occ.Units, 0) AS 'TotalUnits',
			ISNULL(#traf.Approved, 0) AS 'NewLeases',
			ISNULL(#nl.CanceledDeniedLeases, 0) AS 'NewLeasesCanceledDenied',
			ISNULL(#occ.OccupiedUnits, 0) AS 'TotalOccupied',
			ISNULL(#act.MoveIns, 0) AS 'MoveIns',
			ISNULL(#act.MoveOuts, 0) AS 'MoveOuts',
			ISNULL(#occ.VacantUnrented, 0) AS 'VacantUnrented',
			ISNULL(#occ.VacantReady, 0) AS 'VacantReady',
			ISNULL(#occ.Vacant, 0) AS 'TotalVacant',
			ISNULL(#occ.VacantRented, 0) AS 'VacantLeased',
			ISNULL(#act.Notice, 0) AS 'NoticesRecd',
			ISNULL(#occ.NoticeRented, 0) AS 'NoticesLeased',
			ISNULL(#occ.NoticeUnrented, 0) AS 'NoticesUnrented',
			ISNULL(#occ.TotalNotices, 0) AS 'TotalNotices',
			ISNULL(#traf.Traffic, 0) AS 'TotalTraffic',
			ISNULL(#traf.Applied, 0) AS 'TotalApplied',					--needs updated to return total number of lease applications in the period regardless of status (including both preleases and units on notice)
			ISNULL(#traf.PendingApproval, 0) AS 'PendingApproval'		-- needs updated to return total number of lease applications in the period where the application has not yet been approved, cancelled, or denied (equivalent to a 'P' status next to the name on the resident detail page)
		FROM #Occupancy #occ
			INNER JOIN #Activity #act ON #occ.PropertyID = #act.PropertyID
			INNER JOIN #NewLeases #nl ON #occ.PropertyID = #nl.PropertyID
			INNER JOIN #Traffic #traf ON #occ.PropertyID = #traf.PropertyID

END
GO
