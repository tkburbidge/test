SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_TNS_RentRoll]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@date datetime = null,
	@postRecurringChargesVerification bit = 0,
	@isAffordable bit = 0,
	@customCharges bit = 0,
	@isRentRollUnitTypeSummary bit = 0
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
		Building nvarchar(15) null,
		PaddedUnit nvarchar(100) null,
		UnitType nvarchar(100) null,
		UnitStatus nvarchar(50) null,
		SquareFootage int null,
		Residents nvarchar(2000) null,
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
		SuretyBondsTotal money null,
		IsRentalAssistance bit null,
		PostToHapLedger bit not null)

	CREATE TABLE #AffordableData (
		LeaseID uniqueidentifier not null,
		CertificationType nvarchar(50) not null,
		CertificationEffectiveDate date not null,
		RecertificationDate date not null,
		UtilityAllowance int null,
		HudTotalTenantPayment money null,
		HudContractRent int null,
		IsHud bit not null,
		TaxCreditTenantRent money null,
		HudTenantRent money null
	)


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

	IF (@postRecurringChargesVerification = 1)
	BEGIN
	INSERT #RentRoll
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
					ELSE l.LeaseStatus
					END AS 'LeaseStatus',
				CASE
					WHEN (l.LeaseID IS NULL) THEN NULL
					ELSE l.LeaseStatus
					END AS 'CurrentLeaseStatus',
				u.Number AS 'Unit',
				b.Name AS 'Building',
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
				0 AS 'DepositsHeld',
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
				0 AS 'SuretyBondsTotal',
				0 AS 'IsRentalAssistance',
				ISNULL(lli.PostToHapLedger, 0) AS 'PostToHapLedger'
			FROM Unit u
				INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON b.PropertyID = p.PropertyID
				INNER JOIN #Properties prop ON prop.PropertyID = p.PropertyID
				--CROSS APPLY GetUnitStatusByUnitID(u.UnitID, null) AS US
				LEFT JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID AND ((SELECT COUNT(*) FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID AND LeaseStatus IN ('Current', 'Under Eviction', 'Pending', 'Pending Transfer')) > 0)
				LEFT JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				LEFT JOIN LeaseLedgerItem lli ON l.LeaseID = lli.LeaseID AND l.LeaseStatus IN ('Current', 'Under Eviction') AND lli.StartDate <= @date AND lli.EndDate >= @date
				LEFT JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
				LEFT JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
				--OUTER APPLY GetObjectBalance(null, @date, l.UnitLeaseGroupID, 0, @propertyIDs) AS EB

			WHERE ((lit.LedgerItemTypeID IS NULL) OR (lit.IsDeposit = 0))
			  AND ulg.UnitLeaseGroupID IS NOT NULL
			  AND u.IsHoldingUnit = 0
			  AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
			  AND ((l.LeaseID IS NULL) OR (l.LeaseStatus IN ('Current', 'Under Eviction')))
			  AND ((l.LeaseID IS NULL) OR (l.LeaseID = (SELECT TOP 1 LeaseID
															FROM Lease
															WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
															  AND LeaseStatus IN ('Current', 'Under Eviction')
															ORDER BY LeaseEndDate DESC)))


		UNION ALL


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
					ELSE l.LeaseStatus
					END AS 'LeaseStatus',
				CASE
					WHEN (l.LeaseID IS NULL) THEN NULL
					ELSE l.LeaseStatus
					END AS 'CurrentLeaseStatus',
				u.Number AS 'Unit',
				b.Name AS 'Building',
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
				(CASE WHEN (SELECT COUNT(*)
						    FROM PersonLease pl
							WHERE pl.LeaseSignedDate IS NOT NULL
								AND pl.LeaseID = l.LeaseID) > 0 THEN CAST(1 AS BIT)
					  ELSE CAST(0 AS BIT)
				 END) AS 'LeaseSigned',
				(SELECT MAX(pl.MoveOutDate)
					FROM PersonLease pl
						INNER JOIN Lease l1 ON pl.LeaseID = l1.LeaseID
						LEFT JOIN PersonLease pl1 ON l1.LeaseID = pl1.LeaseID AND pl1.MoveOutDate IS NULL
					WHERE l1.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					  AND pl1.PersonLeaseID IS NOT NULL
					  AND l1.LeaseID = l.LeaseID) AS 'MoveOutDate',
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
				#ua.MarketRent AS 'MarketRent',
				--CASE
				--	WHEN (l.LeaseID IS NULL) THEN 0
				--	ELSE ISNULL(EB.Balance, 0)
				--	END AS 'Balance',
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
				0 AS 'SuretyBondsTotal',
				0 AS 'IsRentalAssistance',
				ISNULL(lli.PostToHapLedger, 0) AS 'PostToHapLedger'
			FROM Unit u
				INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON b.PropertyID = p.PropertyID
				INNER JOIN #Properties prop ON prop.PropertyID = p.PropertyID
				--CROSS APPLY GetUnitStatusByUnitID(u.UnitID, null) AS US
				LEFT JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID AND ((SELECT COUNT(*) FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID AND LeaseStatus IN ('Pending Renewal')) > 0)
				LEFT JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				LEFT JOIN LeaseLedgerItem lli ON l.LeaseID = lli.LeaseID AND l.LeaseStatus IN ('Pending Renewal') --AND lli.StartDate <= @date AND lli.EndDate >= @date
				LEFT JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
				LEFT JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
				--OUTER APPLY GetObjectBalance(null, @date, l.UnitLeaseGroupID, 0, @propertyIDs) AS EB

			WHERE ((lit.LedgerItemTypeID IS NULL) OR (lit.IsDeposit = 0))
			  AND ulg.UnitLeaseGroupID IS NOT NULL
			  AND u.IsHoldingUnit = 0
			  AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
			  AND ((l.LeaseID IS NULL) OR (l.LeaseStatus IN ('Pending Renewal')))
			  AND ((l.LeaseID IS NULL) OR (l.LeaseID = (SELECT TOP 1 LeaseID
															FROM Lease
															WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
															  AND LeaseStatus IN ('Pending Renewal')
															ORDER BY LeaseEndDate DESC)))



	-- Remove any rows were a move out date is specified and
	-- and it is before the date of posting the charges
	DELETE FROM #RentRoll
	WHERE MoveOutDate IS NOT NULL
		AND MoveOutDate < @date

	INSERT INTO #RentRoll
		SELECT
				p.PropertyID,
				p.Name AS 'PropertyName',
				null AS 'UnitLeaseGroupID',
				null AS 'LeaseID',
				null AS 'LeaseStatus',
				null AS 'CurrentLeaseStatus',
				u.Number AS 'Unit',
				b.Name AS 'Building',
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
				u.UnitID AS 'UnitID',
				0 AS 'SuretyBondsTotal',
				0 AS 'IsRentalAssistance',
				0 AS 'PostToHapLedger'
			FROM Unit u
				INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				INNER JOIN #Properties prop ON prop.PropertyID = p.PropertyID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				LEFT JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID AND ((SELECT COUNT(*) FROM Lease WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID AND LeaseStatus IN ('Current', 'Under Eviction')) > 0)
				LEFT JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')
				--CROSS APPLY GetUnitStatusByUnitID(u.UnitID, null) AS US
			WHERE l.LeaseID IS NULL
				AND u.IsHoldingUnit = 0
				AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
				OR ((SELECT COUNT(*) FROM #RentRoll
					WHERE #RentRoll.UnitID = u.UnitID
						AND #RentRoll.LeaseStatus IN ('Current', 'Under Eviction')) = 0)


	END
	ELSE
	BEGIN

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

		CREATE TABLE #RROccupants2
		(
			PropertyID uniqueidentifier,
			UnitID uniqueidentifier,
			UnitNumber nvarchar(50) null,
			UnitLeaseGroupID uniqueidentifier null,
			MoveInDate date null,
			MoveOutDate date null
		)

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
				b.Name AS 'Building',
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
				0 AS 'SuretyBondsTotal',
				CASE
					WHEN (l.LeaseID IS NULL) THEN CAST(0 AS BIT)
					ELSE ISNULL(lli.RentalAssistanceCharge, CAST(0 AS BIT))
					END AS 'IsRentalAssistance',
				ISNULL(lli.PostToHapLedger, 0) AS 'PostToHapLedger'
			FROM Unit u
				INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON b.PropertyID = p.PropertyID
				INNER JOIN #Properties prop ON prop.PropertyID = p.PropertyID
				LEFT JOIN #RROccupants #rro ON #rro.UnitID = u.UnitID
				LEFT JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = #rro.UnitLeaseGroupID
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

	END

-- Add Non-Resident recurring charges to the Rent Roll report.
	INSERT #RentRoll
		SELECT	p.PropertyID,
				p.Name AS 'PropertyName',
				per.PersonID AS 'UnitLeaseGroupID',
				per.PersonID AS 'LeaseID',
				'Non-Resident' AS 'LeaseStatus',
				'Non-Resident' AS 'CurrentLeaseStatus',
				null AS 'Unit',
				null AS 'Building',
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
				0 AS 'SuretyBondsTotal',
				0 AS 'IsRentalAssistance',
				0 AS 'PostToHapLedger'
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

	IF @isAffordable = 1
	BEGIN
		INSERT #AffordableData
		SELECT
			#rr.LeaseID AS 'LeaseID',
			c.[Type] AS 'CertificationType',
			c.EffectiveDate AS 'CertificationEffectiveDate',
			c.RecertificationDate AS 'RecertificationDate',
			c.UtilityAllowance AS 'UtilityAllowance',
			c.HUDTotalTenantPayment AS 'HudTotalTenantPayment',
			(SELECT TOP 1 (cr.Amount)
			 FROM
				ContractRent cr
				JOIN UnitType ut ON cr.ObjectID = ut.UnitTypeID
				JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID
				JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
			WHERE
				ulg.UnitLeaseGroupID = #rr.UnitLeaseGroupID
				AND cr.DateChanged <= c.EffectiveDate
			ORDER BY cr.DateChanged DESC) AS 'HudContractRent',
			CASE
				WHEN EXISTS (SELECT *
				             FROM AffordableProgram ap
								JOIN AffordableProgramAllocation apa ON ap.AffordableProgramID = apa.AffordableProgramID
								JOIN CertificationAffordableProgramAllocation capa ON apa.AffordableProgramAllocationID = capa.AffordableProgramAllocationID
							WHERE capa.CertificationID = c.CertificationID
								AND ap.IsHUD = 1)
				THEN 1
				ELSE 0
			END AS 'IsHud',
			CASE WHEN c.[Type] = 'Market'
				THEN NULL ELSE c.TaxCreditTenantRent
				END AS 'TaxCreditTenantRent',
			c.HudTenantRent AS 'HudTenantRent'
		FROM
			#RROccupants #rr
			JOIN UnitLeaseGroup ulg ON #rr.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			JOIN Lease l2 ON l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			JOIN Certification c ON l2.LeaseID = c.LeaseID
		WHERE
			ulg.AccountID = @accountID
			AND c.CertificationID = (SELECT TOP 1 c2.CertificationID
									  FROM Certification c2
										JOIN Lease l ON c2.LeaseID = l.LeaseID
									  WHERE l.UnitLeaseGroupID = #rr.UnitLeaseGroupID
										AND c2.EffectiveDate <= @date
										AND c2.DateCompleted IS NOT NULL
									  ORDER BY c2.EffectiveDate DESC)
	END


	IF (@isRentRollUnitTypeSummary = 1)
	BEGIN
		CREATE TABLE #LeasesAndUnits (
			PropertyID uniqueidentifier not null,
			UnitID uniqueidentifier not null,
			UnitNumber nvarchar(50) null,
			OccupiedUnitLeaseGroupID uniqueidentifier null,
			OccupiedLastLeaseID uniqueidentifier null,
			OccupiedMoveInDate date null,
			OccupiedNTVDate date null,
			OccupiedMoveOutDate date null,
			OccupiedIsMovedOut bit null,
			PendingUnitLeaseGroupID uniqueidentifier null,
			PendingLeaseID uniqueidentifier null,
			PendingApplicationDate date null,
			PendingMoveInDate date null)

		INSERT #LeasesAndUnits
			EXEC GetConsolodatedOccupancyNumbers @accountID, @date, null, @propertyIDs

		UPDATE #rr
			SET #rr.UnitStatus =
				CASE
					WHEN US.[Status] IN ('Down', 'Admin') THEN 'Admin/ Down'
                    WHEN #occ.OccupiedUnitLeaseGroupID IS NULL AND #occ.PendingUnitLeaseGroupID IS NULL THEN 'Vacant/ Not Leased'
                    WHEN #occ.OccupiedUnitLeaseGroupID IS NULL AND #occ.PendingUnitLeaseGroupID IS NOT NULL THEN 'Vacant/ Leased'
                    WHEN #occ.OccupiedNTVDate IS NOT NULL AND #occ.PendingUnitLeaseGroupID IS NOT NULL THEN 'Occupied/ Notice To Vacate Leased'
					WHEN #occ.OccupiedNTVDate IS NOT NULL AND #occ.PendingUnitLeaseGroupID IS NULL THEN 'Occupied/ Notice to Vacate'
                    ELSE 'Occupied/ No Notice'
                END
			FROM #RentRoll #rr
				INNER JOIN #LeasesAndUnits #occ ON #rr.UnitID = #occ.UnitID
				CROSS APPLY GetUnitStatusByUnitID(#rr.UnitID, @date) AS [US]
	END

	SELECT * FROM #RentRoll
		  ORDER BY PaddedUnit, LeaseStatus, OrderBy

	IF @isAffordable = 1
	BEGIN
		SELECT * FROM #AffordableData
	END

END
GO
