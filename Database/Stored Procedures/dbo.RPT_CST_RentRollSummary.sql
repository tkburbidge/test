SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 18, 2016
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_RentRollSummary] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @accountID bigint
	SELECT @accountID = AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs)

	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		UnitStatus nvarchar(200) not null,
		UnitStatusLedgerItemTypeID uniqueidentifier not null,
		RentLedgerItemTypeID uniqueidentifier not null,
		MarketRent money null,
		Amenities nvarchar(MAX) null)
		
	CREATE TABLE #Properties (
		Sequence int identity not null,
		PropertyID uniqueidentifier not null)
		
	CREATE TABLE #RentRoll (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		UnitLeaseGroupID uniqueidentifier null,
		LeaseID uniqueidentifier null,
		LeaseStatus nvarchar(100) null,
		CurrentLeaseStatus nvarchar(100) null,
		Unit nvarchar(50) null,
		PaddedUnit nvarchar(100) null,
		UnitType nvarchar(100) null,
		UnitStatus nvarchar(50) null,
		SquareFootage int null,
		Residents nvarchar(200) null,
		MoveInDate date null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		LeaseSigned bit null,
		MoveOutDate date null,
		LeaseLedgerItemStartDate date null,
		LeaseLedgerItemEndDate date null,
		LedgerItemTypeID uniqueidentifier null,
		LedgerItemTypeName nvarchar(50) null,
		[Description] nvarchar(500) null,
		Amount money null,
		IsCharge bit null,
		IsRent bit null,
		DepositsHeld money null,
		MarketRent money null,
		Balance money null,
		OrderBy int null,
		UnitID uniqueidentifier null,
		SuretyBondsTotal money null)
		
	CREATE TABLE #RROccupants 
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null,
		LeaseID uniqueidentifier null			
	)
    
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
		[Floor] smallint,
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

	CREATE TABLE #RROccupants2 
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null				
	)

	CREATE TABLE #Buildings ( 
		BuildingID uniqueidentifier,
		PropertyID uniqueidentifier,
		Floors smallint,
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
		Bathrooms int,
		[Description] nvarchar(500),
		MarketRent money,
		RequiredDeposit money,
		MarketingDescription nvarchar(500),
		Notes nvarchar(MAX) )
    

		
	DECLARE @propertyID uniqueidentifier, @ctr int = 1, @maxCtr int, @unitIDs GuidCollection
	
	INSERT #Properties SELECT Value FROM @propertyIDs
	SET @maxCtr = (SELECT MAX(Sequence) FROM #Properties)
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @propertyID = PropertyID FROM #Properties WHERE Sequence = @ctr
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
						WHERE u.IsHoldingUnit = 0
							AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 0
		SET @ctr = @ctr + 1
	END	


	INSERT INTO #RROccupants2
		EXEC GetOccupantsByDate @accountID, @date, @propertyIDs
						
	INSERT INTO #RROccupants
		SELECT *, null FROM #RROccupants2

	-- Get the last lease where the date is in the lease date range
	UPDATE rro
			SET LeaseID = l.LeaseID				 
	FROM #RROccupants rro
		INNER JOIN Lease l ON l.UnitLeaseGroupID = rro.UnitLeaseGroupID
	WHERE rro.UnitLeaseGroupID IS NOT NULL
		AND (l.LeaseID = (SELECT TOP 1 LeaseID			
							FROM Lease 								
							WHERE UnitLeaseGroupID = l.UnitLeaseGroupID
								AND LeaseStartDate <= @date
								AND LeaseEndDate >= @date
								AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
							ORDER BY DateCreated DESC))
		
	-- Get the last lease where the EndDate <= @date (Month-to-Month Leases) 
	UPDATE rro
			SET LeaseID = l.LeaseID				 
	FROM #RROccupants rro
		INNER JOIN Lease l ON l.UnitLeaseGroupID = rro.UnitLeaseGroupID
	WHERE rro.UnitLeaseGroupID IS NOT NULL
		AND rro.LeaseID IS NULL
		AND (l.LeaseID = (SELECT TOP 1 LeaseID			
							FROM Lease 								
							WHERE UnitLeaseGroupID = l.UnitLeaseGroupID								  
								AND LeaseEndDate <= @date
								AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
							ORDER BY LeaseEndDate DESC))
		 

	-- For the messed up lease entries, grab the first lease
	-- associated with the UnitLeaseGroup
	UPDATE rro
			SET LeaseID = l.LeaseID				 				 
	FROM #RROccupants rro
		INNER JOIN Lease l ON l.UnitLeaseGroupID = rro.UnitLeaseGroupID
	WHERE rro.UnitLeaseGroupID IS NOT NULL
		AND rro.LeaseID IS NULL
		AND (l.LeaseID = (SELECT TOP 1 LeaseID			
							FROM Lease 
							WHERE UnitLeaseGroupID = l.UnitLeaseGroupID							 
							AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
							ORDER BY LeaseStartDate))			 

	INSERT INTO #RentRoll
	SELECT 
			p.PropertyID,
			p.Name AS 'PropertyName',
			CASE 
				WHEN (ulg.UnitLeaseGroupID IS NULL) THEN NULL
				ELSE ulg.UnitLeaseGroupID 
				END AS 'UnitLeaseGroupID',

			CASE
				WHEN (l.LeaseID IS NULL) THEN NULL
				ELSE l.LeaseID
				END AS 'LeaseID',
			CASE 
				WHEN (l.LeaseID IS NULL) THEN NULL
				ELSE 'Current' --l.LeaseStatus
				END AS 'LeaseStatus',
			CASE 
				WHEN (l.LeaseID IS NULL) THEN NULL
				ELSE l.LeaseStatus
				END AS 'CurrentLeaseStatus',
			u.Number AS 'Unit',
			u.PaddedNumber AS 'PaddedUnit',			
			ut.Name AS 'UnitType',
			--US.[Status] AS 'UnitStatus',
			null AS 'UnitStatus',
			--ut.SquareFootage AS 'SquareFootage',
			u.SquareFootage AS 'SquareFootage',

			CASE
				WHEN (l.LeaseID IS NULL) THEN null
				ELSE STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
							FROM Person 
								INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
								INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
								INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
							WHERE PersonLease.LeaseID = l.LeaseID
								AND PersonType.[Type] = 'Resident'				   
								AND PersonLease.MainContact = 1				   
							FOR XML PATH ('')), 1, 2, '')
				END AS 'Residents',
			(SELECT MIN(pl.MoveInDate)
				FROM PersonLease pl
				WHERE pl.LeaseID = l.LeaseID) AS 'MoveInDate',
			l.LeaseStartDate AS 'LeaseStartDate',
			l.LeaseEndDate AS 'LeaseEndDate',
			CAST(1 AS BIT) AS 'LeaseSigned',
			(SELECT MAX(pl.MoveOutDate)
				FROM PersonLease pl
					INNER JOIN Lease l1 ON pl.LeaseID = l1.LeaseID
					LEFT JOIN PersonLease pl1 ON l1.LeaseID = pl1.LeaseID AND pl1.MoveOutDate IS NULL
				WHERE l1.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					AND pl1.PersonLeaseID IS NULL
					AND pl.LeaseID = l.LeaseID) AS 'MoveOutDate',				
			CASE 
				WHEN (l.LeaseID IS NULL) THEN NULL
				ELSE lli.StartDate
				END AS 'LeaseLedgerItemStartDate',
			CASE 
				WHEN (l.LeaseID IS NULL) THEN NULL
				ELSE lli.EndDate
				END AS 'LeaseLedgerItemEndDate',
			CASE 
				WHEN (l.LeaseID IS NULL) THEN NULL
				ELSE lit.LedgerItemTypeID
				END AS 'LedgerItemTypeID',
			CASE 
				WHEN (l.LeaseID IS NULL) THEN NULL
				ELSE lit.Name
				END AS 'LedgerItemTypeName',

			CASE
				WHEN (l.LeaseID IS NULL) THEN NULL
				ELSE lli.[Description]
				END AS 'Description',			

			CASE
				WHEN (l.LeaseID IS NULL) THEN 0
				ELSE ISNULL(lli.Amount, 0)
				END AS 'Amount',
			CASE 
				WHEN (l.LeaseID IS NULL) THEN CAST(0 AS BIT)
				ELSE ISNULL(lit.IsCharge, CAST(0 AS BIT))
				END AS 'IsCharge',
			CASE 
				WHEN (l.LeaseID IS NULL) THEN CAST(0 AS BIT)
				ELSE ISNULL(lit.IsRent, CAST(0 AS BIT))
				END AS 'IsRent',
			((SELECT ISNULL(SUM(t.Amount), 0)
				FROM [Transaction] t
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				WHERE t.ObjectID = ulg.UnitLeaseGroupID
					AND tt.Name IN ('Deposit', 'Balance Transfer Deposit', 'Deposit Applied to Deposit')) -
				(SELECT ISNULL(SUM(tb.Amount), 0)
					FROM [Transaction] tb
						INNER JOIN TransactionType ttb ON tb.TransactionTypeID = ttb.TransactionTypeID
					WHERE tb.ObjectID = ulg.UnitLeaseGroupID
						AND ttb.Name IN ('Deposit Refund'))) AS 'DepositsHeld',
			--(ISNULL((SELECT TOP 1 ISNULL(Amount, 0) FROM GetLatestMarketRentByUnitTypeID(ut.UnitTypeID, @date) ORDER BY DateEntered DESC), 0)) As 'MarketRent',
			--MR.Amount AS 'MarketRent'
			#ua.MarketRent AS 'MarketRent',				
			0 AS 'Balance',
			CASE WHEN (l.LeaseID IS NULL) THEN 0


			ELSE
				CASE 				
					WHEN lit.IsRent = 1 THEN 0
					WHEN lit.IsCharge = 1 THEN 1
					ELSE 2
					END
				END AS 'OrderBy',
			u.UnitID AS 'UnitID',
			0 AS 'SuretyBondsTotal'
		FROM Unit u
			INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN #Properties prop ON prop.PropertyID = p.PropertyID
			LEFT JOIN #RROccupants #rro ON #rro.UnitID = u.UnitID
			LEFT JOIN UnitLeaseGroup ulg ON ulg.UnitleaseGroupID = #rro.UnitLeaseGroupID
			LEFT JOIN Lease l ON #rro.LeaseID = l.LeaseID
			LEFT JOIN LeaseLedgerItem lli ON l.LeaseID = lli.LeaseID AND lli.StartDate <= @date AND lli.EndDate >= @date
								-- Don't pull back any deposit LeaseLedgerItems
												AND (SELECT lit2.IsDeposit
														FROM LedgerItem li2 
														INNER JOIN LedgerItemType lit2 ON lit2.LedgerItemTypeID = li2.LedgerItemTypeID
														WHERE li2.LedgerItemID = lli.LedgerItemID) = 0
			LEFT JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
			LEFT JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
		WHERE ((lit.LedgerItemTypeID IS NULL) OR (lit.IsDeposit = 0))				
	
-- Add Non-Resident recurring charges to the Rent Roll report.
	INSERT #RentRoll
		SELECT	p.PropertyID,
				p.Name AS 'PropertyName',
				per.PersonID AS 'UnitLeaseGroupID',
				per.PersonID AS 'LeaseID',
				'Non-Resident' AS 'LeaseStatus',
				'Non-Resident' AS 'CurrentLeaseStatus',
				null AS 'Unit',
				null AS 'PaddedUnit',
				null AS 'UnitType',
				null AS 'UnitStatus',
				0 AS 'SquareFootage',
				per.PreferredName + ' ' + per.LastName AS 'Residents',
				null AS 'MoveInDate',
				null AS 'LeaseStartDate',
				null AS 'LeaseEndDate',
				0 AS 'LeaseSigned',
				null AS 'MoveOutDate',
				nrli.StartDate AS 'LeaseLedgerItemStartDate',
				nrli.EndDate AS 'LeaseLedgerItemEndDate',
				lit.LedgerItemTypeID,
				lit.Name AS 'LedgerItemTypeName',
				nrli.[Description] AS 'Description',
				nrli.Amount AS 'Amount',
				ISNULL(lit.IsCharge, CAST(0 AS BIT)) AS 'IsCharge',
				CAST(0 AS BIT) AS 'IsRent',
				0 AS 'DepositsHeld',
				0 AS 'MarketRent',
				0 AS 'Balance',
				1 AS 'OrderBy',
				null AS 'UnitID',
				0 AS 'SuretyBondsTotal'
			FROM NonResidentLedgerItem nrli
				INNER JOIN Person per ON nrli.PersonID = per.PersonID
				INNER JOIN LedgerItem li ON nrli.LedgerItemID = li.LedgerItemID
				INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID	
				INNER JOIN PersonType pt ON per.PersonID = pt.PersonID AND pt.[Type] = 'Non-Resident Account'
				INNER JOIN PersonTypeProperty ptp ON pt.PersonTypeID = ptp.PersonTypeID
				INNER JOIN Property p ON ptp.PropertyID = p.PropertyID
				INNER JOIN #Properties prop ON prop.PropertyID = p.PropertyID
			WHERE nrli.StartDate <= @date
			  AND nrli.EndDate >= @date

	-- Calculate deposits
	UPDATE #RentRoll SET DepositsHeld = ((SELECT ISNULL(SUM(t.Amount), 0)
											FROM [Transaction] t
												INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
											WHERE t.ObjectID = #RentRoll.UnitLeaseGroupID
											  AND tt.Name IN ('Deposit', 'Balance Transfer Deposit', 'Deposit Applied to Deposit')
											  AND t.TransactionDate <= @date) -
											(SELECT ISNULL(SUM(tb.Amount), 0)
												FROM [Transaction] tb
													INNER JOIN TransactionType ttb ON tb.TransactionTypeID = ttb.TransactionTypeID
												WHERE tb.ObjectID = #RentRoll.UnitLeaseGroupID
												  AND ttb.Name IN ('Deposit Refund')
												  AND tb.TransactionDate <= @date))
												  
	-- Surety bonds
	UPDATE #RentRoll SET SuretyBondsTotal = (SELECT ISNULL(SUM(ISNULL(sb.Coverage, 0) + ISNULL(sb.PetCoverage, 0)), 0)
												FROM SuretyBond sb
												WHERE sb.UnitLeaseGroupID = #RentRoll.UnitLeaseGroupID
												  AND sb.PaidDate <= @date)

	CREATE TABLE #Balances (
		UnitLeaseGroupID uniqueidentifier,
		Balance money
	)

	INSERT INTO #Balances
		SELECT DISTINCT UnitLeaseGroupID, 0
		FROM #RentRoll
		WHERE UnitLeaseGroupID IS NOT NULL
		
	UPDATE #Balances SET Balance = CurBal.Balance
		FROM #Balances
			CROSS APPLY GetObjectBalance(null, @date, #Balances.UnitLeaseGroupID, 0, @propertyIDs) AS [CurBal]
			
	UPDATE #rr SET Balance = ISNULL(#b.Balance, 0)
		FROM #RentRoll #rr
		LEFT JOIN #Balances #b ON #b.UnitLeaseGroupID = #rr.UnitLeaseGroupID
				
	UPDATE #rr SET UnitStatus = Stat.[Status]
		FROM #RentRoll #rr
			CROSS APPLY GetUnitStatusByUnitID(#rr.UnitID, null) AS [Stat]

	INSERT #Buildings
		EXEC [RPT_CSTM_PRTY_BuildingInfo] @propertyIDs, @date
	
	INSERT #UnitType
		EXEC [RPT_CSTM_PRTY_UnitType] @propertyIDs, @date

	INSERT #Property
		EXEC [RPT_CSTM_PRTY_PropertyInfo] @propertyIDs, @date

	INSERT #Unit
		EXEC [RPT_CSTM_PRTY_Unit] @propertyIDs, @date, 1

	SELECT * FROM #RentRoll														 			  
		  ORDER BY PaddedUnit, LeaseStatus, OrderBy

	SELECT * FROM #Buildings

	SELECT * FROM #UnitType

	SELECT * FROM #Property

	SELECT * FROM #Unit
END
GO
