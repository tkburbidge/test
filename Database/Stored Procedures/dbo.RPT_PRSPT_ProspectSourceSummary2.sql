SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Phillip Lundquist
-- Create date: April 31, 2012
-- Description:	Generates the data for the Prospect Summary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRSPT_ProspectSourceSummary2]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	
	CREATE TABLE #SourceSummary (
		PropertyID uniqueidentifier,
		PropertyName nvarchar(500),
		PropertyProspectSourceID uniqueidentifier,
		[Source] nvarchar(500),
		NewCount int,
		ReturnCount int,
		Leases int,
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
			pps.CostPerYear
			FROM Prospect p
			INNER JOIN PersonNote pn ON pn.PersonID = p.PersonID
			INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = p.PropertyProspectSourceID
			INNER JOIN ProspectSource ps ON ps.ProspectSourceID = pps.ProspectSourceID
			INNER JOIN Property pro ON pro.PropertyID = pps.PropertyID
			WHERE		
			pps.PropertyID IN (SELECT Value FROM @propertyIDs)		
			AND pn.[Date] >= @startDate
			AND pn.[Date] <= @endDate
			AND pn.[PersonType] = 'Prospect'
		
		
	UPDATE #SourceSummary SET NewCount = (SELECT COUNT(*)
										  FROM PersonNote pn				
											INNER JOIN Prospect p ON pn.PersonID = p.PersonID																		
											INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = p.PropertyProspectSourceID
										  WHERE pn.PersonType = 'Prospect'												
											AND pn.[Date] >= @startDate
											AND pn.[Date] <= @endDate
											-- Get the first Prospect note
											AND pn.PersonNoteID = (SELECT TOP 1 pn2.PersonNoteID 
																	 FROM PersonNote pn2 
																	 WHERE pn2.PersonID = pn.PersonID
																		   AND pn2.PersonType = 'Prospect'
																	 ORDER BY [Date])											
											AND pps.PropertyProspectSourceID = #SourceSummary.PropertyProspectSourceID)
											
	UPDATE #SourceSummary SET ReturnCount = (SELECT COUNT(*)
											  FROM PersonNote pn				
											    INNER JOIN Prospect p ON pn.PersonID = p.PersonID																		
												INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = p.PropertyProspectSourceID
											  WHERE pn.PersonType = 'Prospect'												
												AND pn.[Date] >= @startDate
												AND pn.[Date] <= @endDate
												-- Get the first Prospect note
												AND pn.PersonNoteID <> (SELECT TOP 1 pn2.PersonNoteID 
																		 FROM PersonNote pn2 
																		 WHERE pn2.PersonID = pn.PersonID
																			   AND pn2.PersonType = 'Prospect'
																		 ORDER BY [Date])											
												AND pps.PropertyProspectSourceID = #SourceSummary.PropertyProspectSourceID)											
												
		
		
	CREATE TABLE #NewLeases (
		LeaseID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		ResponsiblePersonID uniqueidentifier not null,
		ProspectID uniqueidentifier not null,
		MainPersonID uniqueidentifier not null,
		RoomieID uniqueidentifier not null,
		LeaseStatus nvarchar(100) not null,
		PropertyProspectSourceID uniqueidentifier
		)

	INSERT #NewLeases 
		SELECT	l.LeaseID AS 'LeaseID', ulg.UnitID AS 'UnitID', ppt.ResponsiblePersonTypePropertyID AS 'ResponsiblePersonID',
				ppt.ProspectID AS 'ProspectID', ppt.PersonID AS 'MainPersonID', ppt.PersonID AS 'RoomieID', l.LeaseStatus, ppt.PropertyProspectSourceID
			FROM Lease l
				INNER JOIN PersonLease pl on l.LeaseID = pl.LeaseID
				INNER JOIN Person p ON pl.PersonID = p.PersonID
				INNER JOIN Prospect ppt	ON p.PersonID = ppt.PersonID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID			
			WHERE 
			 l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)
			  AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID FROM PersonLease WHERE PersonLease.LeaseID = l.LeaseID ORDER BY ApplicationDate)
			  AND pl.ApplicationDate >= @startDate
			  AND pl.ApplicationDate <= @endDate
			  -- Ensure we only get leases that actually applied during the date range
			  --AND (SELECT MIN(ApplicationDate) FROM PersonLease WHERE PersonLease.LeaseID = l.LeaseID) >= @startDate
			  --AND (SELECT MIN(ApplicationDate) FROM PersonLease WHERE PersonLease.LeaseID = l.LeaseID) <= @endDate
			  -- Make sure we only take into account the first lease in a given unit lease group
			  
			  -- Make sure we don't take into account transferred residents
			  AND ulg.PreviousUnitLeaseGroupID IS NULL
			  
			  
	INSERT #NewLeases 
		SELECT	l.LeaseID AS 'LeaseID', ulg.UnitID AS 'UnitID', ppt.ResponsiblePersonTypePropertyID AS 'ResponsiblePersonID',
				ppt.ProspectID AS 'ProspectID', ppt.PersonID AS 'MainPersonID', proom.PersonID AS 'RoomieID', l.LeaseStatus, ppt.PropertyProspectSourceID
			FROM Lease l
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
				INNER JOIN Person p ON pl.PersonID = p.PersonID
				INNER JOIN ProspectRoommate proom ON p.PersonID = proom.PersonID
				INNER JOIN Prospect ppt ON proom.ProspectID = ppt.ProspectID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			WHERE 
			  -- Make sure we only take into account the first lease in a given unit lease group
			  pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID FROM PersonLease WHERE PersonLease.LeaseID = l.LeaseID ORDER BY ApplicationDate)
			  AND l.LeaseID = (SELECT TOP 1 LeaseID FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID ORDER BY LeaseStartDate)
			  AND pl.ApplicationDate >= @startDate
			  AND pl.ApplicationDate <= @endDate	
			  
			  -- Ensure we only get leases that actually applied during the date range
			  --AND (SELECT MIN(ApplicationDate) FROM PersonLease WHERE PersonLease.LeaseID = l.LeaseID) >= @startDate
			  --AND (SELECT MIN(ApplicationDate) FROM PersonLease WHERE PersonLease.LeaseID = l.LeaseID) <= @endDate
			  
			  -- Make sure we don't take into account transferred residents
			  AND ulg.PreviousUnitLeaseGroupID IS NULL			  		
	
	UPDATE #SourceSummary SET Leases = (SELECT COUNT (DISTINCT LeaseID) 
										FROM #NewLeases
										WHERE PropertyProspectSourceID = #SourceSummary.PropertyProspectSourceID)
					
	
	UPDATE #SourceSummary SET LeasesCancelled = (SELECT COUNT (DISTINCT LeaseID) 
													FROM #NewLeases
													WHERE PropertyProspectSourceID = #SourceSummary.PropertyProspectSourceID
														AND LeaseStatus = 'Cancelled')
		
		
	select * from #SourceSummary
		
END
GO
