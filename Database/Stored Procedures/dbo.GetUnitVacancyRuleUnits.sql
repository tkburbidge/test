SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[GetUnitVacancyRuleUnits]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GUIDCOLLECTION READONLY,
	@date date
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #VacantUnits
	(
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(20) null,
		SquareFootage int not null,
		UnitTypeName nvarchar(250) not null,
		BuildingName nvarchar(15) not null,
		AffordableProgramName nvarchar(50) null,
		MoveOutDate date null,
		LeaseID uniqueidentifier null,
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null
	)

	CREATE TABLE #LeasesAndUnits (
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
		
	INSERT #LeasesAndUnits
		EXEC [GetConsolodatedOccupancyNumbers] @accountID, @date, null, @propertyIDs

    INSERT INTO #VacantUnits
		SELECT 
			u.UnitID AS 'UnitID',
			u.Number AS 'UnitNumber',
			u.SquareFootage AS 'SquareFootage',
			ut.Name AS 'UnitTypeName',
			b.Name AS 'BuildingName',
			(SELECT TOP 1 CAST(apa.UnitAmount AS nvarchar(10)) + '/' + CAST(apa.AmiPercent AS nvarchar(10))
				FROM AffordableProgramAllocation apa
					INNER JOIN UnitAffordableProgramDesignation uapd ON apa.AffordableProgramAllocationID = uapd.AffordableProgramAllocationID
				WHERE uapd.UnitID = u.UnitID
				ORDER BY apa.AmiPercent) AS 'AffordableProgramName',
			(SELECT MAX(MoveOutDate) FROM PersonLease pl WHERE lu.OccupiedLastLeaseID = pl.LeaseID) AS 'MoveOutDate',
			lu.OccupiedLastLeaseID AS 'LeaseID',
			b.PropertyID AS 'PropertyID',
			p.Name AS 'PropertyName'
		FROM #LeasesAndUnits lu
			INNER JOIN Unit u ON lu.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
		WHERE u.AccountID = @accountID
			AND b.PropertyID IN (SELECT Value FROM @propertyIDs)
			AND (lu.OccupiedUnitLeaseGroupID IS NULL
				OR lu.OccupiedMoveOutDate IS NOT NULL)

	UPDATE #VacantUnits
		SET MoveOutDate = (SELECT MAX(pl.MoveOutDate)
							FROM UnitLeaseGroup ulg
								INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND ulg.UnitID = #VacantUnits.UnitID
												AND l.LeaseID = (SELECT TOP 1 LeaseID
																		FROM Lease
																		WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																		AND LeaseStatus IN ('Former', 'Evicted')
																		ORDER BY LeaseEndDate DESC)
								INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
							WHERE ulg.UnitID = #VacantUnits.UnitID)
		WHERE MoveOutDate IS NULL

	UPDATE #VacantUnits
		SET LeaseID = (SELECT TOP 1 pl.LeaseID
							FROM UnitLeaseGroup ulg
								INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND ulg.UnitID = #VacantUnits.UnitID
												AND l.LeaseID = (SELECT TOP 1 LeaseID
																		FROM Lease
																		WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
																		AND LeaseStatus IN ('Former', 'Evicted')
																		ORDER BY LeaseEndDate DESC)
								INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
							WHERE ulg.UnitID = #VacantUnits.UnitID)
		WHERE LeaseID IS NULL

	SELECT * FROM #VacantUnits
		ORDER BY PropertyName, MoveOutDate

END
GO
