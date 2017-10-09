SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 22, 2017
-- Description:	Market Analysis of new and renewed leases
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_WSTCH_MarketLossAnalysis]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@startAccountingPeriodID uniqueidentifier = null,
	@endAccountingPeriodID uniqueidentifier = null,
	@startDate date = null,
	@endDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #MarketLossAnalysis (
		PropertyID uniqueidentifier not null,
		MonthPart int null,
		UnitID uniqueidentifier null,
		UnitNumber nvarchar(50) null,
		UnitType nvarchar(50) null,
		MoveInDate date null,
		RenewalDate date null,
		PreviousMoveOutDate date null,
		ApplicationDate date null,
		RentAtApplicationDate money null,
		PreviousLeaseRent money null,
		CurrentLeaseRent money null,
		CurrentMarketRent money null,
		LeaseID uniqueidentifier null,
		LeaseStartDate date null,
		PreviousLeaseID uniqueidentifier null,
		ULGID uniqueidentifier null
		)

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier not null,
		MonthPart int null,
		StartDate date null,
		EndDate date null
		)



	INSERT #PropertiesAndDates
		SELECT	pIDs.Value, 
				DATEPART(MONTH, pap.EndDate),
				CASE
					WHEN ((@startAccountingPeriodID IS NULL) AND (pap.StartDate > @startDate)) THEN pap.StartDate
					WHEN (@startAccountingPeriodID IS NULL) THEN @startDate
					ELSE pap.StartDate
					END,
				CASE
					WHEN ((@endAccountingPeriodID IS NULL) AND (pap.EndDate > @endDate)) THEN @endDate
					WHEN (@endAccountingPeriodID IS NULL) THEN pap.EndDate
					ELSE pap.EndDate
					END
			FROM @propertyIDs pIDs
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID
				LEFT JOIN PropertyAccountingPeriod papStart ON pIDs.Value = papStart.PropertyID AND papStart.AccountingPeriodID = @startAccountingPeriodID
				LEFT JOIN PropertyAccountingPeriod papEnd ON pIDs.Value = papEnd.PropertyID AND papEnd.AccountingPeriodID = @endAccountingPeriodID
			WHERE ((@startAccountingPeriodID IS NOT NULL) OR ((@startDate <= pap.EndDate) AND ((@endDate >= pap.EndDate) OR ((@endDate >= pap.StartDate) AND (@endDate <= pap.EndDate)))))
			  AND (((@startDate IS NOT NULL) OR ((pap.StartDate >= papStart.StartDate) AND (pap.EndDate <= papEnd.EndDate))))


--select * from #PropertiesAndDates

	INSERT #MarketLossAnalysis
		SELECT	ut.PropertyID,
				#pad.MonthPart,
				ulg.UnitID,
				u.Number,
				ut.Name,
				pl.MoveInDate,
				null AS 'RenewalDate',
				null AS 'PreviousMoveOutDate',
				pl.ApplicationDate,
				null AS 'RentAtApplicationDate',
				null AS 'PreviousLeaseRent',
				null AS 'CurrentLeaseRent',
				null AS 'CurrentMarketRent',
				l.LeaseID,
				l.LeaseStartDate,
				null AS 'PreviousLeaseID',
				ulg.UnitLeaseGroupID
			FROM Lease l
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID 
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
				LEFT JOIN PersonLease plPrior ON l.LeaseID = pl.LeaseID AND pl.MoveInDate < #pad.StartDate
			WHERE pl.MoveInDate >= #pad.StartDate 
			  AND pl.MoveInDate <= #pad.EndDate
			  AND l.LeaseStatus NOT IN ('Cancelled')
			  AND plPrior.PersonLeaseID IS NULL
			  AND pl.PersonLeaseID = (SELECT TOP 1 PersonLeaseID
										  FROM PersonLease
										  WHERE LeaseID = l.LeaseID
											AND MoveInDate IS NOT NULL
										  ORDER BY MoveInDate, OrderBy)

	INSERT #MarketLossAnalysis
		SELECT	ut.PropertyID,
				#pad.MonthPart,
				ulg.UnitID,
				u.Number,
				ut.Name,
				pl.MoveInDate,
				l.LeaseStartDate AS 'RenewalDate',
				null AS 'PreviousMoveOutDate',
				null AS 'ApplicationDate',
				null AS 'RentAtApplicationDate',
				null AS 'PreviousLeaseRent',
				null AS 'CurrentLeaseRent',
				null AS 'CurrentMarketRent',
				l.LeaseID,
				l.LeaseStartDate,
				null AS 'PreviousLeaseID',
				ulg.UnitLeaseGroupID
			FROM Lease l
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID 
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #PropertiesAndDates #pad ON ut.PropertyID = #pad.PropertyID
				INNER JOIN Lease lPrior ON l.UnitLeaseGroupID = lPrior.UnitLeaseGroupID AND l.LeaseStartDate > lPrior.LeaseStartDate 
			WHERE l.LeaseStartDate >= #pad.StartDate
			  AND l.LeaseStartDate <= #pad.EndDate
			  --AND pnRenewal.[Date] >= #pad.StartDate 
			  --AND pnRenewal.[Date] <= #pad.EndDate
			  AND l.LeaseStatus NOT IN ('Cancelled')
			  AND lPrior.LeaseID = (SELECT TOP 1 LeaseID
										FROM Lease
										WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
										  AND LeaseStatus IN ('Renewed')
										ORDER BY LeaseStartDate DESC)

	UPDATE #MarketLossAnalysis SET PreviousLeaseID = (SELECT TOP 1 l.LeaseID
														  FROM Lease l
															  INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
														  WHERE ulg.UnitID = #MarketLossAnalysis.UnitID
														    AND ulg.UnitLeaseGroupID <> #MarketLossAnalysis.ULGID
														  ORDER BY l.LeaseEndDate DESC)

	UPDATE #MarketLossAnalysis SET PreviousMoveOutDate = (SELECT TOP 1 pl.MoveOutDate	
															  FROM PersonLease pl
															  WHERE pl.LeaseID = #MarketLossAnalysis.PreviousLeaseID
															  ORDER BY pl.MoveOutDate DESC)

	UPDATE #mla SET RentAtApplicationDate = [Marketrent].Amount
		FROM #MarketLossAnalysis #mla
			CROSS APPLY dbo.GetMarketRentByDate(#mla.UnitID, #mla.ApplicationDate, 1) [MarketRent]
		WHERE #mla.ApplicationDate IS NOT NULL

	UPDATE #mla SET RentAtApplicationDate = [Marketrent].Amount
		FROM #MarketLossAnalysis #mla
			CROSS APPLY dbo.GetMarketRentByDate(#mla.UnitID, #mla.RenewalDate, 1) [MarketRent]
		WHERE #mla.ApplicationDate IS NULL

	UPDATE #mla SET CurrentMarketRent = [MarketRent].Amount
		FROM #MarketLossAnalysis #mla
			INNER JOIN #PropertiesAndDates #pad ON #mla.PropertyID = #pad.PropertyID
			CROSS APPLY dbo.GetMarketRentByDate(#mla.UnitID, #pad.EndDate, 1) [MarketRent]
		WHERE ((#mla.ApplicationDate IS NOT NULL) AND ((#mla.ApplicationDate >= #pad.StartDate) AND (#mla.ApplicationDate <= #pad.EndDate)))
		   OR ((#mla.RenewalDate IS NOT NULL) AND ((#mla.RenewalDate >= #pad.StartDate) AND (#mla.ApplicationDate <= #pad.EndDate)))

	UPDATE #MarketLossAnalysis SET CurrentLeaseRent = (SELECT SUM(lli.Amount)
														   FROM LeaseLedgerItem lli
															   INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
															   INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
														   WHERE lli.LeaseID = #MarketLossAnalysis.LeaseID
														     AND lit.IsRent = 1)

	UPDATE #MarketLossAnalysis SET PreviousLeaseRent = (SELECT SUM(lli.Amount)
														   FROM LeaseLedgerItem lli
															   INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
															   INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
														   WHERE lli.LeaseID = #MarketLossAnalysis.PreviousLeaseID
														     AND lit.IsRent = 1)



	SELECT	p.Name AS 'PropertyName',
			DATENAME(MONTH, #mla.MoveInDate) AS 'MonthName',
			#mla.UnitNumber,
			#mla.UnitType,
			#mla.MoveInDate,
			#mla.PreviousMoveOutDate,
			#mla.RenewalDate,
			#mla.ApplicationDate,
			#mla.RentAtApplicationDate,
			#mla.PreviousLeaseRent,
			#mla.CurrentLeaseRent,
			#mla.CurrentMarketRent			
		FROM #MarketLossAnalysis #mla
			INNER JOIN Property p ON #mla.PropertyID = p.PropertyID
		ORDER BY MoveInDate, UnitID

END
GO
