SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: June 13, 2016
-- Description:	Gets some occupancy percentages
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_Q10PA_GetOccupancyPercentages] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@accountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS

DECLARE @i int = 1
DECLARE @maxI int 
DECLARE @unitID uniqueidentifier, @leaseID uniqueidentifier
DECLARE @totalNumberOfDays int
DECLARE @j int, @maxJ int

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)

	CREATE TABLE #MagicalUnitAndPonyTailInfo (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		OccupiedDays int null,
		OccupableDays int null)

	CREATE TABLE #UnitsAndStati (
		PropertyID uniqueidentifier not null,
		UnitNoteID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		StateOfUnit nvarchar(50) null,
		StateDate date null)								

	CREATE TABLE #UnitsAndMovies (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		LeaseID uniqueidentifier not null,
		MoveIn date null,
		MoveOut date null)

	CREATE TABLE #OrderedUnits (
		[Sequence]	int identity,
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null)

	CREATE TABLE #StatesForAUnit (
		[Sequence] int identity,
		UnitID uniqueidentifier not null,
		[Status] nvarchar(50) null,
		StartDate date null,
		EndDate date null,
		DaysInState int null)

	CREATE TABLE #DaysOccupied (
		[Sequence] int identity,
		UnitID uniqueidentifier not null,
		LeaseID uniqueidentifier not null,
		MoveInDate date null,
		MoveOutDate date null,
		DaysOccupied int null)

	INSERT #PropertiesAndDates
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	INSERT #OrderedUnits
		SELECT	#pad.PropertyID, u.UnitID
			FROM Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
			
	INSERT #UnitsAndStati
		SELECT	ut.PropertyID, [daStatus].UnitNoteID, u.UnitID, [daStatus].Name, [daStatus].[Date]
			FROM Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
				LEFT JOIN 
						(SELECT un.UnitID, un.[Date], us.Name, un.UnitNoteID
							FROM UnitNote un
								INNER JOIN UnitStatus us ON un.UnitStatusID = us.UnitStatusID) [daStatus] ON u.UnitID = [daStatus].UnitID

	INSERT #UnitsAndMovies
		SELECT	#pad.PropertyID, u.UnitID, l.LeaseID, pl.MoveInDate, pl.MoveOutDate
			FROM UnitLeaseGroup ulg
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND (pl.MoveOutDate IS NULL OR pl.MoveOutDate >= #pad.StartDate)

	SET @maxI = (SELECT MAX([Sequence]) FROM #OrderedUnits)
	SET @totalNumberOfDays = DATEDIFF(DAY, @startDate, @endDate)

	WHILE (@i <= @maxI)
	BEGIN
		SELECT @unitID = UnitID
			FROM #OrderedUnits
			WHERE [Sequence] = @i

		TRUNCATE TABLE #StatesForAUnit
		TRUNCATE TABLE #DaysOccupied

		INSERT #StatesForAUnit
			SELECT	UnitID, StateOfUnit,  
					CASE WHEN (StateDate < @startDate) 
						THEN @startDate 
						ELSE StateDate 
						END, 
					null, null
				FROM #UnitsAndStati
				WHERE UnitID = @unitID
				  AND ((StateDate > @startDate)
				    OR (UnitNoteID = (SELECT TOP 1 UnitNoteID
										  FROM #UnitsAndStati
										  WHERE UnitID = @unitID
										    AND StateDate <= @startDate
										  ORDER BY StateDate DESC)))
				ORDER BY StateDate

		SET @j = 1
		SET @maxJ = (SELECT MAX([Sequence]) FROM #StatesForAUnit)

		IF (@j = @maxJ)
		BEGIN
			UPDATE #StatesForAUnit SET EndDate = @endDate
		END
		ELSE
		BEGIN
			WHILE (@j < @maxJ)
			BEGIN
				UPDATE #s4au SET EndDate = DATEADD(DAY, -1, #s4au1.StartDate)
					FROM #StatesForAUnit #s4au
						INNER JOIN #StatesForAUnit #s4au1 ON #s4au.[Sequence] + 1 = #s4au.[Sequence]
					WHERE #s4au.[Sequence] = @j
				SET @j = @j + 1
			END
			UPDATE #StatesForAUnit SET EndDate = @endDate WHERE [Sequence] = @maxJ
		END

		UPDATE #StatesForAUnit SET DaysInState = DATEDIFF(DAY, StartDate, EndDate) + 1

		INSERT #DaysOccupied
			SELECT	DISTINCT
					#um.UnitID, #um.LeaseID,
					(SELECT MIN(pl.MoveInDate)
						FROM PersonLease pl
						WHERE pl.LeaseID = #um.LeaseID) AS 'MoveMeIn',
					(SELECT MAX(pl.MoveOutDate)
						FROM PersonLease pl
							LEFT JOIN PersonLease plMO ON pl.LeaseID = plMO.LeaseID AND plMO.MoveOutDate IS NULL
						WHERE pl.LeaseID = #um.LeaseID
						  AND plMO.PersonLeaseID IS NULL),
					null
				FROM #UnitsAndMovies #um
				WHERE #um.UnitID = @unitID
				GROUP BY #um.UnitID, #um.LeaseID
				ORDER BY 'MoveMeIn'

		UPDATE #DaysOccupied SET MoveInDate = @startDate WHERE MoveInDate < @startDate
		UPDATE #DaysOccupied SET MoveOutDate = @endDate WHERE MoveOutDate > @endDate OR MoveOutDate IS NULL
		UPDATE #DaysOccupied SET DaysOccupied = DATEDIFF(DAY, MoveInDate, MoveOutDate) + 1

		INSERT #MagicalUnitAndPonyTailInfo
			SELECT	#ou.PropertyID,
					#ou.UnitID,
					(SELECT SUM(DaysOccupied)
						FROM #DaysOccupied
						WHERE UnitID = @unitID),
					(SELECT SUM(DaysInState)
						FROM #StatesForAUnit
						WHERE [Status] NOT IN ('Down', 'Model', 'Admin'))
				FROM #OrderedUnits #ou
				WHERE #ou.UnitID = @unitID

		SET @i = @i + 1
	END

	SELECT  #mpt.PropertyID,
			prop.Name AS 'PropertyName',
			ISNULL(SUM(ISNULL(#mpt.OccupiedDays, 0)), 0) AS 'OccupiedDays',
			ISNULL(SUM(ISNULL(#mpt.OccupableDays, 0)), 0) AS 'OccupableDays'
		FROM #MagicalUnitAndPonyTailInfo #mpt
			INNER JOIN Property prop on #mpt.PropertyID = prop.PropertyID
		GROUP BY #mpt.PropertyID, prop.Name
END
GO
