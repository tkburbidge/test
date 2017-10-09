SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
				 
  

																														 
				 
  

						
  




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 28, 2012
-- Description:	Lists the Lease Applications by Salesperson
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_LeaseApplicationsByEmployee] 
	-- Add the parameters for the stored procedure here
	@startDate datetime = null, 
	@endDate datetime = null,
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	  CREATE TABLE #Applicants (
		PersonID uniqueidentifier null,
		ProspectID uniqueidentifier null,
		LeasingAgent nvarchar(500),
		Unit nvarchar(50),
		PaddedUnit nvarchar(50),
		PropertyID uniqueidentifier,
		PropertyName nvarchar(500),
		Resident nvarchar(500),
		LeaseID uniqueidentifier,
		LeaseStatus nvarchar(25),
		LeaseStartDate date,
		LeaseEndDate date,
		ApplicationDate date,
		MoveInDate date,
		ApprovalStatus nvarchar(25),
		ApproverName nvarchar(500),
		ApprovalNotes nvarchar(4000),
		MarketRent money null,
		LastMoveOutDate date null,
		DaysVacant int null,
		UnitLeaseGroupID uniqueidentifier null,
		UnitID uniqueidentifier null
	  )

	INSERT INTO #Applicants
	SELECT DISTINCT 
			p.PersonID,
			null,
			lap.PreferredName + ' ' + lap.LastName AS 'LeasingAgent',
			u.Number AS 'Unit', 
			u.PaddedNumber,
			b.PropertyID,
			pro.Name,
			p.PreferredName + ' ' + p.LastName AS 'Resident',
			l.LeaseID AS 'LeaseID',
			l.LeaseStatus AS 'LeaseStatus', 
			l.LeaseStartDate AS 'LeaseStartDate', 
			l.LeaseEndDate AS 'LeaseEndDate',
			pl.ApplicationDate AS 'ApplicationDate', 
			pl.MoveInDate AS 'MoveInDate',
			pn.InteractionType,
			pad.PreferredName + ' ' + pad.LastName AS 'ApproverName', 
			pn.Note AS 'ApprovedNotes',
			null AS 'MarketRent',
			null AS 'LastMoveOutDate',
			null AS 'DaysVacant',
			ulg.UnitLeaseGroupID,
			u.UnitID
		FROM Lease l
			INNER JOIN PersonLease pl on l.LeaseID = pl.LeaseID
			INNER JOIN Person p ON pl.PersonID = p.PersonID
			INNER JOIN UnitLeaseGroup ulg on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID 
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID				
			INNER JOIN Property pro ON b.PropertyID = pro.PropertyID
			INNER JOIN Person lap ON l.LeasingAgentPersonID = lap.PersonID
			
			-- Approve/Deny Person								
			LEFT JOIN PersonNote pn ON pl.PersonID = pn.PersonID AND pn.InteractionType IN ('Approved', 'Denied')
			--LEFT JOIN PersonTypeProperty ptpad ON  pn.CreatedByPersonTypePropertyID = ptpad.PersonTypePropertyID
			--LEFT JOIN PersonType ptad ON ptpad.PersonTypeID = ptad.PersonTypeID
			--LEFT JOIN Person pad ON ptad.PersonID = pad.PersonID
			LEFT JOIN Person pad ON pn.CreatedByPersonID = pad.PersonID		
			LEFT JOIN PropertyAccountingPeriod pap ON pro.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID	
		WHERE b.PropertyID IN (SELECT Value FROM @propertyIDs)
		  --AND pl.ApplicationDate >= @startDate
		  --AND pl.ApplicationDate <= @endDate	
		  AND (((@accountingPeriodID IS NULL) AND (pl.ApplicationDate >= @startDate) AND (pl.ApplicationDate <= @endDate))
		    OR ((@accountingPeriodID IS NOT NULL) AND (pl.ApplicationDate >= pap.StartDate) AND (pl.ApplicationDate <= pap.EndDate)))	  
		  AND pl.MainContact = 1
		  -- Ensure the first application occurred within the given date range
		  --AND @startDate <= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)
		  --AND @endDate >= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)
		  AND (((@accountingPeriodID IS NULL) 
			  AND (@startDate <= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
			  AND (@endDate >= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)))
			OR ((@accountingPeriodID IS NOT NULL)
			  AND (pap.StartDate <= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
			  AND (pap.EndDate >= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))))				  
		  AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
						   FROM Lease l2
						   WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
						   ORDER BY l2.LeaseStartDate)		  
		  -- Ensure we get the last approve or deny note
		  AND (pn.PersonNoteID IS NULL OR
			   pn.PersonNoteID = (SELECT TOP 1 pn.PersonNoteID	
							      FROM PersonNote pn
							      WHERE pn.PersonID = pl.PersonID
							 		    AND pn.InteractionType IN ('Approved', 'Denied')
								  ORDER BY pn.[Date] DESC, pn.DateCreated DESC))
	
		-- Update prospect id for main prospects
		UPDATE #Applicants SET ProspectID = (SELECT TOP 1 pr.ProspectID 
											 FROM Prospect pr													  
												  INNER JOIN PersonTypeProperty ptp ON pr.ResponsiblePersonTypePropertyID = ptp.PersonTypePropertyID
											 WHERE ptp.PropertyID = #Applicants.PropertyID
												   AND #Applicants.PersonID = pr.PersonID)	
													 
		-- Update prospect id for roommates											 
		UPDATE #Applicants SET ProspectID = (SELECT TOP 1 pr.ProspectID 
											  FROM Prospect pr	
												  INNER JOIN ProspectRoommate proroom ON pr.ProspectID = proroom.ProspectID												 
												  INNER JOIN PersonTypeProperty ptp ON pr.ResponsiblePersonTypePropertyID = ptp.PersonTypePropertyID
											 WHERE ptp.PropertyID = #Applicants.PropertyID
												   AND #Applicants.PersonID = proroom.PersonID)
		WHERE ProspectID IS NULL		
		
		
		-- Update the LeasingAgent name
		--UPDATE #Applicants SET LeasingAgent = (SELECT p.PreferredName + ' ' + p.LastName
		--									   FROM Prospect pr
		--											INNER JOIN PersonTypeProperty ptp ON pr.ResponsiblePersonTypePropertyID = ptp.PersonTypePropertyID
		--											INNER JOIN PersonType pt ON ptp.PersonTypeID = pt.PersonTypeID
		--											INNER JOIN Person p on pt.PersonID = p.PersonID
		--									   WHERE pr.ProspectID = #Applicants.ProspectID)

		UPDATE #a1
			SET #a1.LeasingAgent = #a2.LeasingAgent, #a1.ProspectID = #a2.ProspectID
			FROM #Applicants #a1
				INNER JOIN #Applicants #a2 ON #a1.LeaseID = #a2.LeaseID AND #a1.LeasingAgent IS NULL AND #a2.LeasingAgent IS NOT NULL

		UPDATE #app	SET MarketRent = [MarkRent].Amount
			FROM #Applicants #app 
				CROSS APPLY GetMarketRentByDate(#app.UnitID, #app.ApplicationDate, 1) [MarkRent]


	UPDATE #Applicants SET LastMoveOutDate = (SELECT TOP 1 MoveOutDate
													FROM
														(
															SELECT ulg.UnitLeaseGroupID, MAX(pl.MoveOutDate) AS MoveOutDate
															FROM UnitLeaseGroup ulg
															INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND LeaseStatus IN ('Former', 'Evicted')
															INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.ResidencyStatus IN ('Former', 'Evicted')
															WHERE ulg.UnitID = #Applicants.UnitID
															GROUP BY ulg.UnitLeaseGroupID
														) AS MoveOuts
													WHERE MoveOuts.MoveOutDate < #Applicants.ApplicationDate
													ORDER BY MoveOuts.MoveOutDate DESC)

	UPDATE #Applicants SET DaysVacant = DATEDIFF(DAY, LastMoveOutDate, MoveInDate)
		WHERE LastMoveOutDate IS NOT NULL
			AND MoveInDate IS NOT NULL
			
		SELECT LeasingAgent,
			   Unit,
			   Resident,
			   LeaseStatus,
			   LeaseStartDate,
			   LeaseEndDate,
			   ApplicationDate,
			   MoveInDate,
			   ApprovalStatus,
			   ApproverName,
			   ApprovalNotes,
			   PropertyName,
			   LeaseID,
			   MarketRent,
			   LastMoveOutDate,
			   DaysVacant
		 FROM #Applicants	
		 ORDER BY LeasingAgent, PaddedUnit, LeaseID, Resident	
END







GO
