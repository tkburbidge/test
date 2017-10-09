SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 6, 2012
-- Description:	Get Move In & Move Out data for the Dashboard
-- =============================================
CREATE PROCEDURE [dbo].[RPT_DSH_GetMoveInOuts] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT * 
	FROM 
		(SELECT	l.LeaseStatus AS 'LeaseStatus',
				p.Name AS 'PropertyName',
				'Move Out' AS 'Type',				
				l.LeaseID AS 'LeaseID',
				u.Number AS 'Unit',				
				(STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
								FROM Person 
									INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
									INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID								
								WHERE PersonLease.LeaseID = l.LeaseID
									AND PersonType.[Type] = 'Resident'				   
									AND PersonLease.MainContact = 1				   
								FOR XML PATH ('')), 1, 2, '')) AS 'Residents',					
				(SELECT MAX(MoveOutDate) FROM PersonLease WHERE LeaseID = l.LeaseID) AS 'MoveDate',
				ut.Name AS 'UnitType',
				(SELECT TOP 1 LeaseID 
					FROM Lease pl
					INNER JOIN UnitLeaseGroup pulg ON pulg.UnitLeaseGroupID = pl.UnitLeaseGroupID
					WHERE pulg.UnitID = u.UnitID AND
						pl.LeaseStatus IN ('Pending', 'Pending Transfer')) AS 'PendingLeaseID',--pl.LeaseID AS 'PendingLeaseID'
				p.CalendarColor AS 'Color'
			FROM Unit u
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON b.PropertyID = p.PropertyID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')
				LEFT JOIN PersonLease plmo ON l.LeaseID = plmo.LeaseID AND plmo.MoveOutDate IS NULL			
				--LEFT JOIN UnitLeaseGroup pulg ON pulg.UnitID = u.UnitID
				--LEFT JOIN Lease pl ON pl.UnitLeaseGroupID = pulg.UnitLeaseGroupID AND pl.LeaseStatus IN ('Pending', 'Pending Transfer')
			WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)		  		  
			  AND plmo.PersonLeaseID IS NULL		  
			  AND u.IsHoldingUnit = 0
			  AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
										
			UNION
			
			SELECT	L.LeaseStatus AS 'LeaseStatus',
					p.Name AS 'PropertyName',
					'Move In' AS 'Type',
					l.LeaseID AS 'LeaseID',
					u.Number AS 'Unit',
					(STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
								 FROM Person 
									 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
									 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID									 
								 WHERE PersonLease.LeaseID = l.LeaseID
									   AND PersonType.[Type] = 'Resident'				   
									   AND PersonLease.MainContact = 1				   
								 FOR XML PATH ('')), 1, 2, '')) AS 'Residents',			
					(SELECT MIN(MoveInDate) FROM PersonLease WHERE LeaseID = l.LeaseID) AS 'MoveDate',
					ut.Name AS 'UnitType',
					NULL AS 'PendingLeaseID',
					p.CalendarColor AS 'Color'
			FROM Unit u
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON b.PropertyID = p.PropertyID
				INNER JOIN Settings s ON p.AccountID = s.AccountID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.LeaseStatus IN ('Pending', 'Pending Transfer')
				CROSS APPLY GetUnitStatusByUnitID(u.UnitID, null) AS US
			WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
				AND u.IsHoldingUnit = 0
				AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
				AND (((s.OnlyIncludeApprovedApplicantsForMoveIns = 1) AND ((SELECT COUNT(*) 
																  FROM PersonLease plApp
																  WHERE plApp.LeaseID = l.LeaseID
																    AND plApp.ApprovalStatus IN ('Approved')) > 0))
				OR (s.OnlyIncludeApprovedApplicantsForMoveIns = 0))) Moves		  
		WHERE MoveDate <= @date
		ORDER BY MoveDate

END



GO
