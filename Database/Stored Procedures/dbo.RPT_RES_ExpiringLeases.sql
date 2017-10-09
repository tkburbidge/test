SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_RES_ExpiringLeases] 
	-- Add the parameters for the stored procedure here
	@startDate datetime = null,		-- @startDate
	@endDate datetime = null,		-- @endDate
	@propertyIDs GuidCollection READONLY,			-- @propertyIDs
	@leaseStatuses StringCollection READONLY,
	@accountingPeriodID uniqueidentifier = null,
	@marketRentValueBasis nvarchar(50) = null		
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		UnitStatus nvarchar(200) not null,
		UnitStatusLedgerItemTypeID uniqueidentifier not null,
		RentLedgerItemTypeID uniqueidentifier not null,
		MarketRent decimal null,
		Amenities nvarchar(MAX) null)
		
	CREATE TABLE #Properties (
		Sequence int identity not null,
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null,
		MarketRentDate date null)
		
	DECLARE @propertyID uniqueidentifier, @ctr int = 1, @maxCtr int, @recurringChargesStartDate date, @unitIDs GuidCollection
	

	INSERT #Properties 
		SELECT pIDs.Value, 
			COALESCE(pap.StartDate, @startDate), 
			COALESCE(pap.EndDate, @endDate),
			CASE WHEN (@marketRentValueBasis = 'StartDate') THEN COALESCE(pap.StartDate, @startDate)
				 WHEN (@marketRentValueBasis = 'CurrentDate') THEN dbo.GetTimeZoneTime(pap.PropertyID)
				 --default to EndDate
				 ELSE COALESCE(pap.EndDate, @endDate) END AS 'MarketRentDate'
		FROM @propertyIDs pIDs
			LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
	
	SET @maxCtr = (SELECT MAX(Sequence) FROM #Properties)
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @propertyID = PropertyID, @recurringChargesStartDate = MarketRentDate FROM #Properties WHERE Sequence = @ctr
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
		--INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @startDate, 0
		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @recurringChargesStartDate, 0
		SET @ctr = @ctr + 1
	END	
	
	SELECT DISTINCT p.Name as 'PropertyName', u.Number as 'Unit', l.LeaseID AS 'LeaseID', l.LeaseStatus as 'LeaseStatus', 
					STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						 FROM Person 
							 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
							 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
							 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
						 WHERE PersonLease.LeaseID = l.LeaseID
							   AND PersonType.[Type] = 'Resident'				   
							   AND PersonLease.MainContact = 1				   
						 FOR XML PATH ('')), 1, 2, '') AS 'Residents',
			ut.Name as 'UnitType', 
		    (SELECT MIN(plmi.MoveInDate) FROM PersonLease plmi WHERE plmi.LeaseID = l.LeaseID AND plmi.ResidencyStatus NOT IN ('Cancelled')) as 'MoveInDate', 
			l.LeaseEndDate as 'LeaseExpires',
			CASE WHEN (pln1.PersonLeaseID IS NULL) 
				THEN pln.NoticeGivenDate
				ELSE null END AS 'NoticeDate',
			CASE WHEN (plmo1.PersonLeaseID IS NULL) 
				THEN plmo.MoveOutDate
				ELSE null END AS 'MoveOutDate',
			--lli.Amount as 'CurrentRent', 
			(SELECT SUM(lli.Amount) 
			 FROM LeaseLedgerItem lli
			 INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
			 INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
			 WHERE lli.LeaseID = l.LeaseID
				AND lit.IsRent = 1 
				-- Autobill falls within the day of the month the lease expires
				AND lli.StartDate <= DATEADD(DAY, -(DATEPART(DAY, l.LeaseEndDate) - 1), l.LeaseEndDate)
				AND lli.EndDate >= DATEADD(DAY, -(DATEPART(DAY, l.LeaseEndDate) - 1), l.LeaseEndDate)) AS 'CurrentRent',			 		
			--ut.MarketRent as 'MarketRent'
			#ua.MarketRent AS 'MarketRent',
			(SELECT TOP 1 LeaseID
				FROM Lease
				WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
				  AND LeaseStatus IN ('Pending Renewal')) AS 'RenewalLeaseID',
			(SELECT TOP 1 LeaseStartDate
				FROM Lease
				WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
				  AND LeaseStatus IN ('Pending Renewal')) AS 'RenewalStartDate',
			CASE
				WHEN ((SELECT TOP 1 rl.LeaseID
						FROM Lease rl
							INNER JOIN PersonLease prl ON rl.LeaseID = prl.LeaseID AND prl.LeaseSignedDate IS NOT NULL
						WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
						  AND LeaseStatus IN ('Pending Renewal')) IS NOT NULL) THEN CAST(1 AS Bit)
				ELSE CAST(0 AS Bit) END AS 'IsRenewalLeaseSigned',
			CASE WHEN (la.PersonID IS NULL)
					THEN '' 
					ELSE la.PreferredName + ' ' + la.LastName END AS 'LeasingAgentName'
		FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN #Properties #pad ON p.PropertyID = #pad.PropertyID
			LEFT JOIN PersonLease pln ON pln.LeaseID = l.LeaseID AND pln.NoticeGivenDate IS NOT NULL AND (pln.NoticeGivenDate = (SELECT MAX(NoticeGivenDate)
																																	FROM PersonLease
																																	WHERE LeaseID = l.LeaseID
																																	  AND NoticeGivenDate IS NOT NULL))
			LEFT JOIN PersonLease pln1 ON pln1.LeaseID = l.LeaseID AND pln1.NoticeGivenDate IS NULL
			LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.MoveOutDate IS NOT NULL AND (plmo.MoveOutDate = (SELECT MAX(MoveOutDate)
																																FROM PersonLease
																																WHERE LeaseID = l.LeaseID
																																  AND MoveOutDate IS NOT NULL))
			LEFT JOIN PersonLease plmo1 ON plmo1.LeaseID = l.LeaseID AND plmo1.MoveOutDate IS NULL
			LEFT JOIN Person la on l.LeasingAgentPersonID = la.PersonID
		WHERE --p.PropertyID in (SELECT Value FROM @propertyIDs)
		  --AND l.LeaseEndDate >= @startDate
		  --AND l.LeaseEndDate <= @endDate
		  l.LeaseEndDate >= #pad.StartDate
		  AND l.LeaseEndDate <= #pad.EndDate
		  AND l.LeaseStatus IN (SELECT Value FROM @leaseStatuses)
		 -- AND ((pln.PersonLeaseID IS NULL)
			--OR (pln.PersonLeaseID = (SELECT TOP 1 PersonLeaseID 
			--							FROM PersonLease pl1 
			--							WHERE pl1.LeaseID = l.LeaseID AND pl1.NoticeGivenDate IS NOT NULL 
			--							ORDER BY pl1.NoticeGivenDate DESC)))
END
GO
