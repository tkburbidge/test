SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 1, 2012
-- Description:	Generates the data for the New and Renewed Leases Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_NewAndRenewedLeases] 
	-- Add the parameters for the stored procedure here
	@startDate date = null, 
	@endDate date = null,
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #NewAndRenewedLeaseInfo (
		PropertyName nvarchar(100) null,
		LeaseID uniqueidentifier null,
		Unit nvarchar(50) null,
		UnitID uniqueidentifier null,
		Residents nvarchar(500) null,
		ApplicationRenewalDate date null,
		LeaseSignedDate date null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		Rent money null,
		Renewed bit null,
		[Type] nvarchar(100) null,
		PaddedUnit nvarchar(100) null,
		PriorRent money null,		
		RecurringConcessions money null,
		PreviousLeaseID uniqueidentifier null)

	INSERT INTO #NewAndRenewedLeaseInfo
		SELECT DISTINCT 
				p.Name as 'PropertyName', 
				l1.LeaseID AS 'LeaseID', 
				u.Number as 'Unit', 
				u.UnitID as 'UnitID',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l1.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 FOR XML PATH ('')), 1, 2, '') AS 'Residents',
				(SELECT MIN(pl.ApplicationDate)
					FROM PersonLease pl
					WHERE l1.LeaseID = pl.LeaseID
					  AND pl.ResidencyStatus <> 'Cancelled'
					  AND pl.ApplicationDate IS NOT NULL) AS 'ApplicationRenewalDate',
				(SELECT MIN(pl.LeaseSignedDate)
					FROM PersonLease pl
					WHERE l1.LeaseID = pl.LeaseID
					  AND pl.ResidencyStatus <> 'Cancelled'
					  AND pl.LeaseSignedDate IS NOT NULL) AS 'LeaseSignedDate',						  
				l1.LeaseStartDate AS 'LeaseStartDate', 
				l1.LeaseEndDate AS 'LeaseEndDate',					
			   (SELECT ISNULL(Sum(lli.Amount), 0) 
				FROM LeaseLedgerItem lli
				INNER JOIN LedgerItem li on li.LedgerItemID = lli.LedgerItemID
				INNER JOIN LedgerItemType lit on lit.LedgerItemTypeID = li.LedgerItemTypeID
				WHERE lli.LeaseID = l1.LeaseID 
					  AND lit.IsRent = 1) AS 'Rent',
				CASE 
					WHEN ((SELECT COUNT(prevLease.LeaseID) 
						   FROM Lease prevLease 
						   WHERE prevLease.UnitLeaseGroupID = ulg.UnitLeaseGroupID
								 AND prevLease.LeaseID <> l1.LeaseID 
								 AND prevLease.LeaseStartDate < l1.LeaseStartDate) > 0) THEN CAST(1 AS Bit)						
					ELSE CAST(0 AS Bit) END AS 'Renewed',
				'Started' AS [Type],
				u.PaddedNumber AS 'PaddedUnit',
				null, 
				null,
				null
			FROM Lease l1
				INNER JOIN UnitLeaseGroup ulg ON l1.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID			
				INNER JOIN Building b ON u.BuildingID = b.BuildingID

				INNER JOIN Property p ON b.PropertyID = p.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID			
			WHERE p.PropertyID in (SELECT Value FROM @propertyIDs)		  
				--AND l1.LeaseStartDate >= @startDate
				--AND l1.LeaseStartDate <= @endDate
				AND (((@accountingPeriodID IS NULL) AND (l1.LeaseStartDate >= @startDate) AND (l1.LeaseStartDate <= @endDate))
				  OR ((@accountingPeriodID IS NOT NULL) AND (l1.LeaseStartDate >= pap.StartDate) AND (l1.LeaseStartDate <= pap.EndDate)))
				AND l1.LeaseStatus NOT IN ('Cancelled', 'Pending', 'Pending Renewal', 'Pending Transfer', 'Denied')
		UNION ALL
		SELECT DISTINCT 
				p.Name as 'PropertyName', 
				l1.LeaseID AS 'LeaseID', 
				u.Number as 'Unit', 
				u.UnitID as 'UnitID',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l1.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 FOR XML PATH ('')), 1, 2, '') AS 'Residents',
				(SELECT MIN(pl.ApplicationDate)
					FROM PersonLease pl
					WHERE l1.LeaseID = pl.LeaseID
					  AND pl.ResidencyStatus <> 'Cancelled'
					  AND pl.ApplicationDate IS NOT NULL) AS 'ApplicationRenewalDate',
				(SELECT MIN(pl.LeaseSignedDate)
					FROM PersonLease pl
					WHERE l1.LeaseID = pl.LeaseID
					  AND pl.ResidencyStatus <> 'Cancelled'
					  AND pl.LeaseSignedDate IS NOT NULL) AS 'LeaseSignedDate',						  
				l1.LeaseStartDate AS 'LeaseStartDate', 
				l1.LeaseEndDate AS 'LeaseEndDate',					
			   (SELECT ISNULL(Sum(lli.Amount), 0) 
				FROM LeaseLedgerItem lli
				INNER JOIN LedgerItem li on li.LedgerItemID = lli.LedgerItemID
				INNER JOIN LedgerItemType lit on lit.LedgerItemTypeID = li.LedgerItemTypeID
				WHERE lli.LeaseID = l1.LeaseID 
					  AND lit.IsRent = 1) AS 'Rent',
				CASE 
					WHEN ((SELECT COUNT(prevLease.LeaseID) 
						   FROM Lease prevLease 
						   WHERE prevLease.UnitLeaseGroupID = ulg.UnitLeaseGroupID
								 AND prevLease.LeaseID <> l1.LeaseID 
								 AND prevLease.LeaseStartDate < l1.LeaseStartDate) > 0) THEN CAST(1 AS Bit)						
					ELSE CAST(0 AS Bit) END AS 'Renewed',
				'Signed' AS [Type],		
				u.PaddedNumber AS 'PaddedUnit',
				null,
				null,				
				null
			FROM Lease l1
				INNER JOIN UnitLeaseGroup ulg ON l1.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID			
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON b.PropertyID = p.PropertyID	
				LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID		
			WHERE p.PropertyID in (SELECT Value FROM @propertyIDs)		  
				--AND (SELECT MIN(pl.LeaseSignedDate) FROM PersonLease pl WHERE l1.LeaseID = pl.LeaseID AND pl.LeaseSignedDate IS NOT NULL AND pl.ResidencyStatus <> 'Cancelled') >= @startDate
				--AND (SELECT MIN(pl.LeaseSignedDate) FROM PersonLease pl WHERE l1.LeaseID = pl.LeaseID AND pl.LeaseSignedDate IS NOT NULL AND pl.ResidencyStatus <> 'Cancelled') <= @endDate
				AND (((@accountingPeriodID IS NULL)
					AND ((SELECT MIN(pl.LeaseSignedDate) FROM PersonLease pl WHERE l1.LeaseID = pl.LeaseID AND pl.LeaseSignedDate IS NOT NULL AND pl.ResidencyStatus <> 'Cancelled') >= @startDate)
					AND ((SELECT MIN(pl.LeaseSignedDate) FROM PersonLease pl WHERE l1.LeaseID = pl.LeaseID AND pl.LeaseSignedDate IS NOT NULL AND pl.ResidencyStatus <> 'Cancelled') <= @endDate))
				OR (((@accountingPeriodID IS NOT NULL)
					AND ((SELECT MIN(pl.LeaseSignedDate) FROM PersonLease pl WHERE l1.LeaseID = pl.LeaseID AND pl.LeaseSignedDate IS NOT NULL AND pl.ResidencyStatus <> 'Cancelled') >= pap.StartDate)
					AND ((SELECT MIN(pl.LeaseSignedDate) FROM PersonLease pl WHERE l1.LeaseID = pl.LeaseID AND pl.LeaseSignedDate IS NOT NULL AND pl.ResidencyStatus <> 'Cancelled') <= pap.EndDate))))								
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
																		   AND l2.LeaseStatus IN ('Former', 'Evicted')
																		   ORDER BY l2.LeaseEndDate DESC))
	WHERE #NewAndRenewedLeaseInfo.Renewed = 0
														  
	UPDATE #NewAndRenewedLeaseInfo SET RecurringConcessions = (SELECT ISNULL(SUM(lli.Amount), 0)
																	FROM LeaseLedgerItem lli
																		INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
																		INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID  AND lit.IsCredit = 1 AND lit.IsRecurringMonthlyRentConcession = 1
																		INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
																	WHERE lli.LeaseID = #NewAndRenewedLeaseInfo.LeaseID
																	  AND lli.StartDate <= l.LeaseEndDate)														  
				
	SELECT	#newReLeases.PropertyName,
			#newReLeases.LeaseID,
			#newReLeases.Unit,
			#newReLeases.Residents,
			#newReLeases.ApplicationRenewalDate,
			#newReLeases.LeaseSignedDate,
			#newReLeases.LeaseStartDate,
			#newReLeases.LeaseEndDate,
			#newReLeases.Rent,
			#newReLeases.Renewed,
			#newReLeases.[Type] AS 'Type',
			#newReLeases.PaddedUnit,
			MarketRent.Amount AS 'MarketRent',
			#newReLeases.RecurringConcessions,
			#newReLeases.PriorRent
		FROM #NewAndRenewedLeaseInfo #newReLeases			
			CROSS APPLY GetMarketRentByDate(#newReLeases.UnitID, #newReLeases.ApplicationRenewalDate, 1) AS MarketRent
		ORDER BY #newReLeases.LeaseStartDate
			

			
END




GO
