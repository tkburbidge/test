SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Olsen
-- Create date: January 29, 2013
-- Description:	Gets the market rent for a given lease on a given date
-- =============================================
CREATE PROCEDURE [dbo].[GetMarketRentByLeaseID]
	@accountID bigint,
	@leaseID uniqueidentifier,
	@date date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @propertyID uniqueidentifier
	DECLARE @unitID uniqueidentifier
	DECLARE @unitIDs GuidCollection
	
	SELECT @propertyID = b.PropertyID, @unitID = u.UnitID
	FROM Lease l 
		INNER JOIN UnitLeaseGroup ulg on ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u on u.UnitID = ulg.UnitID
		INNER JOIN Building b on b.BuildingID = u.BuildingID
	WHERE l.AccountID = @accountID AND l.LeaseID = @leaseID
	
	INSERT INTO @unitIDs VALUES (@unitID)
	
	DECLARE @unitTypeInfo AS TABLE
	(
		UnitNumber nvarchar(100),
		UnitID uniqueidentifier, 
		UnitTypeID uniqueidentifier,
		UnitStatus nvarchar(100),
		UnitStatusLedgerItemTypeID uniqueidentifier,
		RentLedgerItemTypeID uniqueidentifier,
		MarketRent money,
		Amenities nvarchar(MAX) 
	)				
			
	INSERT INTO @unitTypeInfo EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date
	
	SELECT TOP 1 MarketRent FROM @unitTypeInfo
END
GO
