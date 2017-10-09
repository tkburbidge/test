SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[GetResidentCounts]
	@accountID bigint,
	@propertyIDs GuidCollection readonly,
	@date date
AS
BEGIN
	
	DECLARE @maxBirthdate date = DATEADD(YEAR, -18, @date)

	CREATE TABLE #ConsolidatedOccupancyNumbers 
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		OccupiedUnitLeaseGroupID uniqueidentifier null,
		OccupiedLastLeaseID uniqueidentifier null,
		OccupiedMoveInDate date null,
		OccupiedNTVDate date null,
		OccupiedMoveOutDate date null,
		OccupiedIsMovedOut bit null,
		PendingUnitLeaseGroupID uniqueidentifier null,
		PendingLeaseID uniqueidentifier,
		PendingApplicationDate date null,
		PendingMoveInDate date null
	)

	INSERT INTO #ConsolidatedOccupancyNumbers EXEC [GetConsolodatedOccupancyNumbers] @accountID, @date, null, @propertyIDs


	CREATE TABLE #ResidentCounts
	(
		PropertyID uniqueidentifier,
		TotalMainContacts int,
		TotalAdults int
	)

	INSERT INTO #ResidentCounts
		SELECT #occ.PropertyID,
				COUNT(DISTINCT pl.PersonID) as 'TotalMainContacts',
				0 as 'TotalAdults'
		FROM PersonLease pl
			INNER JOIN #ConsolidatedOccupancyNumbers #occ ON pl.LeaseID = #occ.OccupiedLastLeaseID
		WHERE pl.MoveInDate <= @date 
		  AND (pl.MoveOutDate > @date OR pl.MoveOutDate IS NULL)
		  AND pl.MainContact = 1
		GROUP BY #occ.PropertyID

	
	UPDATE #rc
		SET #rc.TotalAdults = (SELECT COUNT(DISTINCT pl.PersonID) 
									FROM PersonLease pl
										INNER JOIN #ConsolidatedOccupancyNumbers #occ on pl.LeaseID = #occ.OccupiedLastLeaseID
										INNER JOIN Person p on pl.PersonID = p.PersonID
									WHERE #occ.PropertyID = #rc.PropertyID
									  AND pl.MoveInDate <= @date 
									  AND (pl.MoveOutDate > @date OR pl.MoveOutDate IS NULL)
									  AND p.Birthdate <= @maxBirthdate)
		FROM #ResidentCounts #rc

	SELECT * FROM #ResidentCounts
END


IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AFF_GetRecertifications]') AND type in (N'P', N'PC'))
BEGIN
	EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[AFF_GetRecertifications] AS' 
END
GO
