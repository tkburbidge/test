SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[ExpiredLeasesNotAtMarketRent]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection readonly,
	@date date
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #ExpiredLeases
	(
		LeaseID uniqueidentifier,
		LeaseStartDate date,
		LeaseEndDate date,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(100),
		RentCharge money,		
		ResidentNames nvarchar(500),
		PropertyID uniqueidentifier,
		PropertyAbbreviation nvarchar(10)
	)
	
	INSERT INTO #ExpiredLeases
		SELECT l.LeaseID, l.LeaseStartDate, l.LeaseEndDate, u.UnitID, u.Number, 0,  		
		STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				 WHERE PersonLease.LeaseID = l.LeaseID
					   AND PersonType.[Type] = 'Resident'				   
					   AND PersonLease.MainContact = 1				   
				 FOR XML PATH ('')), 1, 2, '') AS 'ResidentNames',
		p.PropertyID,
		p.Abbreviation
		FROM Lease l
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u ON u.UnitID = ulg.UnitID
		INNER JOIN Building b ON b.BuildingID = u.BuildingID
		INNER JOIN Property p ON p.PropertyID = b.PropertyID	
		WHERE l.AccountID = @accountID 
			AND l.LeaseStatus IN ('Current', 'Under Eviction')
			AND l.LeaseEndDate < @date
			AND b.PropertyID in (SELECT Value FROM @propertyIDs)
			
	UPDATE #ExpiredLeases SET RentCharge = ISNULL((SELECT SUM(ISNULL(lli.Amount, 0))
													FROM LeaseLedgerItem lli
														INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
														INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
													WHERE lli.LeaseID = #ExpiredLeases.LeaseID
														AND lit.IsRent = 1
														AND lli.StartDate <= @date
														AND lli.EndDate >= @date), 0)
												
	DECLARE @unitIDs GuidCollection
	INSERT INTO @unitIDs SELECT UnitID FROM #ExpiredLeases
	
	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		UnitStatus nvarchar(200) not null,
		UnitStatusLedgerItemTypeID uniqueidentifier not null,
		RentLedgerItemTypeID uniqueidentifier not null,
		MarketRent decimal null,
		Amenities nvarchar(MAX) null)
		
	CREATE TABLE #PropertyIDs (Sequence int identity, PropertyID uniqueidentifier null)
	INSERT #PropertyIDs SELECT * FROM @propertyIDs
	DECLARE @i int = 1
	DECLARE @maxI int = (SELECT Max(Sequence) FROM #PropertyIDs)
	DECLARE @propertyID uniqueidentifier

	WHILE (@i <= @maxI)
	BEGIN
		SET @propertyID = (SELECT PropertyID FROM #PropertyIDs WHERE Sequence = @i)

		INSERT #UnitAmenities 
			EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date

		SET @i = @i + 1
	END
	
	SELECT #el.LeaseID, #el.UnitNumber, #el.ResidentNames, #el.LeaseStartDate, #el.LeaseEndDate, #el.RentCharge, #ua.MarketRent, #el.PropertyID, #el.PropertyAbbreviation
	FROM #ExpiredLeases #el
		INNER JOIN #UnitAmenities #ua ON #ua.UnitID = #el.UnitID
	WHERE #el.RentCharge <> #ua.MarketRent		
	
    
END   

GO
