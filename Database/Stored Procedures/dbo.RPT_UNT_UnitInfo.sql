SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[RPT_UNT_UnitInfo] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.

	-- NOTE: There are a few things commented out or not populated here because they aren't used 
	--		 but kept them there in case we do use them later
	SET NOCOUNT ON;

	CREATE TABLE #Unit (
		UnitID uniqueidentifier,
		BuildingID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		Number nvarchar(50),
		PaddedNumber nvarchar(50),
		StreetAddress nvarchar(50),
		City nvarchar(50),
		[State] nvarchar(50),
		Zip nvarchar(50),
		SquareFootage int,
		[Floor] nvarchar(100),
 		IsMadeReady bit,
		Amenities nvarchar(500),
		PetsPermitted bit,
		IsHoldingUnit bit,
		AvailableForOnlineMarketing bit,
		HearingAccessible bit,
		MobilityAccessible bit,
		VisualAccessible bit,
		ExcludedFromOccupancy bit,
		WorkOrderUnitInstructions nvarchar(MAX),
		AvailableUnitsNote nvarchar(500) )

	CREATE TABLE #UnitInfo (
		BuildingID uniqueidentifier,
		BuildingName nvarchar(50),
		PropertyID uniqueidentifier,
		PropertyName nvarchar(50),
		UnitID uniqueidentifier,
		Number nvarchar(50),
		PaddedNumber nvarchar(50),
		StreetAddress nvarchar(50),
		City nvarchar(50),
		[State] nvarchar(50),
		Zip nvarchar(50),
		SquareFootage int,
		[Floor] nvarchar(100),
 		IsMadeReady bit,
		Amenities nvarchar(500),
		PetsPermitted bit,
		IsHoldingUnit bit,
		AvailableForOnlineMarketing bit,
		HearingAccessible bit,
		MobilityAccessible bit,
		VisualAccessible bit,
		ExcludedFromOccupancy bit,
		WorkOrderUnitInstructions nvarchar(MAX),
		AvailableUnitsNote nvarchar(500),
		BaseMarketRent money,
		AmenityMarketRent money,
		TotalMarketRent money,
		RequiredDeposit money,
		[Status] nvarchar(50),
		-- Unit Type Info
		UnitTypeID uniqueidentifier,
		UnitType nvarchar(50),
		UnitTypeDescription nvarchar(500),
		UnitTypeBedrooms int,
		UnitTypeBathrooms decimal(3,1),
		UnitTypeMaxOccupancy int,
		UnitTypeMarketRent money,
		UnitTypeMarketingName nvarchar(50),
		UnitTypeMarketingDescription nvarchar(500),
		UnitTypeNotes nvarchar(MAX),
		-- Data pulled from GetConsolidatedOccupancyNumbers
		CurrentLeaseID uniqueidentifier,
		CurrentResidents nvarchar(500),
		CurrentLeaseStartDate date,
		CurrentLeaseEndDate date,
		CurrentResidentsMoveInDate date,
		CurrentResidentsNTVDate date,
		CurrentResidentsMoveOutDate date,
		PendingLeaseID uniqueidentifier,
		PendingResidents nvarchar(500),
		PendingLeaseStartDate date,
		PendingLeaseEndDate date,
		PendingMoveInDate date)
    
	CREATE TABLE #CurrentOccupants
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,		
		OccupiedUnitLeaseGroupID uniqueidentifier, 
		OccupiedLastLeaseID uniqueidentifier,
		OccupiedMoveInDate date,
		OccupiedNTVDate date,
		OccupiedMoveOutDate date,
		OccupiedIsMovedOut bit,
		PendingUnitLeaseGroupID uniqueidentifier,
		PendingLeaseID uniqueidentifier,
		PendingApplicationDate date,
		PendingMoveInDate date 
	)

	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier null,
		UnitStatus nvarchar(200) null,
		UnitStatusLedgerItemTypeID uniqueidentifier null,
		RentLedgerItemTypeID uniqueidentifier null,
		MarketRent decimal null,
		Amenities nvarchar(MAX) null)
	
	CREATE TABLE #UnitAmenitiesWithAmenities (
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

	DECLARE @propertyID uniqueidentifier, @ctr int = 1, @maxCtr int, @unitIDs GuidCollection
	DECLARE @accountID bigint

	INSERT #Properties SELECT Value FROM @propertyIDs
	SET @maxCtr = (SELECT MAX(Sequence) FROM #Properties)
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @propertyID = PropertyID FROM #Properties WHERE Sequence = @ctr
		SELECT @accountID = AccountID FROM Property WHERE PropertyID = @propertyID
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
		--INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 0
		INSERT #UnitAmenitiesWithAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 0
		SET @ctr = @ctr + 1
	END		

	INSERT #UnitAmenities
		SELECT	DISTINCT
				#uawa.Number,
				#uawa.UnitID,
				null, null, null, null, 
				[MarRent].Amount,
				null
			FROM #UnitAmenitiesWithAmenities #uawa
				CROSS APPLY GetLatestMarketRentByUnitID(#uawa.UnitID, @date) [MarRent]

	INSERT INTO #CurrentOccupants
		EXEC [GetConsolodatedOccupancyNumbers] @accountID, @date, null, @propertyIDs

	INSERT #Unit
		EXEC [RPT_CSTM_PRTY_Unit] @propertyIDs, @date, 1

	INSERT INTO #UnitInfo
		SELECT	u.BuildingID,
				b.[Name],
				b.PropertyID,
				p.[Name],
				u.UnitID,
				u.Number,
				u.PaddedNumber,
				u.StreetAddress,
				u.City,
				u.[State],
				u.Zip,
				u.SquareFootage,
				u.[Floor],
				u.IsMadeReady,
				u.Amenities,
				u.PetsPermitted,
				u.IsHoldingUnit,
				u.AvailableForOnlineMarketing,
				u.HearingAccessible,
				u.MobilityAccessible,
				u.VisualAccessible,
				u.ExcludedFromOccupancy,
				u.WorkOrderUnitInstructions,
				u.AvailableUnitsNote,
				0 AS 'BaseMarketRent',
				0 AS 'AmenityMarketRent',
				null AS 'TotalMarketRent',
				null AS 'RequiredDeposit',
				[US].[Status] AS 'Status',
				u.UnitTypeID,
				ut.[Name],
				ut.[Description],
				ut.Bedrooms,
				ut.Bathrooms,
				ut.MaximumOccupancy,
				utmr.Amount,
				ut.MarketingName,
				ut.MarketingDescription,
				ut.Notes,
				l.LeaseID,
				null AS 'CurrentResidents',
				l.LeaseStartDate,
				l.LeaseEndDate,
				#co.OccupiedMoveInDate,
				--(CASE WHEN #co.OccupiedNTVDate IS NOT NULL AND #co.OccupiedNTVDate <= @date THEN #co.OccupiedNTVDate
				--	  ELSE NULL
				-- END) AS 'CurrentResidentsNTVDate',			
				-- (CASE WHEN #co.OccupiedNTVDate IS NOT NULL AND #co.OccupiedNTVDate <= @date THEN #co.OccupiedMoveOutDate
				--	  ELSE NULL
				-- END) AS 'CurrentResidentsMoveOutDate',	
				null, 
				null,			
				#co.PendingLeaseID,
				null AS 'PendingResidents',
				pendl.LeaseStartDate,
				pendl.LeaseEndDate,
				#co.PendingMoveInDate
			FROM #Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p on b.PropertyID = p.PropertyID
				LEFT JOIN #CurrentOccupants #co ON u.UnitID = #co.UnitID
				LEFT JOIN Lease l ON l.LeaseID = #co.OccupiedLastLeaseID
				LEFT JOIN Lease pendl ON pendl.LeaseID = #co.PendingLeaseID
				OUTER APPLY [GetLatestMarketRentByUnitTypeID](u.UnitTypeID, @date) utmr
				OUTER APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS US

	--UPDATE #UnitInfo SET CurrentResidents = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
	--												 FROM Person 
	--													 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
	--													 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID														 
	--												 WHERE PersonLease.LeaseID = #UnitInfo.CurrentLeaseID
	--													   AND PersonType.[Type] = 'Resident'				   
	--													   AND PersonLease.MainContact = 1				   
	--												 FOR XML PATH ('')), 1, 2, '')

	--UPDATE #UnitInfo SET PendingResidents = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
	--												 FROM Person 
	--													 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
	--													 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID														 
	--												 WHERE PersonLease.LeaseID = #UnitInfo.PendingLeaseID
	--													   AND PersonType.[Type] = 'Resident'				   
	--													   AND PersonLease.MainContact = 1				   
	--												 FOR XML PATH ('')), 1, 2, '')

	UPDATE #UI SET RequiredDeposit = [ReqDeposit].Deposit
			FROM #UnitInfo #UI
			CROSS APPLY [GetRequiredDepositAmount](#UI.UnitID, @date) [ReqDeposit]


	--UPDATE #UI SET BaseMarketRent = #UAmens.MarketRent
	--	FROM #UnitInfo #UI
	--		INNER JOIN #UnitAmenities #UAmens ON #UI.UnitID = #UAmens.UnitID
			
	UPDATE #UI SET TotalMarketRent = #UAmensAll.MarketRent
		FROM #UnitInfo #UI
			INNER JOIN #UnitAmenitiesWithAmenities #UAmensAll ON #UI.UnitID = #UAmensAll.UnitID
	UPDATE #UnitInfo SET TotalMarketRent = 0 WHERE TotalMarketRent IS NULL

	--UPDATE #UnitInfo SET AmenityMarketRent = ISNULL(TotalMarketRent, UnitTypeMarketRent) - ISNULL(BaseMarketRent, UnitTypeMarketRent)

	--UPDATE #UnitInfo SET AmenityMarketRent = ISNULL(TotalMarketRent, UnitTypeMarketRent) - ISNULL(BaseMarketRent, UnitTypeMarketRent)

	UPDATE ui SET Amenities = allU.Amenities
		FROM #UnitInfo ui
			INNER JOIN #UnitAmenitiesWithAmenities allU ON ui.UnitID = allU.UnitID

	SELECT * FROM #UnitInfo

END
GO
