SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 24, 2012
-- Description:	Generates the data for the RentRoll report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_FutureRentRoll] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date datetime = null,
	@excludeExpiringLeasesNotOnNotice bit = 0
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
		UnitID uniqueidentifier null)
		
		
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

	
	CREATE TABLE #LeasedUnits 
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		Number nvarchar(100),
		LeaseID uniqueidentifier
	)

	INSERT INTO #LeasedUnits
		SELECT b.PropertyID, u.UnitID, u.Number, l.LeaseID 
		FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN #Properties prop ON prop.PropertyID = b.PropertyID
		WHERE l.LeaseStatus IN ('Pending', 'Pending Renewal', 'Pending Transfer')
			AND l.LeaseStartDate <= @date
			AND u.IsHoldingUnit = 0
			AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)

	INSERT INTO #LeasedUnits
		SELECT DISTINCT b.PropertyID, u.UnitID, u.Number, l.LeaseID 
		FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.MoveOutDate IS NULL
			INNER JOIN #Properties prop ON prop.PropertyID = b.PropertyID
		WHERE l.LeaseStatus IN ('Current', 'Under Eviction')
			AND l.LeaseStartDate <= @date
			AND u.IsHoldingUnit = 0
			AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
			-- There is someone without a move out date or the move out date is 
			-- after the date
			AND (plmo.PersonLeaseID IS NOT NULL OR
				 (SELECT MAX(pl2.MoveOutDate) 
				  FROM PersonLease pl2
				  WHERE pl2.LeaseID = l.LeaseID) > @date)
			AND u.UnitID NOT IN (SELECT UnitID FROM #LeasedUnits)
			AND (@excludeExpiringLeasesNotOnNotice = 0 OR (@excludeExpiringLeasesNotOnNotice = 1 AND l.LeaseEndDate > @date))

	INSERT INTO #RentRoll
		SELECT 
			p.PropertyID,
			p.Name,
			ulg.UnitLeaseGroupID,
			l.LeaseID,
			l.LeaseStatus,
			u.Number AS 'Unit',
			u.PaddedNumber AS 'PaddedUnit',			
			ut.Name AS 'UnitType',
			null AS 'UnitStatus',				
			u.SquareFootage AS 'SquareFootage',
			STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					FROM Person 
						INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					WHERE PersonLease.LeaseID = l.LeaseID
						AND PersonType.[Type] = 'Resident'				   
						AND PersonLease.MainContact = 1				   
					FOR XML PATH ('')), 1, 2, ''),
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
			lli.StartDate,
			lli.EndDate,
			lit.LedgerItemTypeID,
			lit.Name,
			lli.[Description],
			lli.Amount,
			ISNULL(lit.IsCharge, CAST(0 AS BIT)),		
			ISNULL(lit.IsRent, CAST(0 AS BIT)),			
			0 AS 'DepositsHeld',			
			#ua.MarketRent AS 'MarketRent',				
			0 AS 'Balance',			
			CASE 				
				WHEN lit.IsRent = 1 THEN 0
				WHEN lit.IsCharge = 1 THEN 1
				ELSE 2
			END,
			u.UnitID AS 'UnitID'
		FROM Lease l
			INNER JOIN LeaseLedgerItem lli ON lli.LeaseID = l.LeaseID AND lli.StartDate <= @date AND lli.EndDate >= @date
			INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
			INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID AND (lit.IsCredit = 1 OR lit.IsCharge = 1)
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			INNER JOIN Property p ON p.PropertyID = b.PropertyID
			INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
			INNER JOIN #Properties prop ON prop.PropertyID = p.PropertyID
			INNER JOIN #LeasedUnits #l ON #l.LeaseID = l.LeaseID
		
		INSERT INTO #RentRoll		
			SELECT
					p.PropertyID,
					p.Name AS 'PropertyName',
					null AS 'UnitLeaseGroupID',
					null AS 'LeaseID',
					null AS 'LeaseStatus',
					u.Number AS 'Unit',
					u.PaddedNumber AS 'PaddedUnit',
					ut.Name AS 'UnitType',
					--US.[Status] AS 'UnitStatus',
					null AS 'UnitStatus',
					--ut.SquareFootage AS 'SquareFootage',
					u.SquareFootage AS 'SquareFootage',
					null AS 'Residents',
					null AS 'MoveInDate',
					null AS 'LeaseStartDate',
					null AS 'LeaseEndDate',
					CAST(0 AS BIT) AS 'LeaseSigned',
					null AS 'MoveOutDate',
					null AS 'LeaseLedgerItemStartDate',
					null AS 'LeaseLedgerItemEndDate',
					null AS 'LedgerItemTypeID',
					null AS 'LedgerItemTypeName',
					null AS 'Description',
					0 AS 'Amount',
					CAST(0 as bit) AS 'IsCharge',
					CAST(0 as bit) AS 'IsRent',
					0 AS 'DepositsHeld',
					--ut.MarketRent AS 'MarketRent',
					#ua.MarketRent AS 'MarketRent',
					0 AS 'Balance',
					2 AS 'OrderBy',
					u.UnitID AS 'UnitID'
				FROM Unit u
					INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
					INNER JOIN Property p ON ut.PropertyID = p.PropertyID
					INNER JOIN #Properties prop ON prop.PropertyID = p.PropertyID					
				WHERE u.IsHoldingUnit = 0
					AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
					AND ((SELECT COUNT(*) FROM #RentRoll
						WHERE #RentRoll.UnitID = u.UnitID) = 0)


	
-- Add Non-Resident recurring charges to the Rent Roll report.
	INSERT #RentRoll
		SELECT	p.PropertyID,
				p.Name AS 'PropertyName',
				per.PersonID AS 'UnitLeaseGroupID',
				per.PersonID AS 'LeaseID',
				'Non-Resident' AS 'LeaseStatus',
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
				null AS 'UnitID'
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

	SELECT * FROM #RentRoll														 			  
		  ORDER BY PaddedUnit, LeaseStatus, OrderBy
	
END
GO
