SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Oct. 19, 2012
-- Description:	Gets the Ellipse Units Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_ELLIPSE_GetUnits] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		UnitStatus nvarchar(200) not null,
		UnitStatusLedgerItemTypeID uniqueidentifier not null,
		RentLedgerItemTypeID uniqueidentifier not null,
		MarketRent decimal null,
		Amenities nvarchar(MAX) null)
		
	CREATE TABLE #Properties (
		Sequence int identity not null,
		PropertyID uniqueidentifier not null)
		
	DECLARE @propertyID uniqueidentifier, @ctr int = 1, @maxCtr int, @unitIDs GuidCollection, @date date
	
	INSERT #Properties SELECT Value FROM @propertyIDs
	SET @maxCtr = (SELECT MAX(Sequence) FROM #Properties)
	SET @date = GETDATE()
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @propertyID = PropertyID FROM #Properties WHERE Sequence = @ctr
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date
		SET @ctr = @ctr + 1
	END	

	SELECT	DISTINCT
			u.UnitID AS 'UnitId',
			ut.PropertyID AS 'PropId',
			ut.Name AS 'UnitType',
			u.Number AS 'UnitNumber',
			CASE
				WHEN ((l.LeaseID IS NULL) OR (l.LeaseStatus IN ('Former', 'Evicted'))) THEN 'Vacant'			
				WHEN (l.LeaseStatus = 'Pending') THEN 'Pending'
				WHEN ((l.LeaseStatus IN ('Current', 'Under Eviction')) AND (pl.MoveOutDate IS NOT NULL) AND (plmo.PersonLeaseID IS NULL)) THEN 'Notice'
				ELSE 'Occupant' END AS 'Status',
			CASE 
				WHEN (l.LeaseStatus IN ('Former', 'Evicted')) THEN (SELECT MAX(MoveOutDate) FROM PersonLease WHERE LeaseID = l.LeaseID)
				WHEN ((l.LeaseStatus IN ('Current', 'Under Eviction')) AND (pl.MoveOutDate IS NOT NULL) AND (plmo.PersonLeaseID IS NULL)) 
					THEN (SELECT MAX(MoveOutDate) FROM PersonLease WHERE LeaseID = l.LeaseID)
				ELSE null END AS 'VancantDate',
			null AS 'BaseRent',
			--ut.MarketRent AS 'MarketRent'
			#ua.MarketRent AS 'MarketRent'
		FROM Unit u
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
			LEFT JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
						AND ulg.UnitLeaseGroupID = (SELECT TOP 1 l1.UnitLeaseGroupID
														FROM Lease l1
														WHERE l1.UnitLeaseGroupID in (SELECT UnitLeaseGroupID 
																							FROM UnitLeaseGroup 
																							WHERE UnitID = u.UnitID)
															AND LeaseStatus IN ('Current', 'Former', 'Pending', 'Under Eviction', 'Evicted')
														ORDER BY l1.LeaseStartDate DESC)
			LEFT JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
						AND (l.LeaseID = (SELECT TOP 1 LeaseID 
											FROM Lease 
											WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
											  AND LeaseStatus IN ('Current', 'Former', 'Pending', 'Under Eviction', 'Evicted')
											ORDER BY LeaseStartDate DESC))
			LEFT JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
			LEFT JOIN PersonLease plmo ON l.LeaseID = plmo.LeaseID AND plmo.MoveOutDate IS NULL
		WHERE ut.PropertyID IN (SELECT Value FROM @propertyIDs)
			AND u.ExcludedFromOccupancy = 0
			AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
	
END
GO
