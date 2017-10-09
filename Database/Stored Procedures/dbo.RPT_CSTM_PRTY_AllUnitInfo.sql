SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Ponytail Bertelsen
-- Create date: July 11, 2016
-- Description:	Does some important sproc type work
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CSTM_PRTY_AllUnitInfo] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #Buildings ( 
		BuildingID uniqueidentifier,
		PropertyID uniqueidentifier,
		Floors tinyint,
		Name nvarchar(50),
		[Description] nvarchar(500),
		StreetAddress nvarchar(50),
		City nvarchar(50),
		[State] nvarchar(50),
		Zip nvarchar(50) )
    
	CREATE TABLE #Property (
		PropertyID uniqueidentifier,
		Name nvarchar(50),
		Abbreviation nvarchar(50),
		StreetAddress nvarchar(50),
		City nvarchar(50),
		[State] nvarchar(50),
		Zip nvarchar(50),
		RegionalName nvarchar(50),
		ManagerName nvarchar(50),
		CompanyName nvarchar(50) )


	CREATE TABLE #UnitType (
		UnitTypeID uniqueidentifier,
		PropertyID uniqueidentifier,
		Name nvarchar(50),
		MarketingName nvarchar(50),
		Bedrooms int,
		Bathrooms decimal(3,1),
		[Description] nvarchar(500),
		MarketRent money,
		RequiredDeposit money,
		MarketingDescription nvarchar(500),
		Notes nvarchar(MAX) )
    
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

	CREATE TABLE #AllUnits (
		BuildingID uniqueidentifier,
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		UnitTypeMarketRent money,
		BaseMarketRent money,
		AmenityMarketRent money,
		TotalMarketRent money,
		[Status] nvarchar(50),
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


	INSERT #Buildings
		EXEC [RPT_CSTM_PRTY_BuildingInfo] @propertyIDs, @date
	
	INSERT #UnitType
		EXEC [RPT_CSTM_PRTY_UnitType] @propertyIDs, @date

	INSERT #Property
		EXEC [RPT_CSTM_PRTY_PropertyInfo] @propertyIDs, @date

	INSERT #Unit
		EXEC [RPT_CSTM_PRTY_Unit] @propertyIDs, @date, 1

	INSERT INTO #AllUnits
		SELECT	u.BuildingID,
				b.PropertyID,
				u.UnitID,
				u.UnitTypeID,
				utmr.Amount,
				null AS 'BaseMarketRent',
				null AS 'AmenityMarketRent',
				null AS 'TotalMarketRent',
				[US].[Status] AS 'Status',
				l.LeaseID,
				null AS 'CurrentResidents',
				l.LeaseStartDate,
				l.LeaseEndDate,
				#co.OccupiedMoveInDate,
				(CASE WHEN #co.OccupiedNTVDate IS NOT NULL AND #co.OccupiedNTVDate <= @date THEN #co.OccupiedNTVDate
					  ELSE NULL
				 END) AS 'CurrentResidentsNTVDate',			
				 (CASE WHEN #co.OccupiedNTVDate IS NOT NULL AND #co.OccupiedNTVDate <= @date THEN #co.OccupiedMoveOutDate
					  ELSE NULL
				 END) AS 'CurrentResidentsMoveOutDate',				
				#co.PendingLeaseID,
				null AS 'PendingResidents',
				pendl.LeaseStartDate,
				pendl.LeaseEndDate,
				#co.PendingMoveInDate
			FROM #Unit u
				INNER JOIN #Buildings b ON u.BuildingID = b.BuildingID
				LEFT JOIN #UnitAmenities #ua ON #ua.UnitID = u.UnitID
				LEFT JOIN #CurrentOccupants #co ON u.UnitID = #co.UnitID
				LEFT JOIN Lease l ON l.LeaseID = #co.OccupiedLastLeaseID
				LEFT JOIN Lease pendl ON pendl.LeaseID = #co.PendingLeaseID
				OUTER APPLY [GetLatestMarketRentByUnitTypeID](u.UnitTypeID, @date) utmr
				OUTER APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS US

	UPDATE #AllUnits SET CurrentResidents = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
													 FROM Person 
														 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
														 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID														 
													 WHERE PersonLease.LeaseID = #AllUnits.CurrentLeaseID
														   AND PersonType.[Type] = 'Resident'				   
														   AND PersonLease.MainContact = 1				   
													 FOR XML PATH ('')), 1, 2, '')

	UPDATE #AllUnits SET PendingResidents = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
													 FROM Person 
														 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
														 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID														 
													 WHERE PersonLease.LeaseID = #AllUnits.PendingLeaseID
														   AND PersonType.[Type] = 'Resident'				   
														   AND PersonLease.MainContact = 1				   
													 FOR XML PATH ('')), 1, 2, '')

	UPDATE #AU SET RequiredDeposit = [ReqDeposit].RequiredDeposit
			FROM #AllUnits #AU
			CROSS APPLY [dbo].[GetRequiredDepositAmount](#AU.UnitID, @date) [ReqDeposit]


	UPDATE #AU SET BaseMarketRent = #UAmens.MarketRent
		FROM #AllUnits #AU
			INNER JOIN #UnitAmenities #UAmens ON #AU.UnitID = #UAmens.UnitID
			
	UPDATE #AU SET TotalMarketRent = #UAmensAll.MarketRent
		FROM #AllUnits #AU
			INNER JOIN #UnitAmenitiesWithAmenities #UAmensAll ON #AU.UnitID = #UAmensAll.UnitID

	UPDATE #AllUnits SET AmenityMarketRent = ISNULL(TotalMarketRent, UnitTypeMarketRent) - ISNULL(BaseMarketRent, UnitTypeMarketRent)

	UPDATE u SET Amenities = allU.Amenities
		FROM #Unit u
			INNER JOIN #UnitAmenitiesWithAmenities allU ON u.UnitID = allU.UnitID

	SELECT * FROM #AllUnits

	SELECT * FROM #Buildings

	SELECT * FROM  #Property

	SELECT * FROM #Unit

	SELECT * FROM #UnitType

END
GO
