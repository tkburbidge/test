SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 22, 2014
-- Description:	Gets Expired Leases for the Dashboard
-- =============================================
CREATE PROCEDURE [dbo].[RPT_DSH_GetExpiringLeases] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #ExpiringLeases (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(100) not null,
		Unit nvarchar(50) not null,
		LeaseID uniqueidentifier not null,		-- Expired LeaseID
		RenewalLeaseID uniqueidentifier null,
		ResidentNames nvarchar(500) null,
		LeaseEndDate date null,
		LeaseStatus nvarchar(50) null,
		RenewalStartDate date null,				-- Lease.StartDate of the Pending Renewal lease tied to the same UnitLeaseGroupID (if there is one)
		RenewalLeaseSigned bit null,			-- bit indicating whether or not the pending renewal lease (if there is one) has been signed by anyone
		MoveOutDate date null,					-- Max move out date if all residents have a move out date
		LeaseRentCharge money null,				-- Sum of rent charges during the term of the lease
		RenewalRentCharge money null,			-- Sum of rent charges on the renewal
		CurrentRentCharge money null,			-- Sum of current rent charges as of @date
		MonthToMonthFee money null,				-- Sum of the LeaseLedgerItems where date parameter is between start date and end date and the LedgerItemTypeID matches Settings.MonthToMonthFeeLedgerItemTypeID
		MarketRent money null
		)
		
		
	INSERT #ExpiringLeases
		SELECT	DISTINCT 
				p.PropertyID,
				p.Name,
				u.Number,
				l.LeaseID,
				rl.LeaseID,
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 FOR XML PATH ('')), 1, 2, '') AS 'ResidentNames',
				l.LeaseEndDate,
				l.LeaseStatus,
				rl.LeaseStartDate,
				CASE
					WHEN (rlpl.PersonLeaseID IS NOT NULL) THEN CAST(1 AS bit)
					ELSE CAST(0 AS bit) END,
				(SELECT TOP 1 plMO.MoveOutDate
					FROM PersonLease plMO
						LEFT JOIN PersonLease plMONull ON l.LeaseID = plMONull.LeaseID AND plMONull.MoveOutDate IS NULL
					WHERE plMONull.PersonLeaseID IS NULL
						AND plMO.LeaseID = l.LeaseID
					ORDER BY plMO.MoveOutDate DESC),
				null,
				null,
				null,
				null,
				mr.Amount
			FROM UnitLeaseGroup ulg
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID AND p.PropertyID IN (SELECT Value FROM @propertyIDs)
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction') AND l.LeaseEndDate <= @date
				LEFT JOIN Lease rl On ulg.UnitLeaseGroupID = rl.UnitLeaseGroupID AND rl.LeaseStatus = 'Pending Renewal'
				LEFT JOIN PersonLease rlpl ON rl.LeaseID = rlpl.LeaseID AND rlpl.LeaseSignedDate IS NOT NULL
				CROSS APPLY GetMarketRentByDate(u.UnitID, l.LeaseEndDate, 1) mr
				
	UPDATE #ExpiringLeases SET LeaseRentCharge = (SELECT SUM(lli.Amount)
													FROM LeaseLedgerItem lli
														INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
														INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
														INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
													WHERE lli.LeaseID = #ExpiringLeases.LeaseID
													  AND lli.StartDate <= l.LeaseEndDate)

	UPDATE #ExpiringLeases SET RenewalRentCharge = (SELECT SUM(lli.Amount)
													FROM LeaseLedgerItem lli
														INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
														INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
														INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
													WHERE lli.LeaseID = #ExpiringLeases.RenewalLeaseID
													  AND lli.StartDate <= l.LeaseEndDate)

	UPDATE #ExpiringLeases SET CurrentRentCharge = (SELECT SUM(lli.Amount)
													FROM LeaseLedgerItem lli
														INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
														INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
														INNER JOIN Lease l ON lli.LeaseID = l.LeaseID
													WHERE lli.LeaseID = #ExpiringLeases.LeaseID
													  AND lli.StartDate <= @date
													  AND lli.EndDate >= @date)
												  
	UPDATE #ExpiringLeases SET MonthToMonthFee = (SELECT SUM(lli.Amount)
													FROM LeaseLedgerItem lli
														INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
														INNER JOIN Lease l ON lli.LeaseID = l.LeaseID 
														INNER JOIN Settings s ON l.AccountID = s.AccountID
														INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID 
																		AND s.MonthToMonthFeeLedgerItemTypeID = lit.LedgerItemTypeID
													WHERE lli.LeaseID = #ExpiringLeases.LeaseID
														AND lli.StartDate <= @date
														AND lli.EndDate >= @date)

	--UPDATE #ExpiringLeases SET MarketRent = (SELECT TOP 1(mr.Amount)
	--												FROM MarketRent mr
	--													INNER JOIN Unit u ON mr.ObjectID = u.UnitID
	--													INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
	--													INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
	--												WHERE l.LeaseID = #ExpiringLeases.LeaseID
	--												  AND mr.DateChanged <= @date
	--												ORDER BY mr.DateChanged DESC)

	SELECT * 
		FROM #ExpiringLeases
		ORDER BY PropertyName, Unit
END
GO
