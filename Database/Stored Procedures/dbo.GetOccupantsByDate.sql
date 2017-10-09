SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Olsen
-- Create date: 6/4/2014
-- Description:	Gets the occupancy status of each unit
--				for a given property
-- =============================================
CREATE PROCEDURE [dbo].[GetOccupantsByDate]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@date date,
	@propertyIDs GuidCollection READONLY	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #OccupantsPropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #OccupantsPropertyIDs SELECT Value FROM @propertyIDs

	CREATE TABLE #Occupants 
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null
	)

    INSERT INTO #Occupants
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
			INNER JOIN #OccupantsPropertyIDs #pids ON #pids.PropertyID = b.PropertyID
			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
			LEFT JOIN Lease fl ON fl.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND fl.LeaseStatus IN ('Former', 'Evicted')
			LEFT JOIN PersonLease fpl ON fpl.LeaseID = fl.LeaseID
			WHERE l.LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
				AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
				AND u.AccountID = @accountID
				AND u.ExcludedFromOccupancy = 0
				AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
				AND u.IsHoldingUnit = 0
			GROUP BY b.PropertyID, ulg.UnitLeaseGroupID, u.UnitID, u.Number, u.PaddedNumber, fl.LeaseID) OccupancyHistory
		WHERE MoveInDate <= @date
		AND (MoveOutDate IS NULL OR MoveOutDate >= @date)


	INSERT INTO #Occupants
		SELECT b.PropertyID,
			   u.UnitID,
			   u.Number,
			   null,
			   null, 
			   null				
		FROM Unit u 
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN #OccupantsPropertyIDs #pids ON #pids.PropertyID = b.PropertyID
			LEFT JOIN #Occupants #o ON #o.UnitID = u.UnitID
		WHERE #o.UnitID IS NULL
			AND u.AccountID = @accountID
			AND u.ExcludedFromOccupancy = 0
			AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
			AND u.IsHoldingUnit = 0

	SELECT * FROM #Occupants
END
GO
