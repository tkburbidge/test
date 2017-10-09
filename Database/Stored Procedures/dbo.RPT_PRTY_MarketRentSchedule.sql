SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: June 30, 2014
-- Description:	Gets the data for the MarketRentSchedule Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRTY_MarketRentSchedule] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@date date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Properties (
		Sequence int identity,
		PropertyID uniqueidentifier not null)


	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		UnitStatus nvarchar(200) not null,
		UnitStatusLedgerItemTypeID uniqueidentifier not null,
		RentLedgerItemTypeID uniqueidentifier not null,
		MarketRent decimal null,
		Amenities nvarchar(MAX) null)	
		

		
	CREATE TABLE #MarketRentSchedule (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		UnitTypeID uniqueidentifier not null,
		UnitType nvarchar(50) not null,
		UnitTypeDescription nvarchar(4000) not null,
		Amenities nvarchar(500) null,
		UnitTypeSquareFootage int not null,
		SquareFootage int not null,
		BaseMarketRent money null,
		TotalMarketRent money null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(50) null,
		PaddedNumber nvarchar(50) null)
		
	DECLARE @propertyID uniqueidentifier, @ctr int = 1, @maxCtr int, @unitIDs GuidCollection
	
	INSERT #Properties SELECT Value FROM @propertyIDs
	SET @maxCtr = (SELECT MAX(Sequence) FROM #Properties)
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @propertyID = PropertyID FROM #Properties WHERE Sequence = @ctr
		DELETE FROM @unitIDs
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
							WHERE u.IsHoldingUnit = 0
								AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 0
		SET @ctr = @ctr + 1
	END	
	
	INSERT #MarketRentSchedule
		SELECT	ut.PropertyID, p.Name, ut.UnitTypeID, ut.Name, ut.Description, #ua.Amenities, ut.SquareFootage, u.SquareFootage,  
				ISNULL((SELECT ISNULL(Amount, 0) FROM GetLatestMarketRentByUnitID(#ua.UnitID, @date)), 0),
				#ua.MarketRent, #ua.UnitID, u.Number, u.PaddedNumber
			FROM #UnitAmenities #ua
				INNER JOIN UnitType ut ON #ua.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				INNER JOIN Unit u ON #ua.UnitID = u.UnitID					

	SELECT * FROM #MarketRentSchedule

	SELECT DISTINCT p.Name AS 'PropertyName', a.Name, ac.Amount
	FROM Amenity a
		INNER JOIN AmenityCharge ac ON a.AmenityID = ac.AmenityID 
								AND ac.AmenityChargeID = (SELECT TOP 1 AmenityChargeID 
															  FROM AmenityCharge 
															  WHERE AmenityID = a.AmenityID
															   AND DateEffective <= @date
															  ORDER BY DateEffective DESC)
		INNER JOIN Property p on a.PropertyID = p.PropertyID
	WHERE a.PropertyID IN (SELECT Value FROM @propertyIDs)				
END


GO
