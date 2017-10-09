SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO








CREATE PROCEDURE [dbo].[RPT_RES_CancellationsAndMoveOuts] 
	-- Add the parameters for the stored procedure here
	@startDate datetime = null,
	@endDate datetime = null,
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null
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
		StartDate date not null)

	DECLARE @propertyID uniqueidentifier, @myStartDate date, @ctr int = 1, @maxCtr int, @unitIDs GuidCollection

	INSERT #Properties SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate)
		FROM @propertyIDs pIDs
			LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			
	SET @maxCtr = (SELECT MAX(Sequence) FROM #Properties)

	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @propertyID = PropertyID, @myStartDate = StartDate FROM #Properties WHERE Sequence = @ctr
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @myStartDate /*@startDate*/
		SET @ctr = @ctr + 1
	END			

	SELECT DISTINCT 
			'Moved Out' AS 'ReportStatus', 
			p.Name AS 'PropertyName', 
			pl.ResidencyStatus AS 'ResidencyStatus',
			l.LeaseID AS 'LeaseID', 
			u.Number as 'Unit',
			pr.PreferredName + ' ' + pr.LastName AS 'Resident',
			DATEDIFF(day, pl.MoveInDate, pl.MoveOutDate) AS 'DaysOccupied',
			CASE
				WHEN pl.MoveOutDate < l.LeaseEndDate THEN 'Y'
				ELSE 'N'
				END AS 'BrokeLease',
			ISNULL(DATEDIFF(day, pl.NoticeGivenDate, pl.MoveOutDate), 0) AS 'DaysNotice',
			pl.MoveOutDate AS 'DateVacated',
			((SELECT COUNT(Late) FROM ULGAPInformation WHERE ObjectID = ulg.UnitLeaseGroupID OR ObjectID = ulg.PreviousUnitLeaseGroupID) +
			ISNULL((SELECT ImportTimesLate FROM UnitLeaseGroup WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID), 0)) AS 'TimesLate',
			(ISNULL((SELECT COUNT(DISTINCT p.PaymentID) 
				FROM Payment p					
					LEFT JOIN PersonNote pn ON p.PaymentID = pn.ObjectID AND pn.InteractionType = 'Waived NSF'
				WHERE p.[Type] = 'NSF' AND pn.PersonNoteID IS NULL AND p.ObjectID = ulg.UnitLeaseGroupID), 0) +
			ISNULL((SELECT ImportNSFCount FROM UnitLeaseGroup WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID), 0)) AS 'TimesNSF',
			--mr.Amount AS 'MarketRent', 
			#ua.MarketRent AS 'MarketRent',			
		   (SELECT SUM(lli.Amount) 
		    FROM LeaseLedgerItem lli
			INNER JOIN LedgerItem li on lli.LedgerItemID = li.LedgerItemID
			INNER JOIN LedgerItemType lit on li.LedgerItemTypeID = lit.LedgerItemTypeID
			WHERE lli.LeaseID = l.LeaseID 
				  AND lit.IsRent = 1) AS 'ActualRent',
			pl.ReasonForLeaving AS 'MoveOutReason'
		FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON p.PropertyID = b.PropertyID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID		
			INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
			INNER JOIN Person pr ON pr.PersonID = pl.PersonID	
			LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID		
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  --AND pl.MoveOutDate >= @startDate
		  --AND pl.MoveOutDate <= @endDate
		  AND (((@accountingPeriodID IS NULL) AND (pl.MoveOutDate >= @startDate) AND (pl.MoveOutDate <= @endDate))
		    OR ((@accountingPeriodID IS NOT NULL) AND (pl.MoveOutDate >= pap.StartDate) AND (pl.MoveOutDate <= pap.EndDate)))
		  AND pl.ResidencyStatus IN ('Former', 'Evicted')
		  AND l.LeaseStatus IN ('Former', 'Evicted')		
		  
		UNION
		
	SELECT DISTINCT 
			l.LeaseStatus AS 'ReportStatus', 
			p.Name AS 'PropertyName', 
			pl.ResidencyStatus AS 'ResidencyStatus',
			l.LeaseID AS 'LeaseID', 
			u.Number as 'Unit',
			pr.PreferredName + ' ' + pr.LastName AS 'Resident',
			DATEDIFF(day, pl.MoveInDate, pl.MoveOutDate) AS 'DaysOccupied',
			CASE
				WHEN pl.MoveOutDate <= l.LeaseEndDate THEN 'Y'
				ELSE 'N'
				END AS 'BrokeLease',
			ISNULL(DATEDIFF(day, pl.NoticeGivenDate, pl.MoveOutDate), 0) AS 'DaysNotice',
			pl.MoveOutDate AS 'DateVacated',
			((SELECT COUNT(Late) FROM ULGAPInformation WHERE ObjectID = ulg.UnitLeaseGroupID OR ObjectID = ulg.PreviousUnitLeaseGroupID) +
			ISNULL((SELECT ImportTimesLate FROM UnitLeaseGroup WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID), 0)) AS 'TimesLate',
			(ISNULL((SELECT COUNT(DISTINCT p.PaymentID) 
				FROM Payment p					
					LEFT JOIN PersonNote pn ON p.PaymentID = pn.ObjectID AND pn.InteractionType = 'Waived NSF'
				WHERE p.[Type] = 'NSF' AND pn.PersonNoteID IS NULL AND p.ObjectID = ulg.UnitLeaseGroupID), 0) +
			ISNULL((SELECT ImportNSFCount FROM UnitLeaseGroup WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID), 0)) AS 'TimesNSF',
			#ua.MarketRent AS 'MarketRent',		
		   (SELECT SUM(lli.Amount) 
		    FROM LeaseLedgerItem lli
			INNER JOIN LedgerItem li on lli.LedgerItemID = li.LedgerItemID
			INNER JOIN LedgerItemType lit on li.LedgerItemTypeID = lit.LedgerItemTypeID
			WHERE lli.LeaseID = l.LeaseID 
				  AND lit.IsRent = 1) AS 'ActualRent',
			(CASE WHEN ulg.PreviousUnitLeaseGroupID IS NOT NULL THEN '(PT) ' 
									     WHEN l.LeaseID <> (SELECT TOP 1 l2.LeaseID
															FROM Lease l2
															WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
															ORDER BY l2.LeaseStartDate)  THEN '(R) '
									ELSE '' END) + ISNULL(pl.ReasonForLeaving, '')
			AS 'MoveOutReason'
		FROM Lease l
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON p.PropertyID = b.PropertyID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID			
			INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
			INNER JOIN Person pr ON pr.PersonID = pl.PersonID		
			LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  --AND pl.MoveOutDate >= @startDate
		  --AND pl.MoveOutDate <= @endDate
		  AND (((@accountingPeriodID IS NULL) AND (pl.MoveOutDate >= @startDate) AND (pl.MoveOutDate <= @endDate))
		    OR ((@accountingPeriodID IS NOT NULL) AND (pl.MoveOutDate >= pap.StartDate) AND (pl.MoveOutDate <= pap.EndDate)))		  
		  AND pl.ResidencyStatus IN ('Cancelled', 'Denied')
		  AND l.LeaseStatus IN ('Cancelled',  'Denied')				  	
END













GO
