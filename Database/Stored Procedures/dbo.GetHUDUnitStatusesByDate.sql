SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
----------------------------------------------------------------------------------------------------------

-- =============================================
-- Author:		Mike Root
-- Create date: September 2, 2016
-- Description:	Used to return HUD statuses for all units at a single property on a given date
-- =============================================
CREATE PROCEDURE [dbo].[GetHUDUnitStatusesByDate]
	@accountID bigint = null,
	@propertyID uniqueidentifier,
	@date datetime
AS
BEGIN

	SET NOCOUNT ON;

	--Get OccupantsByDate could get more than one property, but for right now we only need it to get one property
	DECLARE @propertyIDs GuidCollection
	INSERT INTO @propertyIDs VALUES (@propertyID)

	DECLARE @Occupants AS TABLE(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null
	)
	
    INSERT INTO @Occupants
		SELECT * FROM 
			(SELECT  
				b.PropertyID,
				u.UnitID,
				u.Number,
				ulg.UnitLeaseGroupID,
				MIN(pl.MoveInDate) AS 'MoveInDate',
				CASE WHEN fl.LeaseID IS NOT NULL THEN MAX(fpl.MoveOutDate) ELSE NULL END AS 'MoveOutDate'
			FROM UnitLeaseGroup ulg
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN @propertyIDs #pids ON #pids.Value = b.PropertyID
			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
			LEFT JOIN Lease fl ON fl.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND fl.LeaseStatus IN ('Former', 'Evicted')
			LEFT JOIN PersonLease fpl ON fpl.LeaseID = fl.LeaseID
			WHERE l.LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
				AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
				AND u.AccountID = @accountID
				--This is a difference between between this logic and the GetOccupantsByDate logic
				--AND u.ExcludedFromOccupancy = 0
				AND u.IsHoldingUnit = 0
				AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
			GROUP BY b.PropertyID, ulg.UnitLeaseGroupID, u.UnitID, u.Number, u.PaddedNumber, fl.LeaseID) OccupancyHistory
		WHERE MoveInDate <= @date
		AND (MoveOutDate IS NULL OR MoveOutDate >= @date)

	INSERT INTO @Occupants
		SELECT b.PropertyID,
			   u.UnitID,
			   u.Number,
			   null,
			   null, 
			   null				
		FROM Unit u 
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN @propertyIDs #pids ON #pids.Value = b.PropertyID
			LEFT JOIN @Occupants #o ON #o.UnitID = u.UnitID
		WHERE #o.UnitID IS NULL
			AND u.AccountID = @accountID
			--This is a difference between between this logic and the GetOccupantsByDate logic
			--AND u.ExcludedFromOccupancy = 0
			AND u.IsHoldingUnit = 0
			AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)

	SELECT o.UnitID,
		o.PropertyID,
		CASE WHEN us.Status = 'Abated' THEN 'A'
			WHEN us.Status = 'Not Ready' THEN 'N'
			--Market is 'Market and occupied' so there must be a person living there currently,
			--plus it must be designated as market, they could still have an assistance payment
			--in Resman, but that's their mistake, we won't consider it to be a subsidy unit,
			--and we'll ignore any assistance payments
			WHEN o.UnitLeaseGroupID IS NOT NULL AND u.IsMarket = 1 THEN 'M'
			WHEN o.UnitLeaseGroupID IS NULL AND us.Status = 'Ready' THEN 'V'
			WHEN o.UnitLeaseGroupID IS NOT NULL AND us.Status = 'Ready' THEN 'O'
			--If you hit this else the unit must be in either Down or Admin or Model status which we haven't mapped to HUD statuses yet
			--Or you have funky data, like you have a person living in a unit, but the unit's also marked as Abated
			--In either case this else just means we have no way of really figuring out what the user is trying to report the unit as
			--When the user tries to report this unit to HUD they're going to encounter a 'Status is null' message and they'll have to figure
			--out at that point that we couldn't figure out what the status of their unit is so they'll need to fix their data
			ELSE ''
		END AS 'HUDStatus'
	FROM @Occupants  o
	INNER JOIN Unit u ON o.UnitID = u.UnitID
	CROSS APPLY dbo.GetUnitStatusByUnitID(o.UnitID, @date) us

END
GO
