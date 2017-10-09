SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 21, 2014
-- Description:	Creates the data for the custom report LeasingStatistics
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_PLP_LeasingStatistics] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    CREATE TABLE #Statistics (
		ProspectID uniqueidentifier null,
		PropertyID uniqueidentifier null,
		Prospects int null,
		ProspectSourceID uniqueidentifier null,
		LeasingAgentID uniqueidentifier null,
		NewProspects int null,
		Visits int null,
		Phone int null,
		Email int null,
		Unqual int null,
		Rentals int null,
		Cancels int null,
		Denied int null)
		
	CREATE TABLE #OtherStats (
		NewRentals int null,
		CancelledRentals int null,
		DeniedRentals int null,
		NewNotices int null,
		CancelledNotices int null,
		Skips int null,
		Evictions int null)
		
	CREATE TABLE #Notices (
		LeaseID uniqueidentifier null,
		OnNoticeDate datetime null,
		CancelDate datetime null)
		
	CREATE TABLE #Sources (
		ProspectSourceID uniqueidentifier not null,
		ProspectSource nvarchar(100) not null)
		
	CREATE TABLE #Leasors (
		LeasingAgentID uniqueidentifier not null,
		Name nvarchar(50) not null)
		
	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier,
		StartDate date null,
		EndDate date null
	)


	INSERT #PropertyIDs
		SELECT pids.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pids
				LEFT JOIN PropertyAccountingPeriod pap ON pids.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID


	INSERT #Sources
		SELECT ps.ProspectSourceID, ps.Name
			FROM PropertyProspectSource pps
				INNER JOIN ProspectSource ps ON pps.ProspectSourceID = ps.ProspectSourceID
			WHERE PropertyID IN (SELECT Value FROM @propertyIDs)
		UNION
		SELECT '00000000-0000-0000-0000-000000000000', ''
	
	INSERT #Statistics
			SELECT	DISTINCT pn.PersonID, pn.PropertyID, null, pps.ProspectSourceID, 
			(CASE WHEN plapt.[Type] = 'Employee' THEN pla.PersonID
				  ELSE '00000000-0000-0000-0000-000000000000'
			 END), 			
			1, 0, 0, 0, 0, 0, 0, 0
				FROM PersonNote pn						
					INNER JOIN Prospect pros ON pn.PersonID = pros.PersonID					
					INNER JOIN PersonType ptype ON pros.PersonID = ptype.PersonID AND ptype.[Type] = 'Prospect'
					INNER JOIN PropertyProspectSource pps ON pros.PropertyProspectSourceID = pps.PropertyProspectSourceID AND pn.PropertyID = pps.PropertyID
					INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = pps.PropertyID AND #pids.PropertyID = pn.PropertyID								
					INNER JOIN Person pla ON pla.PersonID = pn.CreatedByPersonID
					INNER JOIN PersonType plapt ON plapt.PersonID = pla.PersonID AND plapt.[Type] IN ('Employee', 'Prospect')

				WHERE 
				  -- Happened between the dates
					pn.[Date] >= #pids.StartDate
				  AND pn.[Date] <= #pids.EndDate


				  AND pn.PersonType = 'Prospect'
				  AND pn.CreatedByPersonID IS NOT NULL
				  -- First note
				  AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
											FROM PersonNote pn2
												--INNER JOIN PersonType pt ON pt.PersonID = pn2.CreatedByPersonID AND pt.[Type] = 'Employee'
											WHERE pn2.PersonID = pn.PersonID
												AND pn2.PropertyID = pn.PropertyID
												AND pn2.CreatedByPersonID IS NOT NULL
											ORDER BY pn2.[Date], pn2.DateCreated)
		
	INSERT #Statistics
		SELECT	pn.PersonID, pn.PropertyID, null, pps.ProspectSourceID, 
			(CASE WHEN plapt.[Type] = 'Employee' THEN pla.PersonID
				  ELSE '00000000-0000-0000-0000-000000000000'
			END), 
			0, 
			CASE WHEN pn.ContactType = 'Face-to-Face' THEN 1 ELSE 0 END, 
			CASE WHEN pn.ContactType = 'Phone' THEN 1 ELSE 0 END, 
			CASE WHEN pn.ContactType = 'Email' THEN 1 ELSE 0 END, 
			0, 0, 0, 0
			FROM PersonNote pn
				INNER JOIN Prospect pros ON pn.PersonID = pros.PersonID
				INNER JOIN PersonType ptype ON pros.PersonID = ptype.PersonID AND ptype.[Type] = 'Prospect'				
				INNER JOIN PropertyProspectSource pps ON pros.PropertyProspectSourceID = pps.PropertyProspectSourceID AND pn.PropertyID = pps.PropertyID								
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = pps.PropertyID AND #pids.PropertyID = pn.PropertyID			
				INNER JOIN Person pla ON pla.PersonID = pn.CreatedByPersonID	
				INNER JOIN PersonType plapt ON plapt.PersonID = pla.PersonID AND plapt.[Type] IN ('Employee', 'Prospect')								

				
			WHERE pn.ContactType IN ('Face-to-Face', 'Phone', 'Email')
			  AND pn.[Date] >= #pids.StartDate
			  AND pn.[Date] <= #pids.EndDate
				
			  
-- Unqualified Lost Prospects
	INSERT #Statistics
		SELECT	pros.PersonID, pps.PropertyID, null, pps.ProspectSourceID, ptcb.PersonID, 0, 0, 0, 0, 1, 0, 0, 0
			FROM Prospect pros 
				INNER JOIN PersonType ptype ON pros.PersonID = ptype.PersonID AND ptype.[Type] = 'Prospect'
				LEFT JOIN PersonTypeProperty ptpcb ON pros.ResponsiblePersonTypePropertyID = ptpcb.PersonTypePropertyID 
				INNER JOIN PropertyProspectSource pps ON pros.PropertyProspectSourceID = pps.PropertyProspectSourceID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = pps.PropertyID				

				INNER JOIN PersonType ptcb ON ptpcb.PersonTypeID = ptcb.PersonTypeID AND ptcb.[Type] = 'Employee'						
			WHERE pros.LostDate >= #pids.StartDate
			  AND pros.LostDate <= #pids.EndDate 
			  AND pros.Unqualified = 1
			  
	CREATE TABLE #NewLeases (
		PropertyID uniqueidentifier not null,
		LeaseID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		LeaseStatus nvarchar(50) null,
		LeasingAgentPersonID uniqueidentifier null,
		ProspectID uniqueidentifier null,
		ProspectSourceID uniqueidentifier null)		

	INSERT #NewLeases
		SELECT b.PropertyID,
			   l.LeaseID,
			   ulg.UnitID,  
			   l.LeaseStatus,
			   l.LeasingAgentPersonID,
			   null, -- ProspectID
			   null -- PropertyProspectSourceID		
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN #PropertyIDs #pids on #pids.PropertyID = b.PropertyID				
			WHERE 		
				-- Make sure we only take into account the first lease in a given unit lease group
				l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)				
				-- Ensure we only get leases that actually applied during the date range
				AND #pids.StartDate <= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)
				AND #pids.EndDate >= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)  			  			  			  
				-- Make sure we don't take into account transferred residents
				AND ulg.PreviousUnitLeaseGroupID IS NULL							  
		  		
		-- Delete cancelled leases where they were auto cancelled
		DELETE #nl
		FROM #NewLeases #nl
			INNER JOIN PersonLease pl ON pl.LeaseID = #nl.LeaseID
			INNER JOIN Property p ON p.PropertyID = #nl.PropertyID
			INNER JOIN PickListItem pli ON pli.PickListItemID = p.DefaultCancelApplicationReasonForLeavingPickListItemID
		WHERE #nl.LeaseStatus = 'Cancelled'
			AND pl.ReasonForLeaving = pli.Name						

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
			
	INSERT #Statistics
		SELECT #nl.LeaseID, #nl.PropertyID, null, 
				#nl.ProspectSourceID,
				#nl.LeasingAgentPersonID, 0, 0, 0, 0, 0, 1, 0, 0
		FROM #NewLeases #nl
	
			  			  
	INSERT #OtherStats 
		SELECT ISNULL(SUM(Rentals), 0), 0, 0, 0, 0, 0, 0
			FROM #Statistics

	CREATE TABLE #CancelledAndDeniedLeases
	(
		PropertyID uniqueidentifier,
		LeaseID uniqueidentifier,
		LeaseStatus nvarchar(100),
		LeasingAgentPersonID uniqueidentifier,
		ProspectID uniqueidentifier,
		ProspectSourceID uniqueidentifier
	)
	
	INSERT #CancelledAndDeniedLeases 
		SELECT	b.PropertyID,
				l.LeaseID AS 'LeaseID', 
				l.LeaseStatus,			
				l.LeasingAgentPersonID,	
				null,
				null
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID		
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN #PropertyIDs #pids on #pids.PropertyID = b.PropertyID		
			WHERE 
				-- Make sure we only take into account the first lease in a given unit lease group
				l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)
				AND l.LeaseStatus IN ('Cancelled', 'Denied')
				-- Ensure we only get leases that actually applied during the date range
				AND #pids.StartDate <= (SELECT MIN(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)
				AND #pids.EndDate >= (SELECT MIN(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)  
				-- Make sure we don't take into account transferred residents
				AND ulg.PreviousUnitLeaseGroupID IS NULL

	-- Delete cancelled leases where they were auto cancelled
	DELETE #cdl
	FROM #CancelledAndDeniedLeases #cdl
		INNER JOIN PersonLease pl ON pl.LeaseID = #cdl.LeaseID
		INNER JOIN Property p ON p.PropertyID = #cdl.PropertyID
		INNER JOIN PickListItem pli ON pli.PickListItemID = p.DefaultCancelApplicationReasonForLeavingPickListItemID
	WHERE #cdl.LeaseStatus = 'Cancelled'
		AND pl.ReasonForLeaving = pli.Name

	-- Update prospect id for main prospects
		UPDATE #CancelledAndDeniedLeases SET ProspectID = (SELECT TOP 1 pr.ProspectID 
												 FROM Prospect pr													  
													  INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													  INNER JOIN PersonLease pl ON pl.LeaseID = #CancelledAndDeniedLeases.LeaseID AND pr.PersonID = pl.PersonID
												 WHERE pps.PropertyID = #CancelledAndDeniedLeases.PropertyID)
													   	
													 
		-- Update prospect id for roommates											 
		UPDATE #CancelledAndDeniedLeases SET ProspectID = (SELECT TOP 1 pr.ProspectID 
												FROM Prospect pr	
													INNER JOIN ProspectRoommate proroom ON pr.ProspectID = proroom.ProspectID												 
													INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													INNER JOIN PersonLease pl ON pl.LeaseID = #CancelledAndDeniedLeases.LeaseID AND proroom.PersonID = pl.PersonID
												WHERE pps.PropertyID = #CancelledAndDeniedLeases.PropertyID)
		WHERE #CancelledAndDeniedLeases.ProspectID IS NULL

	UPDATE #CancelledAndDeniedLeases SET ProspectSourceID = (SELECT TOP 1 pps.ProspectSourceID 
													FROM Prospect p
													INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = p.PropertyProspectSourceID
													WHERE p.ProspectID = #CancelledAndDeniedLeases.ProspectID)

	UPDATE #CancelledAndDeniedLeases SET ProspectSourceID =  '00000000-0000-0000-0000-000000000000' WHERE ProspectSourceID IS NULL


	INSERT #Statistics
		SELECT #cdl.LeaseID, #cdl.PropertyID, null, 
				#cdl.ProspectSourceID,
				#cdl.LeasingAgentPersonID, 0, 0, 0, 0, 0, 0, 1, 0
		FROM #CancelledAndDeniedLeases #cdl
		WHERE #cdl.LeaseStatus = 'Cancelled'

	INSERT #Statistics
		SELECT #cdl.LeaseID, #cdl.PropertyID, null, 
				#cdl.ProspectSourceID,
				#cdl.LeasingAgentPersonID, 0, 0, 0, 0, 0, 0, 0, 1
		FROM #CancelledAndDeniedLeases #cdl
		WHERE #cdl.LeaseStatus = 'Denied'
										
	UPDATE #OtherStats SET CancelledRentals = ISNULL((SELECT SUM(ISNULL(Cancels, 0))
												   FROM #Statistics), 0)
												   
	UPDATE #OtherStats SET DeniedRentals = ISNULL((SELECT SUM(ISNULL(Denied, 0))
												FROM #Statistics), 0)
												
	UPDATE #OtherStats SET Skips = (SELECT COUNT(l.LeaseID)
										FROM Lease l
											INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
											INNER JOIN Unit u ON u.UnitID = ulg.UnitID
											INNER JOIN Building b ON b.BuildingID = u.BuildingID
											INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = b.PropertyID

											LEFT JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																														   FROM PersonLease 
																														   WHERE LeaseID = l.LeaseID
																														   ORDER BY MoveOutDate DESC)
											LEFT JOIN PersonLease plNTV ON l.LeaseID = plNTV.LeaseID AND plNTV.NoticeGivenDate IS NOT NULL
										WHERE l.LeaseStatus = 'Former'
										  AND plNTV.PersonLeaseID IS NULL
										  AND pl.MoveOutDate >= #pids.StartDate
										  AND pl.MoveOutDate <= #pids.EndDate)


	UPDATE #OtherStats SET NewNotices = (
		SELECT	COUNT(DISTINCT l.LeaseID)
			FROM UnitLeaseGroup ulg
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = b.PropertyID
				LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.NoticeGivenDate IS NULL AND plmo.ResidencyStatus IN ('Former', 'Current', 'Under Eviction', 'Evicted')		
				WHERE l.LeaseStatus IN ('Former', 'Current', 'Under Eviction', 'Evicted')
			  -- Ensure there are not residents on the lease
			  -- without a move out date
			  AND plmo.PersonLeaseID IS NULL			 
				  AND ((SELECT MAX(NoticeGivenDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Current', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) >= #pids.StartDate)
				  AND ((SELECT MAX(NoticeGivenDate) FROM PersonLease WHERE PersonLease.ResidencyStatus IN ('Former', 'Current', 'Under Eviction', 'Evicted') AND PersonLease.LeaseID = l.LeaseID) <= #pids.EndDate))
											

										  
	UPDATE #OtherStats SET Evictions = (SELECT COUNT(l.LeaseID)
											FROM Lease l
												INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
												INNER JOIN Unit u ON u.UnitID = ulg.UnitID
												INNER JOIN Building b ON b.BuildingID = u.BuildingID
												INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = b.PropertyID

												INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
																																FROM PersonLease
																																WHERE LeaseID = l.LeaseID
																																ORDER BY MoveOutDate DESC)
											WHERE l.LeaseStatus = 'Evicted'
											  AND pl.MoveOutDate >= #pids.StartDate
											  AND pl.MoveOutDate <= #pids.EndDate)



	UPDATE #Statistics SET ProspectSourceID = '00000000-0000-0000-0000-000000000000' WHERE ProspectSourceID IS NULL											
			  
	SELECT #stats.PropertyID, #s.ProspectSource, ISNULL(SUM(#stats.NewProspects), 0) AS 'Prospects', ISNULL(SUM(#stats.Visits), 0) AS 'Visits', ISNULL(SUM(#stats.Phone), 0) AS 'Phone',
			ISNULL(SUM(#stats.Email), 0) AS 'Email', ISNULL(SUM(#stats.Rentals), 0) AS 'Rentals', ISNULL(SUM(#stats.Cancels), 0) AS 'Cancels', 
			ISNULL(SUM(#stats.Denied), 0) AS 'Denied'
		FROM #Sources #s
			LEFT JOIN #Statistics #stats ON #s.ProspectSourceID = #stats.ProspectSourceID
			--LEFT JOIN PropertyProspectSource pps ON #stats.PropertyProspectSourceID = pps.PropertyProspectSourceID
			LEFT JOIN ProspectSource ps ON #stats.ProspectSourceID = ps.ProspectSourceID
		GROUP BY #stats.PropertyID, #s.ProspectSource
		HAVING ISNULL(SUM(#stats.NewProspects), 0) <> 0
		    OR ISNULL(SUM(#stats.Visits), 0) <> 0
		    OR ISNULL(SUM(#stats.Phone), 0) <> 0
		    OR ISNULL(SUM(#stats.Email), 0) <> 0
		    OR ISNULL(SUM(#stats.Rentals), 0) <> 0
		    OR ISNULL(SUM(#stats.Cancels), 0) <> 0
		    OR ISNULL(SUM(#stats.Denied), 0) <> 0
		ORDER BY #s.ProspectSource
		
	INSERT #Leasors 
		SELECT DISTINCT PersonID, PreferredName + ' ' + LastName
			FROM Person
			WHERE PersonID IN (SELECT DISTINCT LeasingAgentID FROM #Statistics)	

	INSERT #Leasors VALUES ('00000000-0000-0000-0000-000000000000', 'Outside Source')
		
		
	SELECT #l.Name, ISNULL(SUM(#stats.NewProspects), 0) AS 'Prospects', ISNULL(SUM(#stats.Visits), 0) AS 'Visits', ISNULL(SUM(#stats.Phone), 0) AS 'Phone',
			ISNULL(SUM(#stats.Email), 0) AS 'Email', ISNULL(SUM(#stats.Rentals), 0) AS 'Rentals', ISNULL(SUM(#stats.Cancels), 0) AS 'Cancels', 
			ISNULL(SUM(#stats.Denied), 0) AS 'Denied'
		FROM #Leasors #l
			LEFT JOIN #Statistics #stats ON #stats.LeasingAgentID = #l.LeasingAgentID	
		GROUP BY #l.Name
		HAVING ISNULL(SUM(#stats.NewProspects), 0) <> 0
		    OR ISNULL(SUM(#stats.Visits), 0) <> 0
		    OR ISNULL(SUM(#stats.Phone), 0) <> 0
		    OR ISNULL(SUM(#stats.Email), 0) <> 0
		    OR ISNULL(SUM(#stats.Rentals), 0) <> 0
		    OR ISNULL(SUM(#stats.Cancels), 0) <> 0
		    OR ISNULL(SUM(#stats.Denied), 0) <> 0		
		ORDER BY #l.Name
		
	SELECT * FROM #OtherStats
END





GO
