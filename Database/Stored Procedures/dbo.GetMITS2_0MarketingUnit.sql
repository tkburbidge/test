SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 12, 2013
-- Description:	Gets the MITS MarketingUnit2.0 data
-- =============================================
CREATE PROCEDURE [dbo].[GetMITS2_0MarketingUnit] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null, 
	@propertyID uniqueidentifier = null,
	@date date = null,
	@buildingName nvarchar(100) = null,
	@floor nvarchar(100) = null,
	@unitTypeName nvarchar(100) = null,
	@availableOnly bit = 0,
	@filterForOnlineMarketing bit = 1,
	@includeHoldingUnits bit = 0
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

	DECLARE @unitIDs GuidCollection
	
	INSERT @unitIDs SELECT u.UnitID 
						FROM Unit u
							INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
							INNER JOIN Building b ON b.BuildingID = u.BuildingID							
						WHERE ((@buildingName IS NULL) OR (@buildingName = b.Name)) 
							AND ((@floor IS NULL) OR (@floor = u.[Floor]))
							AND ((@unitTypeName IS NULL) OR (@unitTypeName = ut.Name))
							AND ((@filterForOnlineMarketing = 0) OR ((@filterForOnlineMarketing = 1) AND (u.AvailableForOnlineMarketing = 1) AND (UT.AvailableForOnlineMarketing = 1)))
						
	IF ((SELECT COUNT(*) FROM @unitIDs) > 0)						
	BEGIN
		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 0
	END
	
	SELECT * FROM 
		-- Get normal units
		(SELECT	u.UnitID AS 'UnitID',
				u.UnitTypeID AS 'UnitTypeID',
				u.Number AS 'UnitNumber',
				u.BuildingID AS 'BuildingID',
				b.Name AS 'BuildingName',
				u.[Floor] AS 'Floor',
				#ua.MarketRent AS 'MarketRent',
				#ua.UnitStatus,
				#ua.Amenities,
				pl.LeaseID AS 'PendingLeaseID',
				cl.LeaseID AS 'CurrentLeaseID',
				(SELECT MAX(pl1.MoveOutDate)
					FROM PersonLease pl1
						LEFT JOIN PersonLease plmo ON plmo.LeaseID = pl1.LeaseID AND plmo.MoveOutDate IS NULL AND plmo.ResidencyStatus NOT IN ('Cancelled')
					WHERE pl1.LeaseID = cl.LeaseID
					  AND pl1.ResidencyStatus NOT IN ('Cancelled')
					  AND plmo.PersonLeaseID IS NULL) AS 'MoveOutDate',
				u.LastVacatedDate AS 'LastVacated',
				a.StreetAddress,
				a.City,
				a.[State],
				a.Zip,
				a.Country,
				u.AddressIncludesUnitNumber,
				u.PaddedNumber,
				u.PetsPermitted,
				u.SquareFootage AS 'SquareFeet',
				(CASE WHEN #ua.UnitStatus = 'Ready' AND cl.LeaseID IS NULL and pl.LeaseID IS NULL THEN @date
				 ELSE u.DateAvailable
				 END) AS 'DateAvailable',
				u.IsHoldingUnit
			FROM Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
				INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
				INNER JOIN Building b on u.BuildingID = b.BuildingID				
				LEFT JOIN UnitLeaseGroup culg ON u.UnitID = culg.UnitID AND ((SELECT COUNT(*) FROM Lease WHERE LeaseStatus IN ('Current', 'Under Eviction') AND UnitLeaseGroupID = culg.UnitLeaseGroupID) > 0)
				LEFT JOIN UnitLeaseGroup pulg ON u.UnitID = pulg.UnitID	AND ((SELECT COUNT(*) FROM Lease WHERE LeaseStatus IN ('Pending', 'Pending Transfer') AND UnitLeaseGroupID = pulg.UnitLeaseGroupID) > 0)	
				LEFT JOIN Lease cl ON culg.UnitLeaseGroupID = cl.UnitLeaseGroupID AND cl.LeaseStatus IN ('Current', 'Under Eviction')
				LEFT JOIN Lease pl ON pulg.UnitLeaseGroupID = pl.UnitLeaseGroupID AND pl.LeaseStatus IN ('Pending', 'Pending Transfer')
				LEFT JOIN [Address] a ON a.AddressID = u.AddressID
			WHERE u.IsHoldingUnit = 0
				AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
		UNION
			-- Get Holding Units if desired
			SELECT	u.UnitID AS 'UnitID',
				u.UnitTypeID AS 'UnitTypeID',
				u.Number AS 'UnitNumber',
				u.BuildingID AS 'BuildingID',
				b.Name AS 'BuildingName',
				u.[Floor] AS 'Floor',
				#ua.MarketRent AS 'MarketRent',
				#ua.UnitStatus,
				#ua.Amenities,
				null,
				null,
				null,
				u.LastVacatedDate AS 'LastVacated',
				a.StreetAddress,
				a.City,
				a.[State],
				a.Zip,
				a.Country,
				u.AddressIncludesUnitNumber,
				u.PaddedNumber,
				u.PetsPermitted,
				u.SquareFootage AS 'SquareFeet',
				u.DateAvailable,
				u.IsHoldingUnit
			FROM Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
				INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
				INNER JOIN Building b on u.BuildingID = b.BuildingID				
				LEFT JOIN [Address] a ON a.AddressID = u.AddressID
			WHERE @includeHoldingUnits = 1 AND u.IsHoldingUnit = 1
			  AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)) Units			

		WHERE ((@includeHoldingUnits = 1 OR IsHoldingUnit = 0) 
				AND ((@availableOnly = 0) 
				  OR (@availableOnly IS NULL) 
				  OR (PendingLeaseID IS NULL AND (CurrentLeaseID IS NULL OR MoveOutDate IS NOT NULL) AND UnitStatus IN ('Ready', 'Not Ready'))))
		ORDER BY PaddedNumber
	
END
GO
