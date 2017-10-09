SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_CST_LEINBACH_RUBSReport] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier = null, 
	@accountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier null,
		StartDate date null,
		EndDate date null)

	INSERT #PropertiesAndDates
		SELECT @propertyID, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM Property p
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

    CREATE TABLE #Occupancy (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) null,
		UnitNumber nvarchar(20) null,
		PaddedUnitNumber nvarchar(20) null,
		UnitID uniqueidentifier null,
		UnitType nvarchar(250) null,
		SquareFootage int null,
		MajorOccupants int null,
		MinorOccupants int null,
		PersonID uniqueidentifier null,
		ResidentName nvarchar(1000) null,
		EmailAddress nvarchar(1000) null,
		LeaseID uniqueidentifier null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null)

	INSERT INTO #Occupancy
		SELECT DISTINCT
			prop.PropertyID,
			prop.Name,
			u.Number,
			u.PaddedNumber,
			u.UnitID,
			ut.Name,
			ut.SquareFootage,
			null,
			null,
			null,		-- PersonID
			Ponytail.ResidentName,
			null,		-- EmailAddress
			Ponytail.LeaseID,
			Ponytail.UnitLeaseGroupID,
			Ponytail.MoveInDate,
			Ponytail.MoveOutDate
		FROM Unit u
			INNER JOIN Building b on u.BuildingID = b.BuildingID
			INNER JOIN Property prop on b.PropertyID = prop.PropertyID
			INNER JOIN UnitType ut on u.UnitTypeID = ut.UnitTypeID
			LEFT JOIN
				(SELECT DISTINCT
					ulg.UnitID,
					l.LeaseID,
					ulg.UnitLeaseGroupID,
					null AS 'ResidentName',
					(SELECT MIN(MoveInDate)
						FROM PersonLease 
						WHERE LeaseID = l.LeaseID) AS 'MoveInDate',
					(SELECT MAX(pl1.MoveOutDate)
						FROM PersonLease pl1
							LEFT JOIN PersonLease pl1MO ON pl1.LeaseID = pl1MO.LeaseID AND pl1MO.MoveOutDate IS NULL
						WHERE pl1.LeaseID = l.LeaseID
						  AND pl1MO.PersonLeaseID IS NULL) AS 'MoveOutDate'
					FROM UnitLeaseGroup ulg
						INNER JOIN Lease l on ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
						INNER JOIN PersonLease pl on l.LeaseID = pl.LeaseID
					WHERE l.LeaseStatus NOT IN ('Denied', 'Cancelled', 'Renewed')
					  AND pl.ResidencyStatus NOT IN ('Approved', 'Cancelled', 'Pending', 'Pending Transfer', 'Pending Renewal')) Ponytail ON u.UnitID = Ponytail.UnitID
			INNER JOIN #PropertiesAndDates #pad ON prop.PropertyID = #pad.PropertyID
		WHERE u.AccountID = @accountID
			AND prop.PropertyID = @propertyID
			AND (Ponytail.MoveOutDate IS NULL OR (Ponytail.MoveOutDate IS NOT NULL AND Ponytail.MoveOutDate >= #pad.StartDate))
			AND (Ponytail.MoveInDate IS NULL OR (Ponytail.MoveInDate <= #pad.EndDate))
			AND u.ExcludedFromOccupancy = 0
			AND (u.DateRemoved IS NULL OR u.DateRemoved > #pad.EndDate)

	INSERT INTO #Occupancy
		SELECT DISTINCT
				prop.PropertyID,
				prop.Name,
				u.Number,
				u.PaddedNumber,
				u.UnitID,
				ut.Name,
				u.SquareFootage,
				null,
				null,
				null,
				'Vacant',
				null,
				null,
				null,
				#pad.StartDate,
				#pad.EndDate
		FROM Unit u
			INNER JOIN Building b on u.BuildingID = b.BuildingID
			INNER JOIN Property prop on b.PropertyID = prop.PropertyID
			INNER JOIN UnitType ut on u.UnitTypeID = ut.UnitTypeID
			INNER JOIN #PropertiesAndDates #pad ON prop.PropertyID = #pad.PropertyID
			LEFT JOIN #Occupancy #occ ON #occ.UnitID = u.UnitID
		WHERE u.ExcludedFromOccupancy = 0
			AND (u.DateRemoved IS NULL OR u.DateRemoved > #pad.EndDate)
			AND #occ.UnitID IS NULL

			

	--UPDATE #Occupancy SET ResidentName = (SELECT TOP 1 PreferredName + ' ' + LastName
	UPDATE #Occupancy SET PersonID = (SELECT TOP 1 Person.PersonID
											FROM Person 
												INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
												INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
												INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
												INNER JOIN #PropertiesAndDates #pad ON PersonTypeProperty.PropertyID = #pad.PropertyID
											WHERE PersonLease.LeaseID = #Occupancy.LeaseID
											  AND PersonType.[Type] = 'Resident'				   
											  AND PersonLease.MainContact = 1	
											  AND (PersonLease.MoveOutDate IS NULL OR #Occupancy.MoveInDate IS NULL OR PersonLease.MoveOutDate >= #pad.StartDate)
											  AND (PersonLease.MoveInDate IS NULL OR #Occupancy.MoveOutDate IS NULL OR PersonLease.MoveInDate <= #pad.EndDate)
											  AND (PersonLease.ResidencyStatus NOT IN ('Cancelled', 'Pending', 'Pending Transfer', 'Pending Renewal'))
											  AND PersonLease.HouseholdStatus IN (SELECT Name
																					  FROM PickListItem
																					  WHERE [Type] = 'HouseholdStatus'
																						AND PickListItem.AccountID = PersonLease.AccountID
																						AND (IsNotOccupant = 0
																								OR IsNotOccupant IS NULL))
											ORDER BY PersonLease.OrderBy)

	UPDATE #Occupancy SET ResidentName = (SELECT PreferredName + ' ' + LastName
											  FROM Person
											  WHERE PersonID = #Occupancy.PersonID)

	UPDATE #Occupancy SET EmailAddress = (SELECT Email
											  FROM Person
											  WHERE PersonID = #Occupancy.PersonID)

	---- update occupancy counts
	UPDATE #Occupancy SET MajorOccupants = (SELECT COUNT(DISTINCT per.PersonID)
											  FROM Person per
												  INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID
												  INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
												  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
												  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
												  INNER JOIN Building b ON u.BuildingID = b.BuildingID
												  INNER JOIN #PropertiesAndDates #pad ON b.PropertyID = #pad.PropertyID
												  CROSS APPLY [dbo].[GetPersonAge](per.PersonID, #pad.EndDate) [Age]
												  --INNER JOIN #ChargeDistributions #cd ON #Charges.ChargeDistributionDetailID = #cd.ChargeDistributionDetailID
											  WHERE ulg.UnitLeaseGroupID = #Occupancy.UnitLeaseGroupID
												AND b.PropertyID = @propertyID
											    AND (pl.MoveOutDate IS NULL OR #Occupancy.MoveInDate IS NULL OR pl.MoveOutDate >= #pad.StartDate)
											    AND (pl.MoveInDate IS NULL OR #Occupancy.MoveOutDate IS NULL OR pl.MoveInDate <= #pad.EndDate)
												AND (pl.ResidencyStatus NOT IN ('Cancelled', 'Pending', 'Pending Transfer', 'Pending Renewal'))
											    AND pl.HouseholdStatus IN (SELECT Name
																			FROM PickListItem
																			WHERE [Type] = 'HouseholdStatus'
																				AND PickListItem.AccountID = pl.AccountID
																				AND (IsNotOccupant = 0
																				     OR IsNotOccupant IS NULL))
												AND l.LeaseID = (SELECT TOP 1 LeaseID 
																	FROM Lease 
																	WHERE LeaseStatus IN ('Current', 'Former', 'Under Eviction', 'Evicted')
																	  AND UnitLeaseGroupID = ulg.UnitLeaseGroupID
																	ORDER BY LeaseStartDate DESC)
												AND [Age].Age >= 18)

	UPDATE #Occupancy SET MinorOccupants = (SELECT COUNT(DISTINCT per.PersonID)
											  FROM Person per
												  INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID
												  INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
												  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
												  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
												  INNER JOIN Building b ON u.BuildingID = b.BuildingID
												  INNER JOIN #PropertiesAndDates #pad ON b.PropertyID = #pad.PropertyID
												  CROSS APPLY [dbo].[GetPersonAge](per.PersonID, #pad.EndDate) [Age]
												  --INNER JOIN #ChargeDistributions #cd ON #Charges.ChargeDistributionDetailID = #cd.ChargeDistributionDetailID
											  WHERE ulg.UnitLeaseGroupID = #Occupancy.UnitLeaseGroupID
												AND b.PropertyID = @propertyID
											    AND (pl.MoveOutDate IS NULL OR #Occupancy.MoveInDate IS NULL OR pl.MoveOutDate >= #pad.StartDate)
											    AND (pl.MoveInDate IS NULL OR #Occupancy.MoveOutDate IS NULL OR pl.MoveInDate <= #pad.EndDate)
												AND (pl.ResidencyStatus NOT IN ('Cancelled', 'Pending', 'Pending Transfer', 'Pending Renewal'))
											    AND pl.HouseholdStatus IN (SELECT Name
																			FROM PickListItem
																			WHERE [Type] = 'HouseholdStatus'
																				AND PickListItem.AccountID = pl.AccountID
																				AND (IsNotOccupant = 0
																				     OR IsNotOccupant IS NULL))
												AND l.LeaseID = (SELECT TOP 1 LeaseID 
																	FROM Lease 
																	WHERE LeaseStatus IN ('Current', 'Former', 'Under Eviction', 'Evicted')
																	  AND UnitLeaseGroupID = ulg.UnitLeaseGroupID
																	ORDER BY LeaseStartDate DESC)
												AND [Age].Age < 18)

	-- update vacant units that were vacant the whole date range
	--UPDATE #Occupancy SET ResidentName = 'Vacant',
	--					  MoveInDate = (SELECT #pap.StartDate FROM #PropertiesAndDates #pap WHERE PropertyID = #Occupancy.PropertyID),
	--					  MoveOutDate = (SELECT #pap.EndDate FROM #PropertiesAndDates #pap WHERE PropertyID = #Occupancy.PropertyID)
	--					WHERE LeaseID IS NULL

	--UPDATE #Occ SET MoveInDate = #pad.StartDate
	--	FROM #Occupancy #Occ 
	--		INNER JOIN #PropertiesAndDates #pad ON #Occ.PropertyID = #pad.PropertyID
	--	WHERE #Occ.MoveInDate IS NULL

	--UPDATE #Occ SET MoveOutDate = #pad.EndDate
	--	FROM #Occupancy #Occ 
	--		INNER JOIN #PropertiesAndDates #pad ON #Occ.PropertyID = #pad.PropertyID
	--	WHERE #Occ.MoveOutDate IS NULL


	UPDATE #Occupancy SET MajorOccupants = 0	
		WHERE MajorOccupants IS NULL

	UPDATE #Occupancy SET MinorOccupants = 0
		WHERE MinorOccupants IS NULL


	SELECT	DISTINCT
			PropertyID,
			PropertyName,
			UnitNumber,
			PaddedUnitNumber,
			UnitID,
			UnitType,
			SquareFootage,
			MajorOccupants,
			MinorOccupants,
			ResidentName,
			EmailAddress,
			LeaseID,
			UnitLeaseGroupID,
			MoveInDate,
			MoveOutDate
		FROM #Occupancy #occ
		WHERE LeaseID IS NOT NULL
		ORDER BY #occ.PaddedUnitNumber, #occ.UnitType, #occ.MoveInDate

END
GO
