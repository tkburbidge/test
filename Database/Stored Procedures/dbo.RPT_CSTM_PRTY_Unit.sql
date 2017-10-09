SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 11, 2016
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_PRTY_Unit] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null,
	@dontNestMeBro bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here

	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier null,
		UnitStatus nvarchar(200) null,
		UnitStatusLedgerItemTypeID uniqueidentifier null,
		RentLedgerItemTypeID uniqueidentifier null,
		MarketRent decimal null,
		Amenities nvarchar(MAX) null)
		
	CREATE TABLE #Properties (
		Sequence int identity not null,
		PropertyID uniqueidentifier not null)

	DECLARE @propertyID uniqueidentifier, @ctr int = 1, @maxCtr int, @unitIDs GuidCollection
	DECLARE @accountID bigint

	INSERT #Properties SELECT Value FROM @propertyIDs
	SET @maxCtr = (SELECT MAX(Sequence) FROM #Properties)
	
	WHILE ((@ctr <= @maxCtr) AND (@dontNestMeBro = 0))
	BEGIN
		SELECT @propertyID = PropertyID FROM #Properties WHERE Sequence = @ctr
		SELECT @accountID = AccountID FROM Property WHERE PropertyID = @propertyID
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
		--INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 0
		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 1
		SET @ctr = @ctr + 1
	END		

	SELECT	u.UnitID,
			b.BuildingID,
			u.UnitTypeID,
			u.Number,
			u.PaddedNumber,
			addr.StreetAddress,
			addr.City,
			addr.[State],
			addr.Zip,
			u.SquareFootage,
			u.[Floor],
			(CASE 
				WHEN (0 = (SELECT COUNT(*) 
					FROM WorkOrder wo
						INNER JOIN UnitNote un ON un.UnitNoteID = wo.UnitNoteID AND un.UnitID = #ua.UnitID
					WHERE ((wo.CompletedDate IS NULL) OR (wo.CompletedDate > @date))
						AND wo.[Status] NOT IN ('Cancelled')
						AND wo.WorkOrderCategoryID IN (SELECT WorkOrderCategoryID 
														FROM AutoMakeReady 
														WHERE PropertyID = b.PropertyID))) THEN CAST(0 AS BIT)
				ELSE CAST(1 AS BIT)
				END) AS 'IsMadeReady',
			#ua.Amenities,
			u.PetsPermitted,
			u.IsHoldingUnit,
			u.AvailableForOnlineMarketing,
			u.HearingAccessibility,
			u.MobilityAccessibility,
			u.VisualAccessibility,
			u.ExcludedFromOccupancy,
			u.WorkOrderUnitInstructions AS 'WorkOrderUnitInstructions',
			u.AvailableUnitsNote,
			u.DateRemoved
		FROM Unit u
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN [Address] addr ON u.AddressID = addr.AddressID
			LEFT JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
		WHERE b.PropertyID IN (SELECT Value FROM @propertyIDs)
END
GO
