SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Jordan Betteridge with Rick's Ponytail
-- Create date: Dec. 15, 2015
-- Description:	S2 Occupancy Detail Report 
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_S2_OccupancyDetail] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY, 
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
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

    CREATE TABLE #Occupancy (
		PonytailID uniqueidentifier null,
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) null,
		UnitNumber nvarchar(20) null,
		PaddedUnitNumber nvarchar(20) null,
		UnitID uniqueidentifier null,
		UnitType nvarchar(250) null,
		SquareFootage int null,
		Occupants int null,
		ResidentName nvarchar(1000) null,
		LeaseID uniqueidentifier null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null)

	INSERT INTO #Occupancy
		SELECT
			NEWID(),
			prop.PropertyID,
			prop.Name,
			u.Number,
			u.PaddedNumber,
			u.UnitID,
			ut.Name,
			ut.SquareFootage,
			null,
			Ponytail.ResidentName,
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
			AND prop.PropertyID IN (SELECT Value FROM @propertyIDs)
			AND (Ponytail.MoveOutDate IS NULL OR (Ponytail.MoveOutDate IS NOT NULL AND Ponytail.MoveOutDate >= #pad.StartDate))
			AND (Ponytail.MoveInDate IS NULL OR (Ponytail.MoveInDate <= #pad.EndDate))
			AND u.ExcludedFromOccupancy = 0
			AND (u.DateRemoved IS NULL OR u.DateRemoved > #pad.EndDate)

	INSERT INTO #Occupancy
		SELECT DISTINCT
				NEWID(),
				prop.PropertyID,
				prop.Name,
				u.Number,
				u.PaddedNumber,
				u.UnitID,
				ut.Name,
				u.SquareFootage,
				null,
				'Vacant',
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

			

	UPDATE #Occupancy SET ResidentName = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
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
													 FOR XML PATH ('')), 1, 2, '')

	---- update occupancy count
	UPDATE #Occupancy SET Occupants = (SELECT COUNT(pl.PersonLeaseID)
											  FROM PersonLease pl
												  INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
												  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
												  INNER JOIN Unit u ON ulg.UnitID = u.UnitID
												  INNER JOIN Building b ON u.BuildingID = b.BuildingID
												  INNER JOIN #PropertiesAndDates #pad ON b.PropertyID = #pad.PropertyID
												  --INNER JOIN #ChargeDistributions #cd ON #Charges.ChargeDistributionDetailID = #cd.ChargeDistributionDetailID
											  WHERE ulg.UnitLeaseGroupID = #Occupancy.UnitLeaseGroupID
												AND b.PropertyID IN (SELECT Value FROM @propertyIDs)
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
																	ORDER BY LeaseStartDate DESC))

	-- update vacant units that were vacant the whole date range
	UPDATE #Occupancy SET ResidentName = 'Vacant',
						  MoveInDate = (SELECT #pap.StartDate FROM #PropertiesAndDates #pap WHERE PropertyID = #Occupancy.PropertyID),
						  MoveOutDate = (SELECT #pap.EndDate FROM #PropertiesAndDates #pap WHERE PropertyID = #Occupancy.PropertyID)
						WHERE LeaseID IS NULL

	UPDATE #Occ SET MoveInDate = #pad.StartDate
		FROM #Occupancy #Occ 
			INNER JOIN #PropertiesAndDates #pad ON #Occ.PropertyID = #pad.PropertyID
		WHERE #Occ.MoveInDate IS NULL

	UPDATE #Occ SET MoveOutDate = #pad.EndDate
		FROM #Occupancy #Occ 
			INNER JOIN #PropertiesAndDates #pad ON #Occ.PropertyID = #pad.PropertyID
		WHERE #Occ.MoveOutDate IS NULL

--	---- insert vacant records where needed
	-- Add vacants for in between date ranges
	INSERT INTO #Occupancy
		SELECT DISTINCT
			#occ2.PonytailID,
			#occ1.PropertyID,
			#occ1.PropertyName,
			#occ1.UnitNumber,
			#occ1.PaddedUnitNumber,
			#occ1.UnitID,
			#occ1.UnitType,
			#occ1.SquareFootage,
			null,
			'Vacant',
			null,
			null,
			DATEADD(DAY, 1, #occ1.MoveOutDate),
			DATEADD(DAY, -1, #occ2.MoveInDate)
		FROM #Occupancy #occ1
			INNER JOIN #Occupancy #occ2 ON #occ1.UnitID = #occ2.UnitID 
			LEFT JOIN #Occupancy #noSkips ON #occ1.UnitID = #noSkips.UnitID AND #occ1.MoveInDate < #noSkips.MoveInDate AND #occ2.MoveInDate > #noSkips.MoveInDate AND #noSkips.MoveOutDate IS NOT NULL
		WHERE #occ1.MoveInDate < #occ2.MoveInDate
		  AND #noSkips.PonytailID IS NULL
		  AND #occ1.MoveOutDate < #occ2.MoveInDate

	-- vacants for start date to move in date
	INSERT INTO #Occupancy
		SELECT DISTINCT
			#occ1.PonytailID,
			#occ1.PropertyID,
			#occ1.PropertyName,
			#occ1.UnitNumber,
			#occ1.PaddedUnitNumber,
			#occ1.UnitID,
			#occ1.UnitType,
			#occ1.SquareFootage,
			null,
			'Vacant',
			null,
			null,
			#pad.StartDate,
			DATEADD(DAY, -1, #occ1.MoveInDate)
		FROM #Occupancy #occ1
			INNER JOIN #PropertiesAndDates #pad ON #occ1.PropertyID = #pad.PropertyID
			LEFT JOIN #Occupancy #occ2 ON #occ1.UnitID = #occ2.UnitID AND (#occ1.MoveInDate < #occ2.MoveInDate OR #occ2.PonytailID IS NULL)
			LEFT JOIN #Occupancy #noSkips ON #occ1.UnitID = #noSkips.UnitID AND #noSkips.MoveInDate < #occ1.MoveInDate
		WHERE #occ1.MoveInDate > #pad.StartDate
			--AND #occ1.ResidentName <> 'Vacant'
		  AND #noSkips.PonytailID IS NULL

	-- Vacancies for move out to end
	INSERT INTO #Occupancy
		SELECT DISTINCT
			#occ1.PonytailID,
			#occ1.PropertyID,
			#occ1.PropertyName,
			#occ1.UnitNumber,
			#occ1.PaddedUnitNumber,
			#occ1.UnitID,
			#occ1.UnitType,
			#occ1.SquareFootage,
			null,
			'Vacant',
			null,
			null,
			DATEADD(DAY, 1, #occ1.MoveOutDate),
			#pad.EndDate
		FROM #Occupancy #occ1
			INNER JOIN #PropertiesAndDates #pad ON #occ1.PropertyID = #pad.PropertyID
			LEFT JOIN #Occupancy #occ2 ON #occ1.UnitID = #occ2.UnitID AND (#occ1.MoveOutDate > #occ2.MoveOutDate OR #occ2.PonytailID IS NULL)
			LEFT JOIN #Occupancy #noSkips ON #occ1.UnitID = #noSkips.UnitID AND #noSkips.MoveOutDate > #occ1.MoveOutDate AND #occ1.MoveOutDate IS NOT NULL
			LEFT JOIN #Occupancy #noPeachesAfter ON #occ1.UnitID = #noPeachesAfter.UnitID AND #occ1.MoveInDate < #noPeachesAfter.MoveInDate
		WHERE #occ1.MoveOutDate < #pad.EndDate
		  --AND #occ1.ResidentName <> 'Vacant'
		  AND #noSkips.PonytailID IS NULL
		  AND #noPeachesAfter.PonytailID IS NULL
		  AND #occ1.MoveInDate < #occ1.MoveOutDate

	UPDATE #Occupancy SET Occupants = 0	
		WHERE Occupants IS NULL

	SELECT * FROM #Occupancy #occ
		ORDER BY #occ.PaddedUnitNumber, #occ.UnitType, #occ.MoveInDate

END
GO
