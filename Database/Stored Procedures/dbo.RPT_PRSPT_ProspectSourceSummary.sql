SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Phillip Lundquist
-- Create date: April 31, 2012
-- Description:	Generates the data for the Prospect Summary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRSPT_ProspectSourceSummary]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs
	
	CREATE TABLE #SourceSummary (
		PropertyID uniqueidentifier,
		PropertyName nvarchar(500),
		PropertyProspectSourceID uniqueidentifier,
		[Source] nvarchar(500),
		NewCount int,
		ReturnCount int,
		NewUnitsShown int,
		NewLeases int,
		LeasedUponReturn int,
		LeasesCancelled int,
		CostPerYear money)
		
			
	INSERT INTO #SourceSummary
		SELECT  DISTINCT
			pro.PropertyID,
			pro.Name AS 'PropertyName',
			pps.PropertyProspectSourceID, 
			ps.Name AS 'Source',		
			0,
			0,
			0,
			0,
			0,		
			0,
			pps.CostPerYear
		FROM 
			ProspectSource ps
			--Prospect p
			--INNER JOIN PersonNote pn ON pn.PersonID = p.PersonID
			INNER JOIN PropertyProspectSource pps ON pps.ProspectSourceID = ps.ProspectSourceID
			--INNER JOIN ProspectSource ps ON ps.ProspectSourceID = pps.ProspectSourceID
			INNER JOIN Property pro ON pro.PropertyID = pps.PropertyID	
			INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = pro.PropertyID 
		--WHERE		
			--pps.PropertyID IN (SELECT Value FROM @propertyIDs)		
			--AND pn.PropertyID IN (SELECT Value FROM @propertyIDs)
			-- pn.[Date] >= @startDate
			--AND pn.[Date] <= @endDate
			--AND pn.[PersonType] = 'Prospect'			
		
	INSERT INTO #SourceSummary
		SELECT 
			pro.PropertyID,
			pro.Name,
			'00000000-0000-0000-0000-000000000000',
			'None',
			0,
			0,
			0,
			0,
			0,		
			0,
			0
		FROM Property pro
			INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = pro.PropertyID

			
	UPDATE #SourceSummary SET NewCount = (SELECT COUNT(DISTINCT p.ProspectID)
										  FROM PersonNote pn				
											INNER JOIN Prospect p ON pn.PersonID = p.PersonID																		
											INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = p.PropertyProspectSourceID
											LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID											
										  WHERE pn.PersonType = 'Prospect'	
										    AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
										      OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))
											AND pn.PropertyID = #SourceSummary.PropertyID
											-- Get the first Prospect note
											AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
																	 FROM PersonNote pn2 																	   
																	 WHERE pn2.PersonID = pn.PersonID
																	       AND pn2.PropertyID = #SourceSummary.PropertyID
																		   AND pn2.PersonType = 'Prospect'
																		   -- Get actual interactions or transfer notes
																		   AND pn2.ContactType <> 'N/A' -- ADD pn2.InteractionType = 'Transfer' to include transfers-- Do not include notes that were not contacts
																	 ORDER BY [Date], [DateCreated])											
											AND pps.PropertyProspectSourceID = #SourceSummary.PropertyProspectSourceID)
											
	UPDATE #SourceSummary SET ReturnCount = (SELECT COUNT(DISTINCT p.ProspectID)
											  FROM PersonNote pn				
											    INNER JOIN Prospect p ON pn.PersonID = p.PersonID																		
												INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = p.PropertyProspectSourceID	
												LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID											
											  WHERE pn.PersonType = 'Prospect'												
												AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
												  OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))
												AND pn.ContactType <> 'N/A'
												AND pn.PropertyID = #SourceSummary.PropertyID
												-- Get the first Prospect note
												AND pn.PersonNoteID <> (SELECT TOP 1 pn2.PersonNoteID 
																		 FROM PersonNote pn2 																			
																		 WHERE pn2.PersonID = pn.PersonID
																			   AND pn2.PropertyID = #SourceSummary.PropertyID
																			   AND pn2.PersonType = 'Prospect'
																			   AND pn2.ContactType <> 'N/A' -- Do not include notes that were not contacts
																		 ORDER BY [Date], [DateCreated])											
												AND pps.PropertyProspectSourceID = #SourceSummary.PropertyProspectSourceID)											
												
		
	UPDATE #SourceSummary SET NewUnitsShown = (SELECT COUNT(DISTINCT pn.PersonID)
														FROM PersonNote pn
															INNER JOIN Prospect p ON pn.PersonID = p.PersonID		
															INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = p.PropertyProspectSourceID	
															LEFT JOIN PropertyAccountingPeriod pap ON pn.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID	
														WHERE p.PropertyProspectSourceID = #SourceSummary.PropertyProspectSourceID															  
														  AND pn.PersonType = 'Prospect'
														  AND (((@accountingPeriodID IS NULL) AND (pn.[Date] >= @startDate) AND (pn.[Date] <= @endDate))
														    OR ((@accountingPeriodID IS NOT NULL) AND (pn.[Date] >= pap.StartDate) AND (pn.[Date] <= pap.EndDate)))
														  AND pn.ContactType <> 'N/A' -- Do not include notes that were not contacts
														  AND pn.InteractionType IN ('Unit Shown', 'Application')
														  AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
																				 FROM PersonNote pn2 																					
																				 WHERE pn2.PersonID = pn.PersonID 																						   
																				       AND pn2.PropertyID = #SourceSummary.PropertyID
																					   AND pn2.PersonType = 'Prospect'
																					   AND pn2.InteractionType IN ('Unit Shown', 'Application')
																				 ORDER BY [Date], DateCreated))		

	CREATE TABLE #NewLeasesRick (
		PropertyID uniqueidentifier not null,
		LeaseID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		ApplicationDate date null,
		LeaseStatus nvarchar(50) null,
		LeasingAgentPersonID uniqueidentifier null,
		ProspectID uniqueidentifier null,
		PropertyProspectSourceID uniqueidentifier null,
		UnitShownDate date null)		
									
		  
	INSERT #NewLeasesRick
		SELECT b.PropertyID,
			   l.LeaseID,
			   ulg.UnitID,  
			   (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID) AS 'ApplicationDate',
			   l.LeaseStatus,
			   l.LeasingAgentPersonID,
			   null, -- ProspectID
			   null, -- PropertyProspectSourceID
			   null  -- Unit Shown Date
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN #PropertyIDs #pids on #pids.PropertyID = b.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE 		
				-- Make sure we only take into account the first lease in a given unit lease group
				l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)				
				-- Ensure we only get leases that actually applied during the date range
				AND (((@accountingPeriodID IS NULL)	
					AND (@startDate <= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
					AND (@endDate >= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)))
				  OR ((@accountingPeriodID IS NOT NULL)	
					AND (pap.StartDate <= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
					AND (pap.EndDate >= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))))		  			  			  
				-- Make sure we don't take into account transferred residents
				AND ulg.PreviousUnitLeaseGroupID IS NULL					  
		  		
		-- Update prospect id for main prospects
		UPDATE #NewLeasesRick SET ProspectID = (SELECT TOP 1 pr.ProspectID 
												 FROM Prospect pr													  
													  INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													  INNER JOIN PersonLease pl ON pl.LeaseID = #NewLeasesRick.LeaseID AND pr.PersonID = pl.PersonID
												 WHERE pps.PropertyID = #NewLeasesRick.PropertyID)
													   	
													 
		-- Update prospect id for roommates											 
		UPDATE #NewLeasesRick SET ProspectID = (SELECT TOP 1 pr.ProspectID 
												FROM Prospect pr	
													INNER JOIN ProspectRoommate proroom ON pr.ProspectID = proroom.ProspectID												 
													INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													INNER JOIN PersonLease pl ON pl.LeaseID = #NewLeasesRick.LeaseID AND proroom.PersonID = pl.PersonID
												WHERE pps.PropertyID = #NewLeasesRick.PropertyID)
		WHERE #NewLeasesRick.ProspectID IS NULL


		UPDATE #NewLeasesRick SET UnitShownDate = (SELECT TOP 1 pn.[Date] 
													FROM PersonNote pn
														INNER JOIN Prospect pro ON pro.PersonID = pn.PersonID AND pro.ProspectID = #NewLeasesRick.ProspectID																																														
													WHERE 
														pn.PersonType = 'Prospect'											   
														AND pn.InteractionType IN ('Unit Shown', 'Application')
														AND pn.PropertyID = #NewLeasesRick.PropertyID
													ORDER BY [Date], DateCreated)				  						

		UPDATE #NewLeasesRick SET UnitShownDate = ApplicationDate WHERE UnitShownDate IS NULL

		UPDATE #NewLeasesRick SET PropertyProspectSourceID = (SELECT TOP 1 PropertyProspectSourceID FROM Prospect WHERE Prospect.ProspectID = #NewLeasesRick.ProspectID)
		UPDATE #NewLeasesRick SET PropertyProspectSourceID =  '00000000-0000-0000-0000-000000000000' WHERE PropertyProspectSourceID IS NULL
							
	UPDATE #SourceSummary SET NewLeases = (SELECT COUNT (DISTINCT LeaseID) 
											FROM #NewLeasesRick
											WHERE #NewLeasesRick.PropertyProspectSourceID = #SourceSummary.PropertyProspectSourceID
												AND #NewLeasesRick.UnitShownDate >= @startDate
												AND #SourceSummary.PropertyID = #NewLeasesRick.PropertyID)
											
	UPDATE #SourceSummary SET LeasedUponReturn = (SELECT COUNT (DISTINCT LeaseID) 
													FROM #NewLeasesRick
													WHERE #NewLeasesRick.PropertyProspectSourceID = #SourceSummary.PropertyProspectSourceID
														AND #NewLeasesRick.UnitShownDate < @startDate
														AND #SourceSummary.PropertyID = #NewLeasesRick.PropertyID)
														


	CREATE TABLE #CancelledLeases
	(
		PropertyID uniqueidentifier,
		LeaseID uniqueidentifier,
		ProspectID uniqueidentifier,
		PropertyProspectSourceID uniqueidentifier
	)
	
	INSERT #CancelledLeases 
		SELECT	b.PropertyID,
				l.LeaseID AS 'LeaseID', 				
				null,
				null
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID		
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN #PropertyIDs #pids on #pids.PropertyID = b.PropertyID	
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID	
			WHERE 
				-- Make sure we only take into account the first lease in a given unit lease group
				l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)
				AND l.LeaseStatus IN ('Cancelled', 'Denied')
				-- Ensure we only get leases that actually applied during the date range
				AND (((@accountingPeriodID IS NULL)
					AND (@startDate <= (SELECT MIN(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
					AND (@endDate >= (SELECT MIN(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)))
				  OR ((@accountingPeriodID IS NOT NULL)
					AND (pap.StartDate <= (SELECT MIN(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
					AND (pap.EndDate >= (SELECT MIN(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))))
				-- Make sure we don't take into account transferred residents
				AND ulg.PreviousUnitLeaseGroupID IS NULL

	-- Update prospect id for main prospects
		UPDATE #CancelledLeases SET ProspectID = (SELECT TOP 1 pr.ProspectID 
												 FROM Prospect pr													  
													  INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													  INNER JOIN PersonLease pl ON pl.LeaseID = #CancelledLeases.LeaseID AND pr.PersonID = pl.PersonID
												 WHERE pps.PropertyID = #CancelledLeases.PropertyID)
													   	
													 
		-- Update prospect id for roommates											 
		UPDATE #CancelledLeases SET ProspectID = (SELECT TOP 1 pr.ProspectID 
												FROM Prospect pr	
													INNER JOIN ProspectRoommate proroom ON pr.ProspectID = proroom.ProspectID												 
													INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													INNER JOIN PersonLease pl ON pl.LeaseID = #CancelledLeases.LeaseID AND proroom.PersonID = pl.PersonID
												WHERE pps.PropertyID = #CancelledLeases.PropertyID)
		WHERE #CancelledLeases.ProspectID IS NULL

	UPDATE #CancelledLeases SET PropertyProspectSourceID = (SELECT TOP 1 PropertyProspectSourceID
															FROM Prospect
															WHERE Prospect.ProspectID = #CancelledLeases.ProspectID)

	UPDATE #CancelledLeases SET PropertyProspectSourceID =  '00000000-0000-0000-0000-000000000000' WHERE PropertyProspectSourceID IS NULL
		

	UPDATE #SourceSummary SET LeasesCancelled = (SELECT COUNT (DISTINCT LeaseID) 
												FROM #CancelledLeases
												WHERE #CancelledLeases.PropertyProspectSourceID = #SourceSummary.PropertyProspectSourceID
													AND #CancelledLeases.PropertyID = #SourceSummary.PropertyID)														
	

	SELECT * 
	FROM #SourceSummary
	WHERE
		(NewCount <> 0 
		 OR ReturnCount <> 0
		 OR NewUnitsShown <> 0
		 OR NewLeases <> 0
		 OR LeasedUponReturn <> 0
		 OR LeasesCancelled <> 0
		 OR CostPerYear <> 0) 
	ORDER BY Source
		
END




GO
