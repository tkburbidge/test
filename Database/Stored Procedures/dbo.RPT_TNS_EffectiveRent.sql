SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 6, 2015
-- Description:	Gets the Effective Rent
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_EffectiveRent] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #EffectiveRent (
		PropertyID uniqueidentifier not null,
		UnitLeaseGroupID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		PropertyName nvarchar(100) null,
		UnitTypeName nvarchar(50) null,
		Unit nvarchar(50) null,
		SquareFeet int null,
		PaddedUnit nvarchar(50) null,
		LeaseID uniqueidentifier null,
		Residents nvarchar(500) null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		MarketRent money null,    -- As of Lease Start Date
		Rent money null,
		MoveInDate date null,
		MoveOutDate date null)

	CREATE TABLE #MyProperties (
		PropertyID uniqueidentifier null)
		
	CREATE TABLE #EROccupants (
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null				
	)		
	
	CREATE TABLE #Concessions (
		LeaseID uniqueidentifier not null,
		ConcessionName nvarchar(50) null,
		ConcessionAmount money null,
		ConcessionStartDate date null,
		ConcessionEndDate date null)

	INSERT INTO #EROccupants
		EXEC GetOccupantsByDate @accountID, @date, @propertyIDs

		
	INSERT #MyProperties 
		SELECT Value FROM @propertyIDs
		
	INSERT #EffectiveRent
		SELECT	prop.PropertyID,
				ulg.UnitLeaseGroupID, 
				ulg.UnitID,
				prop.Name,
				ut.Name,
				u.Number,
				u.SquareFootage,
				u.PaddedNumber,
				null,
				null, 
				null,
				null,
				null,
				null,
				#ero.MoveInDate,
				#ero.MoveOutDate
			FROM #EROccupants #ero
				INNER JOIN UnitLeaseGroup ulg ON #ero.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #MyProperties #mp ON ut.PropertyID = #mp.PropertyID
				INNER JOIN Property prop ON #mp.PropertyID = prop.PropertyID

				
	-- Get the last lease where the date is in the lease date range
	UPDATE #er SET LeaseID = l.LeaseID				 
		FROM #EffectiveRent #er
			INNER JOIN Lease l ON l.UnitLeaseGroupID = #er.UnitLeaseGroupID
		WHERE #er.UnitLeaseGroupID IS NOT NULL
		  AND (l.LeaseID = (SELECT TOP 1 LeaseID			
								FROM Lease 								
								WHERE UnitLeaseGroupID = l.UnitLeaseGroupID
								  AND LeaseStartDate <= @date
								  AND LeaseEndDate >= @date
								  AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
								ORDER BY DateCreated DESC))
	
	-- Get the last lease where the EndDate <= @date (Month-to-Month Leases) 
	UPDATE #er SET LeaseID = l.LeaseID				 
		FROM #EffectiveRent #er
			INNER JOIN Lease l ON l.UnitLeaseGroupID = #er.UnitLeaseGroupID
		WHERE #er.UnitLeaseGroupID IS NOT NULL
		  AND #er.LeaseID IS NULL
		  AND (l.LeaseID = (SELECT TOP 1 LeaseID			
								FROM Lease 								
								WHERE UnitLeaseGroupID = l.UnitLeaseGroupID								  
								  AND LeaseEndDate <= @date
								  AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
								ORDER BY LeaseEndDate DESC))
	 
	-- For the messed up lease entries, grab the first lease
	-- associated with the UnitLeaseGroup
	UPDATE #er SET LeaseID = l.LeaseID				 				 
		FROM #EffectiveRent #er
			INNER JOIN Lease l ON l.UnitLeaseGroupID = #er.UnitLeaseGroupID
		WHERE #er.UnitLeaseGroupID IS NOT NULL
		  AND #er.LeaseID IS NULL
		  AND (l.LeaseID = (SELECT TOP 1 LeaseID			
								FROM Lease 
								WHERE UnitLeaseGroupID = l.UnitLeaseGroupID							 
								  AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
								ORDER BY LeaseStartDate))			 

	UPDATE #er SET LeaseStartDate = l.LeaseStartDate, LeaseEndDate = l.LeaseEndDate
		FROM #EffectiveRent #er
			INNER JOIN Lease l ON #er.LeaseID = l.LeaseID
			
	UPDATE #er SET MarketRent = [MarketRent].Amount
		FROM #EffectiveRent #er
			CROSS APPLY dbo.GetMarketRentByDate(#er.UnitID, @date, 1) [MarketRent]
							
	UPDATE #EffectiveRent SET Rent = (SELECT SUM(lli.Amount)
										 FROM #EffectiveRent #er
											 INNER JOIN LeaseLedgerItem lli ON #er.LeaseID = lli.LeaseID
											 INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
											 INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
										 WHERE lli.StartDate <= @date
										   AND lli.EndDate >= @date
										   AND #er.LeaseID = #EffectiveRent.LeaseID
										 GROUP BY #er.LeaseID)
										 
	UPDATE #EffectiveRent SET Residents = (SELECT STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
											   FROM Person 
												   INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
												   INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
												   INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
											   WHERE PersonLease.LeaseID = #EffectiveRent.LeaseID
											     AND PersonType.[Type] = 'Resident'				   
												 AND PersonLease.MainContact = 1				   
											   FOR XML PATH ('')), 1, 2, ''))
										 
	INSERT #Concessions
		SELECT	lli.LeaseID,
				lit.Name,
				lli.Amount,
				lli.StartDate,
				lli.EndDate
			FROM #EffectiveRent #ef
				INNER JOIN LeaseLedgerItem lli ON #ef.LeaseID = lli.LeaseID
				INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
				INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRecurringMonthlyRentConcession = 1
			WHERE --lli.StartDate <= @date  -- Want to get future concessions so sop this
			  lli.EndDate >= @date
			  
		UNION
		
		SELECT	lli.LeaseID,
				lit.Name,
				lli.Amount,
				lli.StartDate,
				lli.EndDate
			FROM #EffectiveRent #ef
				INNER JOIN LeaseLedgerItem lli ON #ef.LeaseID = lli.LeaseID
				INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
				INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN LedgerItemTypeApplication lita ON lit.LedgerItemTypeID = lita.LedgerItemTypeID AND lita.CanBeApplied = 1
				INNER JOIN LedgerItemType litCharge ON lita.AppliesToLedgerItemTypeID = litCharge.LedgerItemTypeID AND litCharge.IsRent = 1
			WHERE --lli.StartDate <= @date -- Want to get future concessions so sop this
			  lli.EndDate >= @date
			  
	SELECT	*
		FROM #EffectiveRent #ef
			LEFT JOIN #Concessions #cons ON #ef.LeaseID = #cons.LeaseID
		ORDER BY #ef.PropertyName, #ef.UnitTypeName, #ef.LeaseID, #cons.ConcessionStartDate
										 
END
GO
