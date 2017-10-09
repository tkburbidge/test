SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[AFF_GetSetAsideCompliance] 
	@accountID bigint,
	@date datetime,
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		EndDate [Date] NOT NULL)

	CREATE TABLE #UnitCounts (
		PropertyID uniqueidentifier not null,
		UnitCount int not null
	)

	CREATE TABLE #Certifications (
		AffordableProgramAllocationID uniqueidentifier not null,
		EffectiveDate date not null,
		UnitID uniqueidentifier not null
	)

	CREATE TABLE #Allocations (
		AffordableProgramAllocationID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar (50) not null,
		ProgramType nvarchar (50) not null,
		PercentGoal int null,
		NumberGoal int null,
		CurrentPercent money not null,
		QualifiedUnitCount int not null
	)

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

	INSERT #PropertiesAndDates 
		SELECT #pids.PropertyID, COALESCE(pap.EndDate, @date)
			FROM #PropertyIDs #pids 
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	-- Get all non-market, non-removed, non-excluded, non-holding-unit, and non-exempt units in each property
	INSERT #UnitCounts
		SELECT
			#pad.PropertyID AS 'PropertyID',
			0 AS 'UnitCount'
		FROM #PropertiesAndDates #pad

	UPDATE #UnitCounts
		SET UnitCount = (SELECT COUNT (*)
							FROM Unit u
								INNER JOIN Building b ON u.BuildingID = b.BuildingID
								INNER JOIN Property p ON b.PropertyID = p.PropertyID
								INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = b.PropertyID
							WHERE #UnitCounts.PropertyID = p.PropertyID
								AND u.AccountID = @accountID
								AND (u.DateRemoved IS NULL OR u.DateRemoved > #pad.EndDate)
								AND u.IsMarket = 0
								AND u.ExcludedFromOccupancy = 0
								AND u.IsHoldingUnit = 0
								AND u.IsExempt = 0)

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @date, @accountingPeriodID, @propertyIDs

	-- Get completed certifications with a current lease
	INSERT #Certifications
		SELECT 
			capa.AffordableProgramAllocationID AS 'AffordableProgramAllocationID',
			c.EffectiveDate,
			ulg.UnitID
		FROM Certification c
			INNER JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
			INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
			INNER JOIN Lease l ON c.LeaseID = l.LeaseID
			INNER JOIN #LeasesAndUnits #lau ON l.LeaseID = #lau.OccupiedLastLeaseID
		WHERE c.AccountID = @accountID
			AND c.CertificationID IN (SELECT TOP 1 c2.CertificationID
										FROM Certification c2
										WHERE c2.CertificationGroupID = c.CertificationGroupID
											AND c2.EffectiveDate < #pad.EndDate
											AND c2.DateCompleted IS NOT NULL
											AND (SELECT COUNT(cs.CertificationStatusID)
																FROM CertificationStatus cs
																WHERE cs.CertificationID = c2.CertificationID
																	AND cs.[Status] = 'Cancelled') = 0
									ORDER BY c2.EffectiveDate DESC)

	-- Get affordable program allocations
	INSERT #Allocations
		SELECT
			apa.AffordableProgramAllocationID AS 'AffordableProgramAllocationID',
			p.PropertyID AS 'PropertyID',
			p.[Name] AS 'PropertyName',
			(CASE 
				WHEN ap.IsHUD = 1
					THEN apa.SubsidyType
				ELSE ap.[Type]
			END) AS 'ProgramType',
			(CASE 
				WHEN ap.IsHUD = 1
					THEN null
				WHEN apa.UnitAmountIsPercent = 1
					THEN apa.UnitAmount
				ELSE null
			END) AS 'PercentGoal',
			(CASE 
				WHEN ap.IsHUD = 1
					THEN apa.NumberOfUnits
				WHEN apa.UnitAmountIsPercent = 0
					THEN apa.UnitAmount
				ELSE null
			END) AS 'NumberGoal',
			0 AS 'CurrentPercent',
			0 AS 'QualifiedUnitCount'
		FROM AffordableProgram ap
			INNER JOIN Property p ON ap.PropertyID = p.PropertyID
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
			INNER JOIN AffordableProgramAllocation apa ON ap.AffordableProgramID = apa.AffordableProgramID
		WHERE ap.AccountID = @accountID

	UPDATE #Allocations
		SET CurrentPercent = CAST((CAST((SELECT COUNT(*)
									FROM #Certifications c
									WHERE c.AffordableProgramAllocationID = #Allocations.AffordableProgramAllocationID) AS MONEY) / 
									CAST((SELECT UnitCount
										FROM #UnitCounts uc
										WHERE uc.PropertyID = #Allocations.PropertyID) AS MONEY) * 100)
									AS MONEY)

	UPDATE #Allocations
		SET QualifiedUnitCount = (SELECT COUNT(*)
									FROM #Certifications c
									WHERE c.AffordableProgramAllocationID = #Allocations.AffordableProgramAllocationID)

	SELECT * FROM #Allocations
END
GO
