SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[AssessMonthToMonthFees]
	@startDate date,
	@endDate date
AS
BEGIN

CREATE TABLE #Leases (
	AccountID bigint,
	PropertyID uniqueidentifier,
	LeaseID uniqueidentifier,
	LeaseStartDate date,
	LeaseEndDate date,
	MonthToMonthStartDate date,
	MarketRent money,
	ActualRent money,
	RentLedgerItemID uniqueidentifier,
	RentLedgeritemTypeName nvarchar(100),
	MTMRentChargesOption nvarchar(20),
	MTMExtendNonRentCharges bit,
	MTMExtendCredits bit,
	MTMFeeChargeType nvarchar(100),
	MonthToMonthFee money,
	MonthToMonthFeeType nvarchar(100),
	MTMStopAtSignedRenewal bit,
	SignedRenewalLease bit,
	MonthToMonthFeeLedgerItemID uniqueidentifier,
	MonthToMonthFeeLedgerIetmTypeName nvarchar(100),
	MonthToMonthRounding int
)

INSERT INTO #Leases
	SELECT DISTINCT l.AccountID, p.PropertyID, l.LeaseID, l.LeaseStartDate, l.LeaseEndDate, DATEADD(Month, 1,  @startDate), mr.Amount,
	0, li.LedgerItemID, lit.Name, p.MTMRentChargesOption, p.MTMExtendNonRentCharges, p.MTMExtendCredits, p.MTMFeeChargeType, p.MonthToMonthFee, p.MonthToMonthFeeType,
	p.MTMStopAtSignedRenewal,
	(CASE WHEN prl.LeaseID IS NULL THEN 0
		  ELSE 1
	 END) AS SignedRenewalLease,
	 mtmli.LedgerItemID, mtmlit.Name, 
	 (CASE WHEN p.MTMDontRound = 0 THEN 0
		ELSE 2 
		END) AS MonthToMonthRounding
	FROM Lease l
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u ON u.UnitID = ulg.UnitID
		INNER JOIN Building b ON b.buildingID = u.BuildingID
		INNER JOIN Property p ON p.PropertyID = b.PropertyID
		CROSS APPLY GetMarketRentByDate(u.UnitID, l.LeaseEndDate, 1) AS mr
		LEFT JOIN Lease prl ON prl.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND prl.LeaseStatus = 'Pending Renewal' AND prl.LeaseEndDate > l.LeaseEndDate AND EXISTS (SELECT * FROM PersonLease pl WHERE pl.LeaseID = prl.LeaseID AND pl.LeaseSignedDate IS NOT NULL)
		INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
		INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = ut.RentLedgerItemTypeID
		INNER JOIN LedgerItem li ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND li.LedgerItemPoolID IS NULL
		INNER JOIN Settings s on s.AccountID = l.AccountID
		INNER JOIN LedgerItemType mtmlit on mtmlit.LedgerItemTypeID = s.MonthToMonthFeeLedgerItemTypeID
		INNER JOIN LedgerItem mtmli ON mtmli.LedgerItemTypeID = mtmlit.LedgerItemTypeID AND mtmli.LedgerItemPoolID IS NULL
	WHERE l.LeaseStatus IN ('Current', 'Under Eviction')
		AND l.LeaseEndDate >= @startDate
		AND l.LeaseEndDate <= @endDate
		AND p.AutoAdjustMonthToMonthLeaseCharges = 1

UPDATE #Leases SET ActualRent = ISNULL((SELECT SUM(lli.Amount)
										FROM LeaseLedgerItem lli
											INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
											INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
										 WHERE lli.LeaseID = #Leases.LeaseID
											AND lit.IsRent = 1
											AND lli.StartDate <= @startDate
											AND lli.EndDate >= @startDate), 0)



-- Extend Rent or charge market but market is less than actual
UPDATE lli SET lli.EndDate = '2099-12-31' 			
	FROM LeaseLedgerItem lli		
		INNER JOIN #Leases #l ON #l.LeaseID = lli.LeaseID
		INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
		INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
	WHERE (#l.MTMRentChargesOption = 'Extend' OR (#l.MTMRentChargesOption = 'Market' AND #l.ActualRent >= #l.MarketRent))
		AND lit.IsRent = 1
		AND lli.StartDate <= @startDate
		AND lli.EndDate >= @startDate
	

-- End rent and charge market rent
UPDATE lli SET lli.EndDate = @endDate
	FROM LeaseLedgerItem lli 
		INNER JOIN #Leases #l ON #l.LeaseID = lli.LeaseID
		INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
		INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
	WHERE #l.MTMRentChargesOption = 'Market' AND #l.ActualRent < #l.MarketRent
		AND lit.IsRent = 1
		AND lli.StartDate <= @startDate
		AND lli.EndDate >= @startDate

INSERT INTO LeaseLedgerItem
	SELECT newid(), #l.LeaseID, #l.RentLedgerItemID, #l.AccountID, #l.RentLedgerItemTypeName, #l.MarketRent, #l.MonthToMonthStartDate, '2099-12-31', getdate(), null, null, null, null, null, 0, 0, null, 0
	FROM #Leases #l
	WHERE #l.MTMRentChargesOption = 'Market' AND #l.ActualRent < #l.MarketRent
	

---- Extend non-rent charges
UPDATE lli SET lli.EndDate = '2099-12-31' 			
	FROM LeaseLedgerItem lli		
		INNER JOIN #Leases #l ON #l.LeaseID = lli.LeaseID
		INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
		INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
	WHERE #l.MTMExtendNonRentCharges = 1
		AND lit.IsRent = 0
		AND lit.IsCharge = 1
		AND lli.StartDate <= @startDate
		AND lli.EndDate >= @startDate


-- Extend credits
UPDATE lli SET lli.EndDate = '2099-12-31' 			
	FROM LeaseLedgerItem lli		
		INNER JOIN #Leases #l ON #l.LeaseID = lli.LeaseID
		INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
		INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
	WHERE #l.MTMExtendCredits = 1
		AND lit.IsRent = 0
		AND lit.IsCredit = 1
		AND lli.StartDate <= @startDate
		AND lli.EndDate >= @startDate


---- Add month to month fee (flat, percet of actual, percent of market)

INSERT INTO LeaseLedgerItem
	SELECT newid(), #l.LeaseID, #l.MonthToMonthFeeLedgerItemID, #l.AccountID, #l.MonthToMonthFeeLedgerIetmTypeName, #l.MonthToMonthFee, #l.MonthToMonthStartDate, '2099-12-31', getdate(), null, null, null, null, null, 0, 0, null, 0
	FROM #Leases #l
	WHERE #l.MTMFeeChargeType <> 'None'
		AND #l.MonthToMonthFeeType = 'Flat fee'
		AND (#l.SignedRenewalLease = 0 OR #l.MTMStopAtSignedRenewal = 0)


INSERT INTO LeaseLedgerItem																																		
	SELECT newid(), #l.LeaseID, #l.MonthToMonthFeeLedgerItemID, #l.AccountID, #l.MonthToMonthFeeLedgerIetmTypeName, ROUND((#l.MonthToMonthFee / 100.0) * #l.ActualRent, #l.MonthToMonthRounding), #l.MonthToMonthStartDate, '2099-12-31', getdate(), null, null, null, null, null, 0, 0, null, 0
	FROM #Leases #l
	WHERE #l.MTMFeeChargeType <> 'None'
		AND #l.MonthToMonthFeeType = 'Percent of actual rent'
		AND (#l.SignedRenewalLease = 0 OR #l.MTMStopAtSignedRenewal = 0)

INSERT INTO LeaseLedgerItem
	SELECT newid(), #l.LeaseID, #l.MonthToMonthFeeLedgerItemID, #l.AccountID, #l.MonthToMonthFeeLedgerIetmTypeName, ROUND((#l.MonthToMonthFee / 100.0) * #l.MarketRent, #l.MonthToMonthRounding), #l.MonthToMonthStartDate, '2099-12-31', getdate(), null, null, null, null, null, 0, 0, null, 0
	FROM #Leases #l
	WHERE #l.MTMFeeChargeType <> 'None'
		AND #l.MonthToMonthFeeType = 'Percent of market rent'
		AND (#l.SignedRenewalLease = 0 OR #l.MTMStopAtSignedRenewal = 0)
	

DROP TABLE #Leases
END
GO
