SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: May 10, 2012
-- Description:	Gets the guts for the RentableItemDetail report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RNTITM_GetRentableItemDetails] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #AllRentableItems (
		PropertyName nvarchar(500) not null,
		LedgerItemID uniqueidentifier not null,
		LedgerItemPoolName nvarchar(100) not null,
		MarketAmount money null,
		Name nvarchar(500) null,
		IsDown bit null,
		Occupied bit null,
		ScheduledCharge money null,
		AttachedUnitNumber nvarchar(500) null,
		LeaseID uniqueidentifier null, 
		UnitNumber nvarchar(500) null, 
		Residents nvarchar(4000) null, 
		DateAvailable date null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		LedgerItemTypeName nvarchar(50) null,
		LedgerItemPoolSquareFeet int null)
		
	CREATE TABLE #ItemsRented (
		LedgerItemID nvarchar(50) not null,
		LeaseID uniqueidentifier null,
		DateAvailable date null,
		PersonOrAlienName nvarchar(1000) null,
		Charge money null,
		Unit nvarchar(100) null,
		LeaseStartDate date null,
		LeaseEndDate date null)

	INSERT #AllRentableItems
		SELECT	p.Name AS 'PropertyName',
				li.LedgerItemID AS 'LedgerItemID',
				lip.Name AS 'LedgerItemPoolName',
				lip.Amount AS 'MarketAmount',
				li.[Description] AS 'Name',
				li.IsDown AS 'IsDown',				
				CAST(0 AS BIT) AS 'Occupied',				
				null AS 'ScheduledCharge',
				ulgli.Number AS 'AttachedUnitNumber',				
				NULL AS 'LeaseID',				
				NULL AS 'UnitNumber',
				NULL AS 'Residents',		
				NULL AS 'DateAvailable',
				NULL AS 'LeaseStartDate',
				NULL AS 'LeaseEndDate',
				lit.Name AS 'LedgerItemTypeName',
				lip.SquareFootage AS 'LedgerItemPoolSquareFeet'
			FROM LedgerItem li
				INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN LedgerItemPool lip ON li.LedgerItemPoolID = lip.LedgerItemPoolID
				INNER JOIN Property p ON lip.PropertyID = p.PropertyID
				LEFT JOIN Unit ulgli ON li.AttachedToUnitID = ulgli.UnitID
			WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
			

	INSERT #ItemsRented
		SELECT DISTINCT
				lli.LedgerItemID,
				l.LeaseID,
				CASE 
					WHEN (plmo.PersonLeaseID IS NULL) THEN (SELECT MAX(MoveOutDate) FROM PersonLease WHERE LeaseID = l.LeaseID)
					ELSE NULL
				END,
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
							 FROM Person 
								 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
								 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
								 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
							 WHERE PersonLease.LeaseID = l.LeaseID
								   AND PersonType.[Type] = 'Resident'				   
								   AND PersonLease.MainContact = 1
							 ORDER BY PersonLease.OrderBy, PersonLease.PersonLeaseID
							 FOR XML PATH ('')), 1, 2, ''),
				 lli.Amount,
				 u.Number,
				 l.LeaseStartDate,
				 l.LeaseEndDate
			FROM LeaseLedgerItem lli
				INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
				LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID and plmo.MoveOutDate IS NULL
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN #AllRentableItems #ari ON #ari.LedgerItemID = lli.LedgerItemID
			WHERE l.LeaseStatus IN ('Current', 'Under Eviction')
				AND lli.StartDate <= @date 
				AND lli.EndDate >= @date
				AND lli.LedgerItemID = #ari.LedgerItemID

	INSERT #ItemsRented (LedgerItemID, DateAvailable, PersonOrAlienName, Charge, Unit)

		SELECT nrli.LedgerItemID, null, per.PreferredName + ' ' + per.LastName, nrli.Amount, null
			FROM NonResidentLedgerItem nrli
				INNER JOIN Person per ON nrli.PersonID = per.PersonID
				INNER JOIN #AllRentableItems #ari ON #ari.LedgerItemID = nrli.LedgerItemID
			WHERE nrli.StartDate <= @date
			  AND nrli.EndDate >= @date 
		
	UPDATE #ari SET Occupied = 1, Residents = #ir.PersonOrAlienName, DateAvailable = #ir.DateAvailable, 
					ScheduledCharge = #ir.Charge, UnitNumber = #ir.Unit, LeaseId = #ir.LeaseID,
					LeaseStartDate = #ir.LeaseStartDate, LeaseEndDate = #ir.LeaseEndDate

		FROM #AllRentableItems #ari
			INNER JOIN #ItemsRented #ir ON #ari.LedgerItemID = #ir.LedgerItemID	
	
	SELECT * 
		FROM #AllRentableItems
		ORDER BY PropertyName, Name
		  
END
GO
