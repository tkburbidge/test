SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Nick Olsen
-- Create date: Nov 17, 2015
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_S2_LeaseAnalysis] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyID uniqueidentifier,
	@startDate date = null, 
	@endDate date = null,	
	@accountingPeriodID uniqueidentifier = null,
	@unitTypeIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #UnitTypeIDs ( UnitTypeID uniqueidentifier )

	IF ((SELECT COUNT(*) FROM @unitTypeIDs) = 0)
	BEGIN
		INSERT INTO #UnitTypeIDs SELECT UnitTypeID FROM UnitType WHERE AccountID = @accountID AND PropertyID = @propertyID
	END 
	ELSE
	BEGIN
		INSERT INTO #UnitTypeIDs SELECT Value from @unitTypeIDs
	END	

	CREATE TABLE #NewAndRenewedLeaseInfo (
		PropertyName nvarchar(100) null,
		PropertyID uniqueidentifier null,
		LeaseID uniqueidentifier null,
		LeaseStatus nvarchar(100),
		Unit nvarchar(50) null,
		UnitID uniqueidentifier null,
		UnitTypeName nvarchar(100),
		UnitTypeID uniqueidentifier null,
		LeaseStartDate date,
		LeaseEndDate date,		
		ApplicationRenewalDate date,
		[Type] nvarchar(100) null,		
		Rent money null,						
		PriorRent money null,		
		RecurringConcessions money null,
		PreviousLeaseID uniqueidentifier null,
		SquareFootage int null)

	INSERT INTO #NewAndRenewedLeaseInfo
		SELECT DISTINCT 
				p.Name as 'PropertyName',
				p.PropertyID AS 'PropertyID', 
				l1.LeaseID AS 'LeaseID', 
				l1.LeaseStatus,
				u.Number as 'Unit', 
				u.UnitID as 'UnitID',	
				ut.Name,
				ut.UnitTypeID,							
				l1.LeaseStartDate AS 'LeaseStartDate', 
				l1.LeaseEndDate AS 'LeaseEndDate',	
					(SELECT MIN(pl.ApplicationDate)
					FROM PersonLease pl
					WHERE l1.LeaseID = pl.LeaseID
					  AND pl.ResidencyStatus <> 'Cancelled'
					  AND pl.ApplicationDate IS NOT NULL) AS 'ApplicationRenewalDate',				
			   CASE 
					WHEN ((SELECT COUNT(prevLease.LeaseID) 
						   FROM Lease prevLease 
						   WHERE prevLease.UnitLeaseGroupID = ulg.UnitLeaseGroupID
								 AND prevLease.LeaseID <> l1.LeaseID 
								 AND prevLease.LeaseStartDate < l1.LeaseStartDate) > 0) THEN 'Renewal'					
					ELSE 'New' END AS 'Type',	
				
			   (SELECT ISNULL(Sum(lli.Amount), 0) 
				FROM LeaseLedgerItem lli
				INNER JOIN LedgerItem li on li.LedgerItemID = lli.LedgerItemID
				INNER JOIN LedgerItemType lit on lit.LedgerItemTypeID = li.LedgerItemTypeID
				WHERE lli.LeaseID = l1.LeaseID 
					  AND lit.IsRent = 1
					  AND lli.StartDate <= l1.LeaseStartDate
					  AND lli.EndDate >= l1.LeaseStartDate) AS 'Rent',
											
				null, 
				null,
				null,
				u.SquareFootage
			FROM Lease l1
				INNER JOIN UnitLeaseGroup ulg ON l1.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID			
				INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON b.PropertyID = p.PropertyID
				INNER JOIN #UnitTypeIDs #utIDs ON #utIDs.UnitTypeID = ut.UnitTypeID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID							
			WHERE p.PropertyID = @propertyID	  				
				AND (((@accountingPeriodID IS NULL) AND (l1.LeaseStartDate >= @startDate) AND (l1.LeaseStartDate <= @endDate))
				  OR ((@accountingPeriodID IS NOT NULL) AND (l1.LeaseStartDate >= pap.StartDate) AND (l1.LeaseStartDate <= pap.EndDate)))
				AND l1.LeaseStatus NOT IN ('Cancelled', 'Denied')
				
				
	UPDATE #NewAndRenewedLeaseInfo SET PreviousLeaseID = (SELECT TOP 1 l.LeaseID
															FROM Lease l 
																INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																INNER JOIN Unit u ON ulg.UnitID = u.UnitID
															WHERE u.UnitID = #NewAndRenewedLeaseInfo.UnitID
															  AND l.LeaseID <> #NewAndRenewedLeaseInfo.LeaseID
															  AND l.LeaseStartDate < #NewAndRenewedLeaseInfo.LeaseStartDate
															  AND l.LeaseStatus IN ('Current', 'Renewed')
															ORDER BY DateCreated DESC)
															
	UPDATE #NewAndRenewedLeaseInfo SET PriorRent = (SELECT ISNULL(SUM(lli.Amount), 0)
														FROM LeaseLedgerItem lli
															INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
															INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID  AND lit.IsRent = 1
															INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
														WHERE lli.LeaseID = #NewAndRenewedLeaseInfo.PreviousLeaseID
														  AND lli.StartDate <= l.LeaseEndDate)

	-- For the non-renewed leases, get the previous resident's rent
	UPDATE #NewAndRenewedLeaseInfo SET PriorRent = (SELECT ISNULL(SUM(lli.Amount), 0)
														FROM LeaseLedgerItem lli
															INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
															INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID  AND lit.IsRent = 1
															INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
															INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
														WHERE lli.StartDate <= l.LeaseEndDate														
														  AND l.LeaseID = (SELECT TOP 1 l2.LeaseID 
																		   FROM Lease l2
																		   INNER JOIN UnitLeaseGroup ulg2 ON ulg2.UnitLeaseGroupID = l2.UnitLeaseGroupID
																		   WHERE ulg2.UnitID = #NewAndRenewedLeaseInfo.UnitID
																		   AND l2.LeaseStatus IN ('Former', 'Evicted', 'Current', 'Under Eviction')
																		   ORDER BY l2.LeaseEndDate DESC))
	WHERE #NewAndRenewedLeaseInfo.[Type] = 'New'
														  
	UPDATE #NewAndRenewedLeaseInfo SET RecurringConcessions = (SELECT ISNULL(SUM(lli.Amount), 0)
																	FROM LeaseLedgerItem lli
																		INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
																		INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID  AND lit.IsCredit = 1 AND lit.IsRecurringMonthlyRentConcession = 1
																		INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
																	WHERE lli.LeaseID = #NewAndRenewedLeaseInfo.LeaseID
																	  AND lli.StartDate <= l.LeaseEndDate)														  
				
	SELECT	#newReLeases.*, MarketRent.Amount AS 'MarketRent'
		FROM #NewAndRenewedLeaseInfo #newReLeases			
			CROSS APPLY GetMarketRentByDate(#newReLeases.UnitID, #newReLeases.ApplicationRenewalDate, 1) AS MarketRent
		ORDER BY #newReLeases.LeaseStartDate
			

			
END
GO
