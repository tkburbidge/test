SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 10, 2012
-- Description:	Gets the Unit Availability status for the Available Units Report
-- =============================================
CREATE FUNCTION [dbo].[GetUnitAvailabilityStatus] 
(
	-- Add the parameters for the function here
	@unitID uniqueidentifier
	 
)
RETURNS 
@availabilityStatus TABLE 
(
	-- Add the column definitions for the TABLE variable here
	UnitID uniqueidentifier, 
	Availability nvarchar(50)
)
AS
BEGIN
	
	INSERT INTO @availabilityStatus
		SELECT	@unitID AS 'UnitID',
				CASE
					WHEN ((curl.LeaseID IS NULL) AND (pendl.LeaseID IS NULL)) THEN 'Vacant'
					WHEN ((curl.LeaseID IS NOT NULL) AND (pendl.LeaseID IS NULL) 
					      AND ((SELECT COUNT(*) FROM PersonLease pl WHERE pl.LeaseID = curl.LeaseID AND pl.ResidencyStatus = 'Current') = 
					           (SELECT COUNT(*) FROM PersonLease pl WHERE pl.LeaseID = curl.LeaseID AND pl.ResidencyStatus = 'Current' AND pl.MoveOutDate IS NOT NULL)))
						THEN 'Notice to Vacate'
					WHEN ((curl.LeaseID IS NULL) AND (pendl.LeaseID IS NOT NULL)) THEN 'Vacant Pre-Leased'
					WHEN ((curl.LeaseID IS NOT NULL) AND (pendl.LeaseID IS NOT NULL)   
					      AND ((SELECT COUNT(*) FROM PersonLease pl WHERE pl.LeaseID = curl.LeaseID AND pl.ResidencyStatus = 'Current') = 
					           (SELECT COUNT(*) FROM PersonLease pl WHERE pl.LeaseID = curl.LeaseID AND pl.ResidencyStatus = 'Current' AND pl.MoveOutDate IS NOT NULL)))
						THEN 'Notice to Vacate Pre-Leased'
					ELSE 'Not Available'
					END AS 'Availability'
			FROM Unit u
				INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Lease curl ON ulg.UnitLeaseGroupID = curl.UnitLeaseGroupID AND curl.LeaseStatus = 'Current'
				INNER JOIN UnitLeaseGroup ulg2 ON u.UnitID = ulg2.UnitID
				INNER JOIN Lease pendl ON ulg2.UnitLeaseGroupID = pendl.UnitLeaseGroupID AND pendl.LeaseStatus IN ('Pending', 'Pending Renewal', 'Pending Transfer')
			WHERE u.UnitID = @unitID
			  AND u.AllowMultipleLeases = 0
			  
		UNION
		
		SELECT	@unitID AS 'UnitID',
				CASE
					WHEN (ut.MaximumOccupancy > (SELECT COUNT(*) 
													FROM PersonLease pl 
													WHERE pl.ResidencyStatus = 'Current'
														AND pl.LeaseID IN (SELECT DISTINCT LeaseID 
																				FROM Lease 
																				WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
																				  AND LeaseStatus IN ('Current', 'Pending', 'Pending Renewal', 'Pending Transfer'))))
						THEN 'Vacant'
					WHEN  ((ut.MaximumOccupancy = (SELECT COUNT(*) 
													FROM PersonLease pl 
													WHERE pl.ResidencyStatus = 'Current'
														AND pl.LeaseID IN (SELECT DISTINCT LeaseID 
																				FROM Lease 
																				WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
																				  AND LeaseStatus IN ('Current', 'Pending', 'Pending Renewal', 'Pending Transfer'))))
							AND ((0 < (SELECT COUNT(*) 
													FROM PersonLease pl 
													WHERE pl.ResidencyStatus = 'Current'
													    AND pl.MoveOutDate IS NOT NULL
														AND pl.LeaseID IN (SELECT DISTINCT LeaseID 
																				FROM Lease 
																				WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
																				  AND LeaseStatus IN ('Current'))))))
						THEN 'Notice to Vacate'
					WHEN ((ut.MaximumOccupancy > (SELECT COUNT(*) 
													FROM PersonLease pl 
													WHERE pl.ResidencyStatus = 'Current'
														AND pl.LeaseID IN (SELECT DISTINCT LeaseID 
																				FROM Lease 
																				WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
																				  AND LeaseStatus IN ('Current'))))
							AND ((ut.MaximumOccupancy = ((SELECT COUNT(*) 
													FROM PersonLease pl 
													WHERE pl.ResidencyStatus = 'Current'
														AND pl.LeaseID IN (SELECT DISTINCT LeaseID 
																				FROM Lease 
																				WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
																				  AND LeaseStatus IN ('Current')))
												+		(SELECT COUNT(*) 
													FROM PersonLease pl 
													WHERE pl.ResidencyStatus IN ('Current', 'Pending', 'Pending Renewal', 'Pending Transfer')
														AND pl.LeaseID IN (SELECT DISTINCT LeaseID 
																				FROM Lease 
																				WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
																				  AND LeaseStatus IN ('Pending', 'Pending Renewal', 'Pending Transfer')))))))
					
						THEN 'Vacant Pre-Leased'
					WHEN ((ut.MaximumOccupancy > (SELECT COUNT(*)
													FROM PersonLease pl 
													WHERE pl.ResidencyStatus = 'Current'
														AND pl.LeaseID IN (SELECT DISTINCT LeaseID 
																				FROM Lease 
																				WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
																				  AND LeaseStatus IN ('Current'))))
							AND ((0 < (SELECT COUNT(*)
											FROM PersonLease pl 
											WHERE pl.ResidencyStatus = 'Current'
											    AND pl.MoveOutDate IS NOT NULL
												AND pl.LeaseID IN (SELECT DISTINCT LeaseID 
																		FROM Lease 
																		WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
																		  AND LeaseStatus IN ('Current')))))
							AND ((ut.MaximumOccupancy = ((SELECT COUNT(*) 
															FROM PersonLease pl 
															WHERE pl.ResidencyStatus = 'Current'
																AND pl.LeaseID IN (SELECT DISTINCT LeaseID 
																						FROM Lease 
																						WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
																						  AND LeaseStatus IN ('Current')))
												+		(SELECT COUNT(*) 
															FROM PersonLease pl 
															WHERE pl.ResidencyStatus IN ('Current', 'Pending', 'Pending Renewal', 'Pending Transfer')
																AND pl.LeaseID IN (SELECT DISTINCT LeaseID 
																						FROM Lease 
																						WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
																						  AND LeaseStatus IN ('Pending', 'Pending Renewal', 'Pending Transfer')))))))
					
						THEN 'Notice to Vacate Pre-Leased'
					ELSE 'Not Available'
					END AS 'Availability'
			FROM Unit u
				INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID

			WHERE u.UnitID = @unitID
			  AND u.AllowMultipleLeases = 1		
	
	RETURN 
END
GO
