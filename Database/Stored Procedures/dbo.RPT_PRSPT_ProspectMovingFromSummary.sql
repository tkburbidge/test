SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Phillip Lundquist
-- Create date: April 31, 2012
-- Description:	Generates the data for the Prospect Summary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRSPT_ProspectMovingFromSummary]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startDate date = null,
	@endDate date = null,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN

	CREATE TABLE #PropertyIDs (PropertyID uniqueidentifier)
	INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SELECT  
		p.MovingFrom AS 'MovingFrom', p.MaxRent AS 'MaxRent',
		pro.Name AS 'PropertyName',
		ps.Name AS 'Source',		
		ps.ProspectSourceID, 
		-- Get all PersonIDs for the Prospect Group				 
		-- If the main prospect or one of the roommates
		-- leased and didn't cancel, consider this prospect leased
		CASE WHEN (SELECT COUNT(*) 
					 FROM PersonLease pl
						INNER JOIN Lease l on pl.LeaseID = l.LeaseID
						INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
						INNER JOIN Unit u ON u.UnitID = ulg.UnitID
						INNER JOIN Building b ON b.BuildingID = u.BuildingID
						INNER JOIN #PropertyIDs #pids on #pids.PropertyID = b.PropertyID		
					 WHERE pl.PersonID IN  (SELECT PersonID 
											FROM ((SELECT PersonID 
												   FROM ProspectRoommate pr
												   WHERE pr.ProspectID = p.ProspectID)
												   UNION
												  (SELECT PersonID 
												   FROM Prospect
												   WHERE Prospect.ProspectID = p.ProspectID)) AS PersonIDs)
					AND l.LeaseStatus NOT IN ('Cancelled', 'Denied')) > 0 THEN CAST(1 AS bit)
			ELSE CAST(0 as bit)
		END AS 'Leased'		
		FROM Prospect p
		INNER JOIN PersonNote pn ON pn.PersonID = p.PersonID
		INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = p.PropertyProspectSourceID
		INNER JOIN ProspectSource ps ON ps.ProspectSourceID = pps.ProspectSourceID
		INNER JOIN Property pro ON pro.PropertyID = pps.PropertyID
		WHERE		
		pps.PropertyID IN (SELECT Value FROM @propertyIDs)
		AND pn.PersonNoteID = (SELECT TOP 1 PersonNoteID 
							   FROM PersonNote pn								
							   WHERE 
							   pn.PersonID = p.PersonID
							   AND pn.PropertyID = pps.PropertyID
							   AND PersonType = 'Prospect'
							   AND pn.ContactType <> 'N/A' -- Remove to include transferrred
							   ORDER BY [Date])
		AND pn.[Date] >= @startDate
		AND pn.[Date] <= @endDate
END



GO
