SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Olsen
-- Create date: August 3, 2012
-- Description:	Gets the data needed for MITS 20 Customers
--				interface
-- =============================================
CREATE PROCEDURE [dbo].[GetMITS2_0Customers]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	SELECT * FROM (
		SELECT DISTINCT
			--b.Name AS 'Building',
			--u.Number AS 'Unit',
			--ut.Name AS 'UnitTypeName',
			--ut.Bedrooms,
			--ut.Bathrooms,
			--ut.SquareFootage,
			--ut.MarketRent,
			--ut.[Description] AS 'UnitTypeDescription',
			u.UnitID,
			u.UnitTypeID,
			u.AddressIncludesUnitNumber,
			a.StreetAddress AS 'UnitStreetAddress', 
			a.City AS 'UnitCity',
			a.[State] AS 'UnitState',
			a.Zip AS 'UnitZip',
			fa.StreetAddress AS 'FwdStreetAddress', 
			fa.City AS 'FwdCity',
			fa.[State] AS 'FwdState',
			fa.Zip AS 'FwdZip',
			ma.StreetAddress AS 'MailingStreetAddress', 
			ma.City AS 'MailingCity',
			ma.[State] AS 'MailingState',
			ma.Zip AS 'MailingZip',
			-- If the lease is pending then get all the non-cancelled residents
			-- as the occupancy count
			-- Otherwise get the count of the residents with a residency status
			-- that matches the lease status
			(CASE WHEN l.LeaseStatus IN ('Pending', 'Pending Transfer') THEN
					(SELECT COUNT(*) 
					 FROM PersonLease pl3
					 INNER JOIN PickListItem pli ON pli.Name = pl3.HouseholdStatus AND (pli.IsNotOccupant IS NULL OR pli.IsNotOccupant = 0)
					 WHERE pl3.LeaseID = l.LeaseID 
						AND pl3.ResidencyStatus NOT IN ('Cancelled', 'Denied')
						AND pli.[Type] = 'HouseholdStatus'
						AND pli.AccountID = @accountID)
				  ELSE
		  			(SELECT COUNT(*) 
					 FROM PersonLease pl3
					 INNER JOIN PickListItem pli ON pli.Name = pl3.HouseholdStatus AND (pli.IsNotOccupant IS NULL OR pli.IsNotOccupant = 0)
					 WHERE pl3.LeaseID = l.LeaseID 
						AND pl3.ResidencyStatus = l.LeaseStatus
						AND pli.[Type] = 'HouseholdStatus'
						AND pli.AccountID = @accountID)
			END) AS Occupants,
			ulg.UnitLeaseGroupID,
			l.LeaseStatus,
			p.PersonID,
			p.FirstName,
			p.MiddleName,
			p.LastName,	
			p.Email,
			(CASE WHEN p.Phone1Type = 'Mobile' THEN p.Phone1
				  WHEN p.Phone2Type = 'Mobile' THEN p.Phone2
				  WHEN p.Phone3Type = 'Mobile' THEN p.Phone3
				  ELSE null 
			 END) AS 'MobilePhone',
			(CASE WHEN p.Phone1Type = 'Home' THEN p.Phone1
				  WHEN p.Phone2Type = 'Home' THEN p.Phone2
				  WHEN p.Phone3Type = 'Home' THEN p.Phone3
				  ELSE null 
			 END) AS 'HomePhone',
			(CASE WHEN p.Phone1Type = 'Work' THEN p.Phone1
				  WHEN p.Phone2Type = 'Work' THEN p.Phone2
				  WHEN p.Phone3Type = 'Work' THEN p.Phone3
				  ELSE null 
			 END) AS 'WorkPhone',
			pl.OrderBy,
			pl.MoveInDate,
			pl.MoveOutDate,	
			pl.LeaseSignedDate,
			pl.ResidencyStatus,
			pl.MainContact,
			(SELECT SUM(lli.Amount)
			 FROM LeaseLedgerItem lli
			 INNER JOIN LedgerItem li ON li.LedgerItemID = lli.LedgerItemID
			 INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = li.LedgerItemTypeID
			 WHERE lli.LeaseID = l.LeaseID
				AND lit.IsRent = 1
				AND lli.StartDate <= GETDATE()
				AND lli.EndDate >= GETDATE()) AS 'Rent',
			l.LeaseStartDate,
			l.LeaseEndDate,			
			-- Get the earliest move in date among the non-cancelled residents
			--(SELECT MIN(MoveInDate)
			-- FROM PersonLease pl3
			-- WHERE pl3.LeaseID = l.LeaseID 
			--	AND pl3.ResidencyStatus NOT IN ('Cancelled')) AS MoveInDate,
			-- Get the latest move out date if everyone has a move out date
			(CASE WHEN l.LeaseStatus = 'Former' OR l.LeaseStatus = 'Evicted' THEN (SELECT MAX(pl3.MoveOutDate)
																						FROM PersonLease pl3
																						WHERE pl3.LeaseID = l.LeaseID 
																						  AND pl3.ResidencyStatus NOT IN ('Cancelled', 'Denied'))
				  ELSE NULL
			END) AS MoveOutDater,
			u.PaddedNumber,
			ulg.OnlinePaymentsDisabled,
			ulg.CashOnlyOverride,
			u.IsHoldingUnit
		FROM UnitLeaseGroup ulg
		INNER JOIN Unit u on u.UnitID = ulg.UnitID
		--INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
		LEFT JOIN [Address] a ON u.AddressID = a.AddressID
		INNER JOIN Building b ON b.BuildingID = u.BuildingID
		INNER JOIN Property prop ON prop.PropertyID = b.PropertyID
		INNER JOIN Settings s ON u.AccountID = s.AccountID
		-- Get current, former, and pending leases
		INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND LeaseStatus IN ('Current', 'Former', 'Pending', 'Pending Transfer', 'Under Eviction', 'Evicted')
		INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.ResidencyStatus NOT IN ('Cancelled', 'Denied')
		-- Don't include non-occupant HouseholdStatuses
		INNER JOIN PickListItem pli ON pli.Name = pl.HouseholdStatus AND pli.[Type] = 'HouseholdStatus' AND (pli.IsNotOccupant IS NULL OR pli.IsNotOccupant = 0)
		INNER JOIN Person p ON pl.PersonID = p.PersonID
		LEFT JOIN [Address] fa ON fa.ObjectID = p.PersonID AND fa.AddressType = 'Forwarding'
		LEFT JOIN [Address] ma ON ma.ObjectID = p.PersonID AND ma.AddressType = 'MailingAddress'
		--LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.MoveOutDate IS NULL
		WHERE 		
			prop.AccountID = @accountID 
			AND pli.AccountID = @accountID
			AND prop.PropertyID = @propertyID
			/*AND u.IsHoldingUnit = 0*/) AS Customers
	WHERE
	-- Make sure to only return former lease that have moved out in the last 60 days
	((MoveOutDater IS NULL) OR (MoveOutDater >= DATEADD(DAY, -60, GETDATE())))
	ORDER BY PaddedNumber, LeaseStatus
END
GO
