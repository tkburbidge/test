SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO





-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 10, 2012
-- Description:	Generates the data for the Unit Availability Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_UNT_AvailableUnits] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@unitStatuses StringCollection READONLY,
	@date date = null,
	@onlyIncludeAvailableForMarketing bit = 0,
	@historical bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #AvailableUnits (
		PropertyName nvarchar(50) not null,
		PropertyID uniqueidentifier not null,
		[Type] nvarchar(50) null,
		Unit nvarchar(50) null,
		UnitID uniqueidentifier null,
		MarketRent money null,
		UnitType nvarchar(50) null,
		UnitTypeID uniqueidentifier null,
		Building nvarchar(50) null,
		[Floor] nvarchar(50) null,
		SquareFeet int null,
		UnitStatus nvarchar(50) null,
		DaysVacant int null,
		MoveInDate date null,
		MoveOutDate date null,
		Applicants nvarchar(1000) null,
		OldLeaseID uniqueidentifier null,
		NewLeaseID uniqueidentifier null,
		PaddedNumber nvarchar(50) null,
		Note nvarchar(1000) null,
		PetsPermitted bit not null,
		UnitDateAvailable date null)
		
	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		UnitStatus nvarchar(200) not null,
		UnitStatusLedgerItemTypeID uniqueidentifier not null,
		RentLedgerItemTypeID uniqueidentifier not null,
		MarketRent decimal null,
		Amenities nvarchar(MAX) null)

	CREATE TABLE #UnitRentableItems (
		UnitID uniqueidentifier null,
		LedgerItemID uniqueidentifier not null,
		Name nvarchar(50) not null,
		Amount money not null,
		[Type] nvarchar(50) not null)
		
	CREATE TABLE #Properties (
		Sequence int identity not null,
		PropertyID uniqueidentifier not null)

	CREATE TABLE #Pricing(
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier null,
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

	CREATE TABLE #Special(
		UnitID uniqueidentifier not null,
		SpecialID uniqueidentifier not null,
		LeaseTermID uniqueidentifier null,
		LeaseTerm nvarchar(50) null,
		LeaseTermDuration int null,
		Name nvarchar(50) not null,
		MarketingName nvarchar(50) not null,
		MarketingDescription nvarchar(max) null,
		StartDate datetime not null,
		EndDate datetime null,
		Period nvarchar(50) not null,
		StartMonth int not null,
		Duration int null,
		Amount money not null,
		AmountType nvarchar(50) not null,
		PriceDisplayType nvarchar(50) null,
		ShowOnAvailability bit not null,
		DateType nvarchar(50) not null)

	CREATE TABLE #CurrentOccupants	(
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

	CREATE TABLE #MaxDaysByProperty (
		PropertyID uniqueidentifier not null,
		MaxDays int not null)
	
	INSERT #MaxDaysByProperty
		SELECT pIDs.Value, ISNULL(MAX(amr.DaysToComplete), 0)
			FROM @propertyIDs pIDs
				LEFT JOIN AutoMakeReady amr ON pIDs.Value = amr.PropertyID AND amr.AccountID = @accountID
			GROUP BY pIDs.Value
	
	IF (@historical = 1)
	BEGIN
		INSERT INTO #CurrentOccupants
			EXEC [GetConsolodatedOccupancyNumbers] @accountID, @date, null, @propertyIDs

	INSERT INTO #AvailableUnits
		SELECT	p.Name AS 'PropertyName',
					p.PropertyID,
					'Vacant' AS 'Type',
					u.Number AS 'Unit',
					u.UnitID AS 'UnitID',
					ut.MarketRent AS 'MarketRent',
					ut.Name AS 'UnitType',
					ut.UnitTypeID,
					b.Name AS 'Building',
					u.[Floor] AS 'Floor',
					u.SquareFootage AS 'SquareFootage',
					[US].[Status] AS 'UnitStatus',
					ISNULL(DATEDIFF(DAY, u.LastVacatedDate, @date), 0) AS 'DaysVacant',
					null AS 'MoveInDate',
					null AS 'MoveOutDate',
					null AS 'Applicants',
					null AS 'OldLeaseID',
					null AS 'NewLeaseID',
					u.PaddedNumber AS 'PaddedNumber',
					u.AvailableUnitsNote AS 'Note',
					u.PetsPermitted AS 'PetsPermitted',
					null AS 'UnitDateAvailable'
				FROM #CurrentOccupants #co
					INNER JOIN Property p ON #co.PropertyID = p.PropertyID
					INNER JOIN Unit u ON #co.UnitID = u.UnitID
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS [US]
				WHERE [US].[Status] IN (SELECT Value FROM @unitStatuses)
				  AND u.AllowMultipleLeases = 0
				  AND u.IsHoldingUnit = 0
				  AND u.ExcludedFromOccupancy = 0
				  AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
				  AND (@onlyIncludeAvailableForMarketing = 0 OR u.AvailableForOnlineMarketing = 1)
				  AND #co.OccupiedUnitLeaseGroupID IS NULL
				  AND #co.PendingUnitLeaseGroupID IS NULL

			UNION

			SELECT	p.Name AS 'PropertyName',
					p.PropertyID,
					'Notice to Vacate' AS 'Type',
					u.Number AS 'Unit',
					u.UnitID AS 'UnitID',
					ut.MarketRent AS 'MarketRent',
					ut.Name AS 'UnitType',
					ut.UnitTypeID,
					b.Name AS 'Building',
					u.[Floor] AS 'Floor',
					u.SquareFootage AS 'SquareFootage',
					[US].[Status] AS 'UnitStatus',
					ISNULL(DATEDIFF(DAY, u.LastVacatedDate, @date), 0) AS 'DaysVacant',
					null AS 'MoveInDate',
					#co.OccupiedMoveOutDate AS 'MoveOutDate',
					null AS 'Applicants',
					#co.OccupiedLastLeaseID AS 'OldLeaseID',
					null AS 'NewLeaseID',
					u.PaddedNumber AS 'PaddedNumber',
					u.AvailableUnitsNote AS 'Note',
					u.PetsPermitted AS 'PetsPermitted',
					#co.OccupiedMoveOutDate AS 'UnitDateAvailable'
				FROM #CurrentOccupants #co
					INNER JOIN Property p ON #co.PropertyID = p.PropertyID
					INNER JOIN Unit u ON #co.UnitID = u.UnitID
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS [US]
				WHERE [US].[Status] IN (SELECT Value FROM @unitStatuses)
				  AND u.AllowMultipleLeases = 0
				  AND u.IsHoldingUnit = 0
				  AND u.ExcludedFromOccupancy = 0
				  AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
				  AND (@onlyIncludeAvailableForMarketing = 0 OR u.AvailableForOnlineMarketing = 1)
				  AND (#co.OccupiedUnitLeaseGroupID IS NOT NULL AND #co.OccupiedNTVDate <= @date)
				  AND #co.OccupiedMoveOutDate IS NOT NULL
				  AND #co.PendingUnitLeaseGroupID IS NULL

			UNION

			SELECT	p.Name AS 'PropertyName',
					p.PropertyID,
					'Vacant Pre-Leased' AS 'Type',
					u.Number AS 'Unit',
					u.UnitID AS 'UnitID',
					(SELECT SUM(lli.Amount)
						FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
						WHERE lli.LeaseID = #co.PendingLeaseID
						  --AND lli.StartDate <= l.LeaseEndDate
						  AND lit.IsRent = 1) AS 'MarketRent',
					ut.Name AS 'UnitType',
					ut.UnitTypeID,
					b.Name AS 'Building',
					u.[Floor] AS 'Floor',
					u.SquareFootage AS 'SquareFootage',
					[US].[Status] AS 'UnitStatus',
					ISNULL(DATEDIFF(DAY, u.LastVacatedDate, @date), 0) AS 'DaysVacant',
					#co.PendingMoveInDate AS 'MoveInDate',
					null AS 'MoveOutDate',
					(STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
								 FROM Person 
									 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
									 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
									 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
								 WHERE PersonLease.LeaseID = #co.PendingLeaseID
									   AND PersonType.[Type] = 'Resident'				   
									   AND PersonLease.MainContact = 1				   
								 FOR XML PATH ('')), 1, 2, '')) AS 'Applicants',
					null AS 'OldLeaseID',
					#co.PendingLeaseID AS 'NewLeaseID',
					u.PaddedNumber AS 'PaddedNumber',
					u.AvailableUnitsNote AS 'Note',
					u.PetsPermitted AS 'PetsPermitted',
					null AS 'UnitDateAvailable'
				FROM #CurrentOccupants #co
					INNER JOIN Property p ON #co.PropertyID = p.PropertyID
					INNER JOIN Unit u ON #co.UnitID = u.UnitID
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS [US]
				WHERE [US].[Status] IN (SELECT Value FROM @unitStatuses)
				  AND u.AllowMultipleLeases = 0
				  AND u.IsHoldingUnit = 0
				  AND u.ExcludedFromOccupancy = 0
				  AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
				  AND (@onlyIncludeAvailableForMarketing = 0 OR u.AvailableForOnlineMarketing = 1)
				  AND #co.OccupiedUnitLeaseGroupID IS NULL
				  AND #co.PendingUnitLeaseGroupID IS NOT NULL

			UNION

			SELECT	p.Name AS 'PropertyName',
					p.PropertyID,
					'Notice to Vacate Pre-Leased' AS 'Type',
					u.Number AS 'Unit',
					u.UnitID AS 'UnitID',
					(SELECT SUM(lli.Amount)
						FROM LeaseLedgerItem lli
						INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
						INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
						WHERE lli.LeaseID = #co.PendingLeaseID
						  --AND lli.StartDate <= l.LeaseEndDate
						  AND lit.IsRent = 1) AS 'MarketRent',
					ut.Name AS 'UnitType',
					ut.UnitTypeID,
					b.Name AS 'Building',
					u.[Floor] AS 'Floor',
					u.SquareFootage AS 'SquareFootage',
					[US].[Status] AS 'UnitStatus',
					ISNULL(DATEDIFF(DAY, u.LastVacatedDate, @date), 0) AS 'DaysVacant',
					#co.PendingMoveInDate AS 'MoveInDate',
					#co.OccupiedMoveOutDate AS 'MoveOutDate',
					(STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
								 FROM Person 
									 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
									 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
									 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
								 WHERE PersonLease.LeaseID = #co.PendingLeaseID
									   AND PersonType.[Type] = 'Resident'				   
									   AND PersonLease.MainContact = 1				   
								 FOR XML PATH ('')), 1, 2, '')) AS 'Applicants',
					#co.OccupiedLastLeaseID AS 'OldLeaseID',
					#co.PendingLeaseID AS 'NewLeaseID',
					u.PaddedNumber AS 'PaddedNumber',
					u.AvailableUnitsNote AS 'Note',
					u.PetsPermitted AS 'PetsPermitted',
					#co.OccupiedMoveOutDate AS 'UnitDateAvailable'
				FROM #CurrentOccupants #co
					INNER JOIN Property p ON #co.PropertyID = p.PropertyID
					INNER JOIN Unit u ON #co.UnitID = u.UnitID
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
					INNER JOIN Building b ON u.BuildingID = b.BuildingID
					CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS [US]
				WHERE [US].[Status] IN (SELECT Value FROM @unitStatuses)
				  AND u.AllowMultipleLeases = 0
				  AND u.IsHoldingUnit = 0
				  AND u.ExcludedFromOccupancy = 0
				  AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
				  AND (@onlyIncludeAvailableForMarketing = 0 OR u.AvailableForOnlineMarketing = 1)
				  AND #co.OccupiedUnitLeaseGroupID IS NOT NULL 
				  AND #co.OccupiedMoveOutDate IS NOT NULL
				  AND #co.PendingUnitLeaseGroupID IS NOT NULL
				  AND #co.OccupiedNTVDate <= @date

	
		

		UPDATE #AvailableUnits SET UnitDateAvailable = (SELECT MAX(pl.MoveOutDate)
														FROM UnitLeaseGroup ulg
															INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND ulg.UnitID = #AvailableUnits.UnitID
																			AND l.LeaseID = (SELECT TOP 1 LeaseID
																									FROM Lease
																									WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																									AND LeaseStatus IN ('Former', 'Evicted')
																									-- Make sure this lease moved out before the @date
																									AND (SELECT TOP 1 pl2.MoveOutDate
																										 FROM PersonLease pl2
																										 WHERE pl2.LeaseID = Lease.LeaseID
																										 ORDER BY pl2.MoveOutDate DESC) <= @date
																									ORDER BY LeaseEndDate DESC)
															INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID)
		WHERE [Type] IN ('Vacant', 'Vacant Pre-Leased')

		UPDATE #AvailableUnits SET DaysVacant = ISNULL(DATEDIFF(DAY, UnitDateAvailable, @date), 0)
		WHERE [Type] IN ('Vacant', 'Vacant Pre-Leased')

		UPDATE #AvailableUnits SET UnitDateAvailable = (SELECT DATEADD(DAY, #days.MaxDays, UnitDateAvailable)
													    FROM #MaxDaysByProperty #days
														WHERE #days.PropertyID = #AvailableUnits.PropertyID)
		WHERE [Type] IN ('Vacant', 'Notice to Vacate')
			AND UnitDateAvailable IS NOT NULL

		UPDATE #AvailableUnits SET UnitDateAvailable = (SELECT DATEADD(DAY, -#AvailableUnits.DaysVacant + #days.MaxDays, GETDATE())
															FROM #MaxDaysByProperty #days
															WHERE #days.PropertyID = #AvailableUnits.PropertyID)
			WHERE UnitDateAvailable IS NULL
				AND [Type] IN ('Vacant', 'Notice to Vacate')

	END
	ELSE
	BEGIN
		INSERT INTO #AvailableUnits
			SELECT	p.Name AS 'PropertyName',
				p.PropertyID AS 'PropertyID',
				'Vacant' AS 'Type',
				u.Number AS 'Unit',
				u.UnitID AS 'UnitID',
				ut.MarketRent AS 'MarketRent',
				ut.Name AS 'UnitType',
				ut.UnitTypeID AS 'UnitTypeID',
				b.Name AS 'Building',
				u.[Floor] AS 'Floor',
				--ut.SquareFootage AS 'SquareFeet',
				u.SquareFootage AS 'SquareFeet',
				US.[Status] AS 'UnitStatus',
				ISNULL(DATEDIFF(day, u.LastVacatedDate, getdate()), 0) AS 'DaysVacant',
				null AS 'MoveInDate',
				null AS 'MoveOutDate',
				null AS 'Applicants',
				null AS 'OldLeaseID',
				null AS 'NewLeaseID',
				u.PaddedNumber AS 'PaddedNumber',
				u.AvailableUnitsNote AS 'Note',
				u.PetsPermitted AS 'PetsPermitted',
				u.DateAvailable AS 'UnitDateAvailable'
		FROM Unit u
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS US
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND US.[Status] IN (SELECT Value FROM @unitStatuses)
		  AND u.AllowMultipleLeases = 0
		  AND u.IsHoldingUnit = 0
		  AND u.ExcludedFromOccupancy = 0
		  AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
		  AND (@onlyIncludeAvailableForMarketing = 0 OR u.AvailableForOnlineMarketing = 1)
		  AND u.UnitID NOT IN (SELECT DISTINCT ulg.UnitID
									FROM UnitLeaseGroup ulg
										LEFT JOIN Lease cl ON cl.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND cl.LeaseStatus IN ('Current', 'Under Eviction')
										LEFT JOIN Lease pl ON pl.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND pl.LeaseStatus IN ('Pending',  'Pending Renewal', 'Pending Transfer')
									WHERE ut.PropertyID IN (SELECT Value FROM @propertyIDs)
									  AND ((cl.LeaseID IS NOT NULL) OR (pl.LeaseID IS NOT NULL)))
										
		UNION
		
		SELECT	p.Name AS 'PropertyName',
				p.PropertyID AS 'PropertyID',
				'Notice to Vacate' AS 'Type',
				u.Number AS 'Unit',
				u.UnitID AS 'UnitID',
				ut.MarketRent AS 'MarketRent',
				ut.Name AS 'UnitType',
				ut.UnitTypeID AS 'UnitTypeID',
				b.Name AS 'Building',
				u.[Floor] AS 'Floor',
				--ut.SquareFootage AS 'SquareFeet',
				u.SquareFootage AS 'SquareFeet',
				US.[Status] AS 'UnitStatus',
				ISNULL(DATEDIFF(day, u.LastVacatedDate, getdate()), 0) AS 'DaysVacant',
				null AS 'MoveInDate',
				(SELECT MAX(MoveOutDate) FROM PersonLease WHERE LeaseID = l.LeaseID AND ResidencyStatus NOT IN ('Cancelled')) AS 'MoveOutDate',
				null AS 'Applicants',
				l.LeaseID AS 'OldLeaseID',
				null AS 'NewLeaseID',
				u.PaddedNumber AS 'PaddedNumber',
				u.AvailableUnitsNote AS 'Note',
				u.PetsPermitted AS 'PetsPermitted',
				u.DateAvailable AS 'UnitDateAvailable'
		FROM Unit u
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')
			LEFT JOIN PersonLease plmo ON l.LeaseID = plmo.LeaseID AND plmo.MoveOutDate IS NULL
			CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS US
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND US.[Status] IN (SELECT Value FROM @unitStatuses)
		  AND u.AllowMultipleLeases = 0	
		  AND u.IsHoldingUnit = 0
		  AND u.ExcludedFromOccupancy = 0
		  AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
		  AND (@onlyIncludeAvailableForMarketing = 0 OR u.AvailableForOnlineMarketing = 1)
		  AND plmo.PersonLeaseID IS NULL
		  AND u.UnitID NOT IN (SELECT ulg1.UnitID 
									FROM UnitLeaseGroup ulg1
										INNER JOIN Lease l1 ON l1.UnitLeaseGroupID = ulg1.UnitLeaseGroupID AND l1.LeaseStatus IN ('Pending', 'Pending Renewal', 'Pending Transfer'))
									
		UNION
		
		SELECT	p.Name AS 'PropertyName',
				p.PropertyID AS 'PropertyID',
				'Vacant Pre-Leased' AS 'Type',
				u.Number AS 'Unit',
				u.UnitID AS 'UnitID',
				--ut.MarketRent AS 'MarketRent',
				(SELECT SUM(lli.Amount)
					FROM LeaseLedgerItem lli
					INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
					INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = l.LeaseID
					  AND lli.StartDate <= l.LeaseEndDate
					  AND lit.IsRent = 1) AS 'MarketRent',
				ut.Name AS 'UnitType',
				ut.UnitTypeID AS 'UnitTypeID',
				b.Name AS 'Building',
				u.[Floor] AS 'Floor',
				--ut.SquareFootage AS 'SquareFeet',
				u.SquareFootage AS 'SquareFeet',
				US.[Status] AS 'UnitStatus',
				ISNULL(DATEDIFF(day, u.LastVacatedDate, getdate()), 0) AS 'DaysVacant',
				(SELECT MIN(MoveInDate) FROM PersonLease WHERE LeaseID = l.LeaseID AND ResidencyStatus NOT IN ('Cancelled')) AS 'MoveInDate',
				null AS 'MoveOutDate',
				(STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
							 FROM Person 
								 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
								 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
								 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
							 WHERE PersonLease.LeaseID = l.LeaseID
								   AND PersonType.[Type] = 'Resident'				   
								   AND PersonLease.MainContact = 1				   
							 FOR XML PATH ('')), 1, 2, '')) AS 'Applicants',
				null AS 'OldLeaseID',
				l.LeaseID AS 'NewLeaseID',
				u.PaddedNumber AS 'PaddedNumber',
				u.AvailableUnitsNote AS 'Note',
				u.PetsPermitted AS 'PetsPermitted',
				u.DateAvailable AS 'UnitDateAvailable'
		FROM Unit u
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.LeaseStatus IN ('Pending', 'Pending Renewal', 'Pending Transfer')
			CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS US
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND US.[Status] IN (SELECT Value FROM @unitStatuses)
		  AND u.AllowMultipleLeases = 0
		  AND u.IsHoldingUnit = 0
		  AND u.ExcludedFromOccupancy = 0
		  AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
		  AND (@onlyIncludeAvailableForMarketing = 0 OR u.AvailableForOnlineMarketing = 1)
		  AND u.UnitID NOT IN (SELECT DISTINCT ulg.UnitID
									FROM UnitLeaseGroup ulg
										INNER JOIN Lease cl ON cl.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND cl.LeaseStatus IN ('Current', 'Under Eviction'))
										
		UNION
		
		SELECT	p.Name AS 'PropertyName',
				p.PropertyID AS 'PropertyID',
				'Notice to Vacate Pre-Leased' AS 'Type',
				u.Number AS 'Unit',
				u.UnitID AS 'UnitID',
				--ut.MarketRent AS 'MarketRent',
				(SELECT SUM(lli.Amount)
					FROM LeaseLedgerItem lli
					INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
					INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
					WHERE lli.LeaseID = lp.LeaseID
					  AND lli.StartDate <= lp.LeaseEndDate
					  AND lit.IsRent = 1) AS 'MarketRent',
				ut.Name AS 'UnitType',
				ut.UnitTypeID AS 'UnitTypeID',
				b.Name AS 'Building',
				u.[Floor] AS 'Floor',
				--ut.SquareFootage AS 'SquareFeet',
				u.SquareFootage AS 'SquareFeet',
				US.[Status] AS 'UnitStatus',
				ISNULL(DATEDIFF(day, u.LastVacatedDate, getdate()), 0) AS 'DaysVacant',
				(SELECT MIN(MoveInDate) FROM PersonLease WHERE LeaseID = lp.LeaseID AND ResidencyStatus NOT IN ('Cancelled')) AS 'MoveInDate',
				(SELECT MAX(MoveOutDate) FROM PersonLease WHERE LeaseID = l.LeaseID AND ResidencyStatus NOT IN ('Cancelled')) AS 'MoveOutDate',
				(STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
							 FROM Person 
								 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
								 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
								 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
							 WHERE PersonLease.LeaseID = lp.LeaseID
								   AND PersonType.[Type] = 'Resident'				   
								   AND PersonLease.MainContact = 1				   
							 FOR XML PATH ('')), 1, 2, '')) AS 'Applicants',			
				l.LeaseID AS 'OldLeaseID',
				lp.LeaseID AS 'NewLeaseID',
				u.PaddedNumber AS 'PaddedNumber',
				u.AvailableUnitsNote AS 'Note',
				u.PetsPermitted AS 'PetsPermitted',
				u.DateAvailable AS 'UnitDateAvailable'					
		FROM Unit u
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.LeaseStatus IN  ('Current', 'Under Eviction')
			INNER JOIN UnitLeaseGroup ulg1 ON u.UnitID = ulg1.UnitID
			INNER JOIN Lease lp ON ulg1.UnitLeaseGroupID = lp.UnitLeaseGroupID AND lp.LeaseStatus IN ('Pending', 'Pending Renewal', 'Pending Transfer')
			CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS US
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND US.[Status] IN (SELECT Value FROM @unitStatuses)
		  AND u.AllowMultipleLeases = 0	
		  AND u.IsHoldingUnit = 0
		  AND u.ExcludedFromOccupancy = 0
		  AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
		  AND (@onlyIncludeAvailableForMarketing = 0 OR u.AvailableForOnlineMarketing = 1)
		  AND ((SELECT COUNT(*) FROM PersonLease WHERE LeaseID = l.LeaseID) 
				=
			   (SELECT COUNT(*) FROM PersonLease WHERE LeaseID = l.LeaseID AND MoveOutDate IS NOT NULL))	
			   
		UNION

		SELECT	p.Name AS 'PropertyName',
				p.PropertyID AS 'PropertyID',
				'Holding Unit' AS 'Type',
				u.Number AS 'Unit',
				u.UnitID AS 'UnitID',
				ut.MarketRent AS 'MarketRent',
				ut.Name AS 'UnitType',
				ut.UnitTypeID AS 'UnitTypeID',
				b.Name AS 'Building',
				u.[Floor] AS 'Floor',
				--ut.SquareFootage AS 'SquareFeet',
				u.SquareFootage AS 'SquareFeet',
				US.[Status] AS 'UnitStatus',
				0 AS 'DaysVacant',
				null AS 'MoveInDate',
				null AS 'MoveOutDate',
				null AS 'Applicants',
				null AS 'OldLeaseID',
				null AS 'NewLeaseID',
				u.PaddedNumber AS 'PaddedNumber',
				u.AvailableUnitsNote AS 'Note',
				u.PetsPermitted AS 'PetsPermitted',
				u.DateAvailable AS 'UnitDateAvailable'
		FROM Unit u
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS US
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND US.[Status] IN (SELECT Value FROM @unitStatuses)
		  AND u.AllowMultipleLeases = 0
		  AND u.IsHoldingUnit = 1	
		  AND (@onlyIncludeAvailableForMarketing = 0 OR u.AvailableForOnlineMarketing = 1)

		UNION

		SELECT	p.Name AS 'PropertyName',
				p.PropertyID AS 'PropertyID',
				'Holding Units' AS 'Type',
				u.Number AS 'Unit',
				u.UnitID AS 'UnitID',
				ut.MarketRent AS 'MarketRent',
				ut.Name AS 'UnitType',
				ut.UnitTypeID AS 'UnitTypeID',
				b.Name AS 'Building',
				u.[Floor] AS 'Floor',
				--ut.SquareFootage AS 'SquareFeet',
				u.SquareFootage AS 'SquareFeet',
				US.[Status] AS 'UnitStatus',
				0 AS 'DaysVacant',
				(SELECT MIN(MoveInDate) FROM PersonLease WHERE LeaseID = l.LeaseID AND ResidencyStatus NOT IN ('Cancelled')) AS 'MoveInDate',
				null AS 'MoveOutDate',
				(STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
							 FROM Person 
								 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
								 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
								 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
							 WHERE PersonLease.LeaseID = l.LeaseID
								   AND PersonType.[Type] = 'Resident'				   
								   AND PersonLease.MainContact = 1				   
							 FOR XML PATH ('')), 1, 2, '')) AS 'Applicants',
				null AS 'OldLeaseID',
				l.LeaseID AS 'NewLeaseID',
				u.PaddedNumber AS 'PaddedNumber',
				'' AS 'Note',
				u.PetsPermitted AS 'PetsPermitted',
				u.DateAvailable AS 'UnitDateAvailable'
		FROM Unit u
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND l.LeaseStatus IN ('Pending')
			CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS US
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND US.[Status] IN (SELECT Value FROM @unitStatuses)
		  AND u.AllowMultipleLeases = 0
		  AND u.IsHoldingUnit = 1
		  AND (@onlyIncludeAvailableForMarketing = 0 OR u.AvailableForOnlineMarketing = 1)
	
		
		UPDATE #AvailableUnits SET UnitDateAvailable = (SELECT DATEADD(DAY, #days.MaxDays, MAX(pl.MoveOutDate))
														FROM UnitLeaseGroup ulg
															INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND ulg.UnitID = #AvailableUnits.UnitID
																			AND l.LeaseID = (SELECT TOP 1 LeaseID
																								 FROM Lease
																								 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																								   AND LeaseStatus IN ('Former', 'Evicted')
																								 ORDER BY LeaseEndDate DESC)
															INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
															INNER JOIN #MaxDaysByProperty #days ON #days.PropertyID = #AvailableUnits.PropertyID
														GROUP BY #days.MaxDays)
		WHERE UnitDateAvailable IS NULL
			AND [Type] IN ('Vacant')

	UPDATE #AvailableUnits SET UnitDateAvailable = (SELECT DATEADD(DAY, #days.MaxDays, MoveOutDate)
													    FROM #MaxDaysByProperty #days
														WHERE #days.PropertyID = #AvailableUnits.PropertyID)
	WHERE UnitDateAvailable IS NULL
			AND [Type] IN ('Vacant', 'Notice to Vacate')

	UPDATE #AvailableUnits SET UnitDateAvailable = (SELECT DATEADD(DAY, -#AvailableUnits.DaysVacant + #days.MaxDays, GETDATE())
														FROM #MaxDaysByProperty #days
														WHERE #days.PropertyID = #AvailableUnits.PropertyID)
		WHERE UnitDateAvailable IS NULL
			AND [Type] IN ('Vacant', 'Notice to Vacate')
	END
	
		
	INSERT #Properties SELECT Value 
						   FROM @propertyIDs 
						   WHERE Value IN (SELECT p.PropertyID FROM Property p
																  INNER JOIN UnitType ut ON p.PropertyID = ut.PropertyID
																  INNER JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID 
																WHERE u.UnitID IN (SELECT UnitID FROM #AvailableUnits))
	DECLARE @maxCtr int, @ctr int = 1
	DECLARE @propertyID uniqueidentifier
	DECLARE @unitIDs GuidCollection
	SET @maxCtr = (SELECT MAX(Sequence) FROM #Properties)
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SET @propertyID = (SELECT PropertyID FROM #Properties WHERE Sequence = @ctr)
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
							WHERE u.UnitID IN (SELECT UnitID FROM #AvailableUnits)
		INSERT #UnitAmenities 
			EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 1
	
		DELETE @unitIDs
		SET @ctr = @ctr + 1
	END	


	INSERT #UnitRentableItems
		EXEC GetRentableItemUnitInfo @accountID, @propertyIDs, 1


	SELECT #au.PropertyName, #au.PropertyID, #au.[Type], #au.Unit, #au.UnitID, #ua.MarketRent, #au.UnitType, #au.UnitTypeID, #au.Building, #au.[Floor], #au.SquareFeet, #au.UnitStatus, #au.DaysVacant, 
			#au.MoveInDate, #au.MoveOutDate, #au.Applicants, #au.OldLeaseID, #au.NewLeaseID, #au.Note, #ua.Amenities, #au.PetsPermitted, #au.UnitDateAvailable,
			STUFF((SELECT DISTINCT ', ' + (#uri.Name) 
				FROM #UnitRentableItems #uri				
				WHERE #uri.UnitID = #au.UnitID			
				FOR XML PATH ('')), 1, 2, '') AS 'RentableItems',
			ISNULL((SELECT #ua.MarketRent + SUM(#uri.Amount)
						FROM #UnitRentableItems #uri
						WHERE #uri.UnitID = #au.UnitID),
				   (SELECT #ua.MarketRent)) AS 'TotalCharges'
		FROM #AvailableUnits #au
			INNER JOIN #UnitAmenities #ua ON #au.UnitID = #ua.UnitID
		ORDER BY UnitType, PaddedNumber
	
	INSERT #Special
		SELECT #au.UnitID, s.SpecialID, lt.LeaseTermID, lt.Name, (CASE lt.IsFixed WHEN 0 THEN lt.Months ELSE NULL END), s.Name, s.MarketingName, s.MarketingDescription, s.StartDate, s.EndDate, s.Period, s.StartMonth, 
				s.Duration, s.Amount, s.AmountType, s.PriceDisplayType, s.ShowOnAvailability, s.DateType
			FROM Special s
				INNER JOIN SpecialApplication sa ON s.SpecialID = sa.SpecialID
				INNER JOIN #AvailableUnits #au ON sa.ObjectID IN (#au.UnitID, #au.UnitTypeID, #au.PropertyID)
				LEFT JOIN SpecialLeaseTerm slt ON s.SpecialID = slt.SpecialID
				LEFT JOIN LeaseTerm lt ON slt.LeaseTermID = lt.LeaseTermID
			WHERE (s.EndDate IS NULL OR s.EndDate >= (CASE WHEN @date IS NULL THEN GETDATE() ELSE @date END))
              AND s.[Type] <> 'Renewal'
			
	SELECT * FROM #Special
END
GO
