SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 15, 2014
-- Description:	Gets the current market rentable price factoring in term length, and if they're integrated with LRO.
-- =============================================
CREATE PROCEDURE [dbo].[GetLatestUnitPrice] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyID uniqueidentifier = null, 
	@unitIDs GuidCollection READONLY,
	@leaseTerm int = null
AS

DECLARE @myUnitIDs GuidCollection				-- A collection of the UnitIDs derived from either the available units, or the set of units passed in as a parameter.
DECLARE @allUnitIDs GuidCollection				-- A collection of all of the UnitIDs associated with a given property.  Used to determine what units are available.
DECLARE @myMissingUnitIDs GuidCollection		-- A collection of the UnitIDs that we have NOT yet found pricing for.  Eventually this set will be empty.
DECLARE @maxAutoMakeReady int
DECLARE @newPricingBatchID uniqueidentifier
DECLARE @isLROIntegrated bit = 0


BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @date date = GETDATE()
	
	-- Final results set
	CREATE TABLE #PricingToReturn (
		ObjectID uniqueidentifier not null,
		LeaseTerm int null,
		PricingID uniqueidentifier null,
		BaseRent money null,
		Concession money null,
		ExtraAmenitiesAmount money null,
		EffectiveRent money null,
		StartDate date null,
		EndDate date null,
		IsFixed bit null,
		LeaseTermName nvarchar(50) null)
	
	CREATE TABLE #UnitMarketRent1 (
		UnitID uniqueidentifier not null,
		MarketRent money null)
		
	CREATE TABLE #UnitAvailability (
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		DateAvailable date null)
		
	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		UnitStatus nvarchar(200) not null,
		UnitStatusLedgerItemTypeID uniqueidentifier not null,
		RentLedgerItemTypeID uniqueidentifier not null,
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
		
	CREATE TABLE #MyResManPricing (
		Sequence int identity,
		PricingBatchID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		UnitID uniqueidentifier not null)	
		
	IF ((SELECT COUNT(*) FROM IntegrationPartnerItemProperty ipip WHERE ipip.PropertyID = @propertyID and ipip.IntegrationPartnerItemID = 72) > 0)
	BEGIN
		SET @isLROIntegrated = 1
	END
	
	-- Get all the UnitIDs		
	INSERT @allUnitIDs 
		SELECT u.UnitID
			FROM Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID						
	
	IF (0 = (SELECT COUNT(*) FROM @unitIDs))
	BEGIN
		IF (0 < (SELECT COUNT(*) FROM @allUnitIDs))
		BEGIN
			-- Get data for all the available units
			INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @allUnitIDs, @date, 0
			INSERT #UnitAmenitiesWithAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @allUnitIDs, @date, 1

			-- Grab available units			
			INSERT #UnitMarketRent1 
				SELECT Units.UnitID, Units.MarketRent FROM 
					(SELECT	u.UnitID AS 'UnitID',
							#ua.UnitStatus,
							#ua.MarketRent,
							pl.LeaseID AS 'PendingLeaseID',
							cl.LeaseID AS 'CurrentLeaseID',
							(SELECT MAX(pl1.MoveOutDate)
								FROM PersonLease pl1
									LEFT JOIN PersonLease plmo ON plmo.LeaseID = pl1.LeaseID AND plmo.MoveOutDate IS NULL AND plmo.ResidencyStatus NOT IN ('Cancelled')
								WHERE pl1.LeaseID = cl.LeaseID
								  AND pl1.ResidencyStatus NOT IN ('Cancelled')
								  AND plmo.PersonLeaseID IS NULL) AS 'MoveOutDate'
						FROM Unit u
							INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
							INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
							LEFT JOIN UnitLeaseGroup culg ON u.UnitID = culg.UnitID AND ((SELECT COUNT(*) FROM Lease WHERE LeaseStatus = 'Current' AND UnitLeaseGroupID = culg.UnitLeaseGroupID) > 0)
							LEFT JOIN UnitLeaseGroup pulg ON u.UnitID = pulg.UnitID	AND ((SELECT COUNT(*) FROM Lease WHERE LeaseStatus IN ('Pending', 'Pending Transfer') AND UnitLeaseGroupID = pulg.UnitLeaseGroupID) > 0)	
							LEFT JOIN Lease cl ON culg.UnitLeaseGroupID = cl.UnitLeaseGroupID AND cl.LeaseStatus = 'Current'
							LEFT JOIN Lease pl ON pulg.UnitLeaseGroupID = pl.UnitLeaseGroupID AND pl.LeaseStatus IN ('Pending', 'Pending Transfer')
							LEFT JOIN [Address] a ON a.AddressID = u.AddressID) Units
					WHERE ((PendingLeaseID IS NULL AND (CurrentLeaseID IS NULL OR MoveOutDate IS NOT NULL)))
					
			-- Store available units					
			INSERT @myUnitIDs SELECT UnitID FROM #UnitMarketRent1
		END
	END
	ELSE
	BEGIN		
		-- Only get data for the units passed in
		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 0
		INSERT #UnitAmenitiesWithAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 1
		
		INSERT INTO #UnitMarketRent1
			SELECT UnitID, MarketRent FROM #UnitAmenities
		
		INSERT @myUnitIDs SELECT UnitID FROM #UnitMarketRent1	
	END
	
	--  Insert into result set the market rent row for each unit in #UnitMarketRent1
	SET @maxAutoMakeReady = (SELECT MAX(DaysToComplete) FROM AutoMakeReady WHERE PropertyID = @propertyID)
	
	INSERT #UnitAvailability 
		SELECT	DISTINCT u.UnitID, u.UnitTypeID, DATEADD(DAY, @maxAutoMakeReady, MAX(plmo.MoveOutDate))
			FROM Unit u
				INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID 
								AND l.LeaseID = (SELECT TOP 1 LeaseID 
													FROM Lease 
													WHERE LeaseID = l.LeaseID
													  AND LeaseStatus IN ('Former', 'Current', 'Evicted')
													ORDER BY DateCreated DESC)
				LEFT JOIN PersonLease plmo ON l.LeaseID = plmo.LeaseID AND plmo.MoveOutDate IS NOT NULL
			WHERE u.UnitID IN (SELECT Value FROM @myUnitIDs)
			GROUP BY u.UnitID, u.UnitTypeID
			
	-- INSERT INTO #UnitAvailabilty rows where @myUnitIDs don't exist yet with an AvailableDate of today
	INSERT #UnitAvailability
		SELECT	DISTINCT myUnits.Value, u.UnitTypeID, GETDATE()
			FROM @myUnitIDs myUnits
				INNER JOIN Unit u ON myUnits.Value = u.UnitID
			WHERE myUnits.Value NOT IN (SELECT UnitID FROM #UnitAvailability)
					
			
	UPDATE #UnitAvailability SET DateAvailable = GETDATE()
		WHERE DateAvailable < GETDATE()
			OR DateAvailable IS NULL

	INSERT #PricingToReturn
		SELECT p.ObjectID, p.LeaseTerm, p.PricingID, p.BaseRent, p.Concession, null, p.EffectiveRent, p.StartDate, p.EndDate, 0, p.Name
			FROM Pricing p
				INNER JOIN PricingBatch pb ON p.PricingBatchID = pb.PricingBatchID AND pb.IsArchived = 0
				INNER JOIN #UnitAvailability #ua ON p.ObjectID = #ua.UnitID				
			WHERE p.ObjectType = 'Unit'
			  AND p.ObjectID IN (SELECT DISTINCT Value FROM @myUnitIDs)
			  AND ((@leaseTerm IS NULL) OR (@leaseTerm = p.LeaseTerm))			  

		  
	
-- Get all the UnitIDs where pricing doesn't already exist
		INSERT @myMissingUnitIDs 
			SELECT Value 
				FROM @myUnitIDs
				WHERE Value NOT IN (SELECT DISTINCT ObjectID FROM #PricingToReturn)
				
-- Determine if we have a #PricingToReturn record for each unit in @myUnitIDs.
	IF ((SELECT COUNT(*) FROM @myUnitIDs) <> (SELECT COUNT(DISTINCT ObjectID) FROM #PricingToReturn))
	BEGIN	
		IF (@isLROIntegrated = 1)
		BEGIN
				
			SET @newPricingBatchID = NEWID()						 
			INSERT PricingBatch	(PricingBatchID, AccountID, IntegrationPartnerID, PropertyID, DatePosted, IsArchived)
				VALUES (@newPricingBatchID, @accountID, 1034, @propertyID, GETDATE(), 0)
				
			INSERT Pricing
				SELECT NEWID(), @accountID, @newPricingBatchID, u.UnitID, 'Unit', p.LeaseTerm, p.StartDate, p.EndDate, p.BaseRent, p.Concession, p.EffectiveRent, 
						p.ConcessionType, p.ConcessionValue, null
					FROM Unit u
						INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
						INNER JOIN Pricing p ON ut.UnitTypeID = p.ObjectID AND p.ObjectType = 'UnitType'
						INNER JOIN PricingBatch pb ON p.PricingBatchID = pb.PricingBatchID AND pb.IsArchived = 0
						INNER JOIN #UnitAvailability #ua ON pb.DatePosted = #ua.DateAvailable
					WHERE u.UnitID IN (SELECT Value FROM @myMissingUnitIDs)
					  AND #ua.DateAvailable >= p.StartDate AND #ua.DateAvailable <= p.EndDate

		END  -- End Property IS integrated with LRO
		ELSE				-- Property is NOT integrated with LRO, use ResMan pricing!
		BEGIN			

			INSERT #MyResManPricing
				SELECT NEWID(), u.UnitTypeID, u.UnitID
					FROM Unit u
						INNER JOIN @myMissingUnitIDs myMissingUnits ON u.UnitID = myMissingUnits.Value

			INSERT Pricing
				SELECT	NEWID(),
						@accountID,
						#myPricing.PricingBatchID,
						#myPricing.UnitID,
						'Unit',
						lt.Months,
						NULL,
						NULL,
						CASE
							WHEN (utlt.[Round] = 1)
								THEN ROUND((#umr.MarketRent +
												CASE						-- Factor in the Concession value
													WHEN (utlt.IsPercentage = 1) THEN
														#umr.MarketRent * (utlt.Amount/100.0)
													ELSE
														utlt.Amount
													END), 0)
								ELSE (#umr.MarketRent +
												CASE						-- Factor in the Concession value
													WHEN (utlt.IsPercentage = 1) THEN
														#umr.MarketRent * (utlt.Amount/100.0)
													ELSE
														utlt.Amount
													END)
							END AS 'BaseRent',
						0 AS 'Concession',							
						0 AS 'EffectiveRent',
						NULL,
						0 AS 'ConcessionValue',
						lt.Name											
					FROM #MyResManPricing #myPricing
						INNER JOIN #UnitMarketRent1 #umr ON #myPricing.UnitID = #umr.UnitID
						INNER JOIN UnitTypeLeaseTerm utlt ON #myPricing.UnitTypeID = utlt.UnitTypeID
						INNER JOIN LeaseTerm lt ON utlt.LeaseTermID = lt.LeaseTermID AND lt.IsFixed = 0
						
			IF (@@ROWCOUNT > 0)
			BEGIN
				INSERT PricingBatch
					SELECT #myPricing.PricingBatchID, @accountID, null, @propertyID, GETDATE(), 0
						FROM #MyResManPricing #myPricing
			END						

		END  -- End ELSE WE ARE NOT integrated with LRO
	END  -- End we have UnitIDs in the collection @myMissingUnitIDs
	
	INSERT #PricingToReturn
		SELECT p.ObjectID, p.LeaseTerm, p.PricingID, p.BaseRent, p.Concession, null, p.EffectiveRent, p.StartDate, p.EndDate, 0, p.Name
			FROM Pricing p
				INNER JOIN PricingBatch pb ON p.PricingBatchID = pb.PricingBatchID AND pb.IsArchived = 0
			WHERE p.ObjectType = 'Unit'
			  AND p.ObjectID IN (SELECT DISTINCT Value FROM @myMissingUnitIDs)
			  AND ((@leaseTerm IS NULL) OR (@leaseTerm = p.LeaseTerm))				
	
	IF (@isLROIntegrated = 0)
	BEGIN
		-- ADD a row for MarketRent & Fixed Lease Terms ALWAYS to be returned.
		INSERT #PricingToReturn
			SELECT	u.UnitID, null, null, #umr.MarketRent, 0.00, 0.00, #umr.MarketRent, null, null, 0, 'MarketRent'
				FROM @myUnitIDs myUnits
					INNER JOIN Unit u ON myUnits.Value = u.UnitID
					INNER JOIN #UnitMarketRent1 #umr ON u.UnitID = #umr.UnitID
					
		INSERT #PricingToReturn
			SELECT	u.UnitID, lt.Months, null, #umr.MarketRent, 0.00, 0.00, #umr.MarketRent, lt.StartDate, lt.EndDate, ISNULL(lt.IsFixed, CAST(0 AS bit)), lt.Name
				FROM @myUnitIDs myUnits
					INNER JOIN Unit u ON myUnits.Value = u.UnitID
					INNER JOIN #UnitMarketRent1 #umr ON u.UnitID = #umr.UnitID
					INNER JOIN PropertyLeaseTerm plt ON plt.PropertyID = @propertyID
					INNER JOIN LeaseTerm lt ON lt.LeaseTermID = plt.LeaseTermID AND lt.IsFixed = 1 
				WHERE lt.StartDate >= CAST(GETDATE() AS date)
					
		UPDATE #ptr SET ExtraAmenitiesAmount = ISNULL((#uawa.MarketRent - #ua.MarketRent), 0), EffectiveRent = BaseRent + ISNULL((#uawa.MarketRent - #ua.MarketRent), 0)
			FROM #PricingToReturn #ptr
				INNER JOIN #UnitAmenities #ua ON #ptr.ObjectID = #ua.UnitID
				INNER JOIN #UnitAmenitiesWithAmenities #uawa ON #ptr.ObjectID = #uawa.UnitID
									
	END			
	
	SELECT *
		FROM #PricingToReturn
		ORDER BY ObjectID, IsFixed, LeaseTerm
	
END
GO
