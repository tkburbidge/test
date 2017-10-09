SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[RPT_CST_BLRK_WeeklyPropertySummaryStatistics] 
	-- Add the parameters for the stored procedure here
	--@propertyIDs GuidCollection READONLY, 
	@accountID bigint,
	@propertyID uniqueidentifier,
	@accountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS

DECLARE @propertyIDs GuidCollection

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #AllPropertyInfoEver (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		Traffic int null,
		NewLeases int null,
		VacantNotLeased int null,
		VacantLeased int null,
		VacantNotLeasedReady int null,
		VacantLeasedReady int null,
		LeaseExpirations30Days int null,
		LeaseRenewals30Days int null,
		LeaseExpirations60Days int null,
		LeaseRenewals60Days int null,
		FutureNoticeToVacate int null)

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

	CREATE TABLE #UnitsInfo (
		UnitID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		SquareFeet int null,
		UStatus nvarchar(50) null)

	IF @accountingPeriodID IS NOT NULL
	BEGIN
		SELECT TOP(1) @startDate = StartDate, @endDate = EndDate
		FROM PropertyAccountingPeriod
		WHERE PropertyID = @propertyID
			AND AccountingPeriodID = @accountingPeriodID
	END

	INSERT @propertyIDs SELECT @propertyID

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @endDate, null, @propertyIDs

	INSERT #AllPropertyInfoEver
		SELECT PropertyID, [Name], null, null, null, null, null, null, null, null, null, null, null
		FROM Property
		WHERE PropertyID = @propertyID

	INSERT #UnitsInfo
		SELECT  #lau.UnitID, ut.PropertyID, CASE WHEN (u.SquareFootage > 0) THEN u.SquareFootage ELSE ut.SquareFootage END, ISNULL([UStatus].[Status], 'Ready')
			FROM #LeasesAndUnits #lau
				INNER JOIN Unit u ON #lau.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				OUTER APPLY GetUnitStatusByUnitID(u.UnitID, @endDate) [UStatus]
			WHERE #lau.PropertyID = @propertyID

	CREATE TABLE #Applicants (
			[Type] nvarchar(100),
			PropertyID uniqueidentifier,
			UnitTypeID uniqueidentifier,
			UnitType nvarchar(100),
			UnitID uniqueidentifier,
			Unit nvarchar(50),
			PaddedUnitNumber nvarchar(50),
			UnitLeaseGroupID uniqueidentifier,
			LeaseID uniqueidentifier,
			IsRenewal bit					
		)

	INSERT INTO #Applicants
		SELECT 
			'NewApplication' AS 'Type',
			p.PropertyID,
			ut.UnitTypeID,
			ut.Name,
			u.UnitID,
			u.Number,
			u.PaddedNumber,
			l.UnitLeaseGroupID,
			l.LeaseID,
			0
		FROM Lease l
			INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN Property p ON ut.PropertyID = p.PropertyID		
		WHERE pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID	
												FROM PersonLease 
												WHERE LeaseID = l.LeaseID
												ORDER BY ApplicationDate, OrderBy, PersonLeaseID)
			AND pl.ApplicationDate >= @startDate
			AND pl.ApplicationDate <= @endDate
			AND p.PropertyID = @propertyID

	INSERT INTO #Applicants
		SELECT 
			'CancelledDeniedApplication' AS 'Type',
			p.PropertyID,
			ut.UnitTypeID,
			ut.Name,
			u.UnitID,
			u.Number,
			u.PaddedNumber,
			l.UnitLeaseGroupID,
			l.LeaseID,				
			0 AS 'IsRenewal'				
		FROM Lease l
			INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN Property p ON ut.PropertyID = p.PropertyID		
		WHERE pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID	
					FROM PersonLease 
					WHERE LeaseID = l.LeaseID
					ORDER BY MoveOutDate DESC, OrderBy, PersonLeaseID)
			AND l.LeaseStatus IN ('Cancelled', 'Denied')
			AND pl.MoveOutDate >= @startDate
			AND pl.MoveOutDate <= @endDate
			AND p.PropertyID = @propertyID

	INSERT INTO #Applicants
			SELECT 
				'SignedApplication' AS 'Type',
				p.PropertyID,
				ut.UnitTypeID,
				ut.Name,
				u.UnitID,
				u.Number,
				u.PaddedNumber,
				l.UnitLeaseGroupID,
				l.LeaseID,				
				0 AS 'Renewal'		
			FROM Lease l
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID		
			WHERE pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID	
										FROM PersonLease 
										WHERE LeaseID = l.LeaseID
											AND LeaseSignedDate IS NOT NULL
										ORDER BY LeaseSignedDate, OrderBy, PersonLeaseID)
				AND l.LeaseStatus NOT IN ('Cancelled', 'Denied')
				AND pl.LeaseSignedDate >= @startDate
				AND pl.LeaseSignedDate <= @endDate
				AND p.PropertyID = @propertyID

	UPDATE #Applicants SET IsRenewal = 1 WHERE LeaseID <> (SELECT TOP 1 LeaseID 
															   FROM Lease 
															   WHERE UnitLeaseGroupID = #Applicants.UnitLeaseGroupID
															   ORDER BY LeaseStartDate, DateCreated)

	UPDATE #Applicants SET [Type] = REPLACE([Type], 'Application', 'Renewal') WHERE IsRenewal = 1

	CREATE TABLE #ExpiringLeases (
		PropertyID uniqueidentifier not null,
		LeaseID uniqueidentifier not null,
		NextLeaseID uniqueidentifier null,
		DaysUntilExpired int null)

	INSERT #ExpiringLeases 
	SELECT #lau.PropertyID, l.LeaseID, null, DATEDIFF(DAY, @endDate, l.LeaseEndDate)
		FROM #LeasesAndUnits #lau
			INNER JOIN Lease l ON #lau.OccupiedUnitLeaseGroupID = l.UnitLeaseGroupID
		WHERE l.LeaseEndDate >= @endDate
			AND l.LeaseEndDate <= DATEADD(DAY, 60, @endDate)
			AND l.LeaseStatus IN ('Current', 'Under Eviction')--, 'Former', 'Evicted', 'Renewed')

	-- Get the next lease for the UnitLeaseGroup.  
	-- cl = Expiring Current Lease
	-- nl = Next Lease in order of LeaseEndDate.  The INNER JOIN Binds nl to ANY Lease which expires after the current.  The TOP 1 binds it to the first of those EndDates	  
	UPDATE #ExpiringLeases SET NextLeaseID = (SELECT nl.LeaseID
												  FROM Lease cl
												      INNER JOIN Lease nl ON cl.UnitLeaseGroupID = nl.UnitLeaseGroupID AND cl.LeaseEndDate < nl.LeaseEndDate AND cl.DateCreated <= nl.DateCreated
												  WHERE nl.LeaseID = (SELECT TOP 1 LeaseID 
																		  FROM Lease l
																		  WHERE UnitLeaseGroupID = nl.UnitLeaseGroupID
																		    AND l.UnitLeaseGroupID = cl.UnitLeaseGroupID
																		    AND cl.LeaseID = #ExpiringLeases.LeaseID
																		    AND l.LeaseEndDate > cl.LeaseEndDate
																		    AND l.LeaseStatus NOT IN ('Denied', 'Cancelled')
																		  ORDER BY LeaseEndDate))

	UPDATE #AllPropertyInfoEver SET NewLeases = ISNULL((SELECT COUNT(*) 
												FROM #Applicants #a
												WHERE #a.PropertyID = #AllPropertyInfoEver.PropertyID
												AND #a.[Type] = 'NewApplication'), 0)
	
	UPDATE #AllPropertyInfoEver SET VacantNotLeased = ISNULL((SELECT COUNT(DISTINCT #lau.UnitID)
															FROM #LeasesAndUnits #lau
															WHERE OccupiedUnitLeaseGroupID IS NULL
															  AND PendingUnitLeaseGroupID IS NULL
															  AND #lau.PropertyID = #AllPropertyInfoEver.PropertyID), 0)

	UPDATE #AllPropertyInfoEver SET VacantNotLeasedReady = ISNULL((SELECT COUNT(DISTINCT #lau.UnitID)
																FROM #LeasesAndUnits #lau
																INNER JOIN #UnitsInfo #ui ON #ui.UnitID = #lau.UnitID
																WHERE OccupiedUnitLeaseGroupID IS NULL
																  AND PendingUnitLeaseGroupID IS NULL
																  AND #lau.PropertyID = #AllPropertyInfoEver.PropertyID
																  AND #ui.UStatus = 'Ready'), 0)

	UPDATE #AllPropertyInfoEver SET VacantLeased = ISNULL((SELECT COUNT(DISTINCT #lau.UnitID)
														FROM #LeasesAndUnits #lau
														WHERE OccupiedUnitLeaseGroupID IS NULL
														  AND PendingUnitLeaseGroupID IS NOT NULL
														  AND #lau.PropertyID = #AllPropertyInfoEver.PropertyID), 0)
													  
	UPDATE #AllPropertyInfoEver SET VacantLeasedReady = ISNULL((SELECT COUNT(DISTINCT #lau.UnitID)
																FROM #LeasesAndUnits #lau
																INNER JOIN #UnitsInfo #ui ON #ui.UnitID = #lau.UnitID
																WHERE OccupiedUnitLeaseGroupID IS NULL
																  AND PendingUnitLeaseGroupID IS NOT NULL
																  AND #lau.PropertyID = #AllPropertyInfoEver.PropertyID
																  AND #ui.UStatus = 'Ready'), 0)
	
	UPDATE #AllPropertyInfoEver SET Traffic = ISNULL((SELECT COUNT(DISTINCT prst.ProspectID)
												FROM Prospect prst
													INNER JOIN PropertyProspectSource pps ON prst.PropertyProspectSourceID = pps.PropertyProspectSourceID
												WHERE pps.PropertyID = #AllPropertyInfoEver.PropertyID
													AND pps.PropertyID = @propertyID
													AND (@startDate <= (SELECT TOP 1 pn1.[Date] 
																		FROM PersonNote pn1											  
																		WHERE pn1.PersonID = prst.PersonID
																		  AND pn1.PropertyID = pps.PropertyID
																		  AND PersonType = 'Prospect'
																		  AND ContactType <> 'N/A' -- Do not include notes that were not contacts
																		ORDER BY [Date] ASC, [DateCreated] ASC))
												  AND (@endDate >= (SELECT TOP 1 pn1.[Date] 
																	FROM PersonNote pn1											  
																	WHERE pn1.PersonID = prst.PersonID
																	  AND pn1.PropertyID = pps.PropertyID
																	  AND PersonType = 'Prospect'
																	  AND ContactType <> 'N/A' -- Do not include notes that were not contacts
																	ORDER BY [Date] ASC, [DateCreated] ASC))), 0)

	UPDATE #AllPropertyInfoEver SET LeaseExpirations30Days = ISNULL((SELECT COUNT(*)
																		FROM #ExpiringLeases
																		WHERE DaysUntilExpired <= 30), 0)

	UPDATE #AllPropertyInfoEver SET LeaseRenewals30Days = ISNULL((SELECT COUNT(*)
																	FROM #ExpiringLeases
																	WHERE DaysUntilExpired <= 30
																	  AND NextLeaseID IS NOT NULL), 0)

	UPDATE #AllPropertyInfoEver SET LeaseExpirations60Days = ISNULL((SELECT COUNT(*) FROM #ExpiringLeases), 0)

	UPDATE #AllPropertyInfoEver SET LeaseRenewals60Days = ISNULL((SELECT COUNT(*)
																	FROM #ExpiringLeases
																	WHERE NextLeaseID IS NOT NULL), 0)

	UPDATE #AllPropertyInfoEver SET FutureNoticeToVacate = ISNULL((SELECT COUNT(UnitID)
																	FROM #LeasesAndUnits
																	WHERE OccupiedUnitLeaseGroupID IS NOT NULL
																	  AND OccupiedNTVDate IS NOT NULL), 0)

	SELECT * 
		FROM #AllPropertyInfoEver
		ORDER BY PropertyName

END
GO
