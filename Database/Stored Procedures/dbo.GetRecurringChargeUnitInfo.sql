SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 21, 2013
-- Description:	Gets Unit Information needed for Posting Recurring Charges, or Autobills.
-- =============================================
CREATE PROCEDURE [dbo].[GetRecurringChargeUnitInfo] 
	-- Add the parameters for the stored procedure here
	@propertyID uniqueidentifier = null, 
	@unitIDs GuidCollection READONLY,
	@date date = null,
	@includeNonMarketRent bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	IF @propertyID IS NULL
	BEGIN
		SET @propertyID = (SELECT TOP 1 PropertyID
						   FROM Unit u
								INNER JOIN Building b ON b.BuildingID = u.BuildingID
						   WHERE u.UnitID IN (SELECT Value FROM @unitIDs))
	END		

	CREATE TABLE #UnitIDs ( UnitID uniqueidentifier )

	IF ((SELECT COUNT(*) FROM @unitIDs) > 0)
	BEGIN
		INSERT INTO #UnitIDs SELECT Value FROM @unitIDs
	END
	ELSE
	BEGIN
		INSERT INTO #UnitIDs
			SELECT u.UnitID
			FROM Unit u
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			WHERE b.PropertyID = @propertyID
	END

	CREATE TABLE #MyAmenities (
		AmenityID uniqueidentifier not null,
		Name nvarchar(1000) null,
		UnitID uniqueidentifier not null,
		Amount money null)

	INSERT #MyAmenities 
	SELECT DISTINCT a.AmenityID, a.Name, ua.UnitID, ac.Amount
		FROM UnitAmenity ua 
			INNER JOIN Amenity a ON ua.AmenityID = a.AmenityID
			INNER JOIN AmenityCharge ac ON ac.AmenityID = a.AmenityID			
			INNER JOIN #UnitIDs #uids ON #uids.UnitID = ua.UnitID
		WHERE a.PropertyID = @propertyID
		  AND ua.DateEffective <= @date
		  -- Only get the latest amenity charge
		  AND ac.AmenityChargeID = (SELECT TOP 1 AmenityChargeID FROM AmenityCharge WHERE AmenityID = a.AmenityID AND DateEffective <= @date ORDER BY DateEffective DESC, DateCreated DESC)
		  -- Either we are told to get all amenities or
		  -- only get the latest amenity charge that is applied to market rent
		  AND ((@includeNonMarketRent = 1) OR (ac.LedgerItemTypeID IS NULL))

	SELECT	DISTINCT
			u.Number,
			u.UnitID AS 'UnitID',
			ut.UnitTypeID AS 'UnitTypeID',
			us.[Name] AS 'UnitStatus',
			us.StatusLedgerItemTypeID AS 'UnitStatusLedgerItemTypeID',
			ut.RentLedgerItemTypeID AS 'RentLedgerItemTypeID',
			(ISNULL(SUM(#ma.Amount), 0) + 			
			ISNULL((SELECT ISNULL(Amount, 0) FROM GetLatestMarketRentByUnitID(u.UnitID, @date)), 0)) AS 'MarketRent',
			STUFF((SELECT DISTINCT ', ' + (#ma1.Name) 
				FROM #MyAmenities #ma1				
				WHERE #ma1.UnitID = u.UnitID			
				FOR XML PATH ('')), 1, 2, '') AS 'Amenities'
		FROM Unit u 
			INNER JOIN #UnitIDs #uids ON #uids.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID			
			CROSS APPLY [GetUnitStatusByUnitID](u.UnitID, @date) un
			INNER JOIN UnitStatus us on un.UnitStatusID = us.UnitStatusID			
			LEFT JOIN #MyAmenities #ma ON u.UnitID = #ma.UnitID	
		WHERE ut.PropertyID = @propertyID		  
			AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
		GROUP BY u.UnitID, u.Number, ut.UnitTypeID, ut.RentLedgerItemTypeID, us.[Name], us.StatusLedgerItemTypeID--, #ma.AmenityID


END
GO
