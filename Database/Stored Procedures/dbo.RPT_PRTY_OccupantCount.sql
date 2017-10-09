SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_PRTY_OccupantCount] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0,
	@propertyIDs GuidCollection READONLY, 
	@date date = null,
	@includePendingMoveIns bit = 0,
	@includeVacant bit = 0
AS

--DECLARE @accountID bigint
DECLARE @accountingPeriodID uniqueidentifier = null

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #WhereAreMyPonyTails (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier null,
		PropertyName nvarchar(50) null,
		UnitNumber nvarchar(50) null,		
		SquareFootage int null,
		ResidentNames nvarchar(1000) null,
		LeaseID uniqueidentifier null,
		LeaseStart date null,
		LeaseEnd date null,
		LastMoveOutDate date null,
		OccupancyCount int null,
		MainContactCount int null)

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


	--SET @accountID = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID IN (SELECT Value FROM @propertyIDs))

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @date, @accountingPeriodID, @propertyIDs	

	INSERT #WhereAreMyPonyTails
		SELECT PropertyID, UnitID, null, UnitNumber, null, null, null, null, null, null, null, null
			FROM #LeasesAndUnits

	UPDATE #WhereAreMyPonyTails SET SquareFootage = (SELECT u.SquareFootage
														 FROM Unit u 
														 WHERE #WhereAreMyPonyTails.UnitID = u.UnitID)

	UPDATE #WhereAreMyPonyTails SET LeaseID = (SELECT TOP 1 l.LeaseID
												   FROM #LeasesAndUnits #lau
													   INNER JOIN Lease l ON #lau.OccupiedUnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStartDate <= @date AND l.LeaseEndDate >= @date
												   WHERE #WhereAreMyPonyTails.UnitID = #lau.UnitID)

	UPDATE #WhereAreMyPonyTails SET LeaseID = (SELECT l.LeaseID
												   FROM #LeasesAndUnits #lau
												       INNER JOIN Lease l ON #lau.OccupiedLastLeaseID = l.LeaseID
												   WHERE #WhereAreMyPonyTails.UnitID = #lau.UnitID)
		WHERE #WhereAreMyPonyTails.LeaseID IS NULL

	UPDATE #WhereAreMyPonyTails SET LeaseID = (SELECT TOP 1 l.LeaseID
												   FROM UnitLeaseGroup ulg
												       INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
													   INNER JOIN Unit u ON ulg.UnitID = u.UnitID
													   INNER JOIN #LeasesAndUnits #lau ON u.UnitID = #lau.UnitID
												   WHERE #WhereAreMyPonyTails.UnitID = #lau.UnitID
													 AND l.LeaseStartDate < @date
												   ORDER BY l.LeaseStartDate DESC)
			WHERE #WhereAreMyPonyTails.LeaseID IS NULL 
												   

	UPDATE #WhereAreMyPonyTails SET LastMoveOutDate = (SELECT OccupiedMoveOutDate
														   FROM #LeasesAndUnits 
														   WHERE #WhereAreMyPonyTails.UnitID = UnitID)

	UPDATE #WhereAreMyPonyTails SET LeaseID = NULL, LastMoveOutDate = NULL
		FROM #WhereAreMyPonyTails
		WHERE LastMoveOutDate IS NOT NULL
		  AND LastMoveOutDate < @date

	UPDATE #wampt SET LeaseStart = l.LeaseStartDate, LeaseEnd = l.LeaseEndDate
		FROM #WhereAreMyPonyTails #wampt
			INNER JOIN Lease l ON #wampt.LeaseID = l.LeaseID
			
	UPDATE #WhereAreMyPonyTails SET OccupancyCount = (SELECT COUNT(pl.PersonLeaseID)
														  FROM PersonLease pl
															  LEFT JOIN PickListItem pli ON pl.HouseholdStatus = pli.Name AND pli.AccountID = @accountID AND pli.[Type] = 'HouseholdStatus'
														  WHERE #WhereAreMyPonyTails.LeaseID = pl.LeaseID															
															AND (pli.IsNotOccupant = 0 OR pli.IsNotOccupant IS NULL)
															AND pl.MoveInDate <= @date AND (pl.MoveOutDate IS NULL OR pl.MoveOutDate >= @date))

	UPDATE #WhereAreMyPonyTails SET MainContactCount = (SELECT COUNT(pl.PersonLeaseID)
															FROM PersonLease pl
																LEFT JOIN PickListItem pli ON pl.HouseholdStatus = pli.Name AND pli.AccountID = @accountID AND pli.[Type] = 'HouseholdStatus'
															WHERE #WhereAreMyPonyTails.LeaseID = pl.LeaseID
															  AND (pli.IsNotOccupant = 0 OR pli.IsNotOccupant IS NULL)
															  AND pl.MainContact = 1
															  AND pl.MoveInDate <= @date AND (pl.MoveOutDate IS NULL OR pl.MoveOutDate >= @date))

	UPDATE #WhereAreMyPonyTails SET ResidentNames = (STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
																 FROM Person 
																	 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
																	 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
																	 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
																 WHERE PersonLease.LeaseID = #WhereAreMyPonyTails.LeaseID
																   AND PersonType.[Type] = 'Resident'				   
																   AND PersonLease.MainContact = 1		
																   AND PersonLease.MoveInDate <= @date AND (PersonLease.MoveOutDate IS NULL OR PersonLease.MoveOutDate >= @date)		   
																 FOR XML PATH ('')), 1, 2, ''))
	
		SELECT	#wampt.PropertyID,
				prop.Name AS 'PropertyName',
				#wampt.UnitID,
				#wampt.UnitNumber,
				#wampt.SquareFootage,
				#wampt.ResidentNames,
				#wampt.LeaseID,
				#wampt.LeaseStart,
				#wampt.LeaseEnd,
				#wampt.OccupancyCount,
				#wampt.MainContactCount,
				#wampt.LastMoveOutDate
		FROM #WhereAreMyPonyTails #wampt
			INNER JOIN Property prop ON #wampt.PropertyID = prop.PropertyID
			INNER JOIN Unit u ON u.UnitID = #wampt.UnitID
			LEFT JOIN #LeasesAndUnits #pendingLease ON #wampt.LeaseID = #pendingLease.PendingLeaseID
			CROSS APPLY GetUnitStatusByUnitID(u.UnitID, @date) [unitStatus]
		WHERE (#pendingLease.PendingLeaseID IS NULL OR @includePendingMoveIns = 1)					--should we include pending?
		  AND ((#wampt.LeaseID IS NOT NULL AND #wampt.OccupancyCount > 0) OR @includeVacant = 1)	--should we include vacant?
		ORDER BY prop.Name, u.PaddedNumber

END
GO
