SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: May 10, 2012
-- Description:	Gets the data for the AvailableRentableItems
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RNTITM_AvailableRentableItems] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	/*
		Load all rentable items
		Update the CurrentLeaseID		
		Update the PendingLeaseID
		Update the CurrentNonResidentID
		Update the PendingNonResidentID

		Set Status

	*/
	CREATE TABLE #RentableItems (
		--ProperyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		[Type] nvarchar(50) null,
		Name nvarchar(50) null, 
		LedgerItemID uniqueidentifier null,
		Charge money null,
		LedgerItemPoolName nvarchar(50) null, 
		Rentable bit null, 
		AttachedUnitNumber nvarchar(50) null,
		MoveInDate date null,
		DateAvailable date null,
		Applicants nvarchar(500) null, 
		OldLeaseID uniqueidentifier null,
		OldLessorType nvarchar(100),
		NewLeaseID uniqueidentifier null,
		NewLessorType nvarchar(100),
		Unit nvarchar(50) null,
		LedgerItemTypePoolID uniqueidentifier null,
		LedgerItemPoolMarketingDescription nvarchar(400) null,
		IncludeInOnlineApplication bit null,
		AttachedToUnitID uniqueidentifier null)
		
	CREATE TABLE #NonResidentRentals (
		LedgerItemID uniqueidentifier not null,
		Amount money not null,
		DateAvailable date not null,
		PersonName nvarchar(100) null)

	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier
	)

	INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs

	INSERT #RentableItems
		SELECT DISTINCT
					p.Name AS 'PropertyName',			
					null AS 'Type',
					li.[Description] AS 'Name',
					li.LedgerItemID AS 'LedgerItemID',
					li.Amount AS 'Charge',
					lip.Name AS 'LedgerItemPoolName',
					CASE WHEN li.IsDown = 1 THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS 'Rentable',
					au.Number AS 'AttachedUnitNumber',
					null AS 'MoveInDate',
					NULL AS 'DateAvailable',
					NULL AS 'Applicants',
					NULL AS 'OldLeaseID',
					NULL AS 'OldLessorType',
					NULL AS 'NewLeaseID',
					NULL AS 'NewLessorType',
					NULL AS 'Unit',
					lip.LedgerItemPoolID,
					lip.MarketingDescription AS 'LedgerItemPoolMarketingDescription',
					lip.IncludeInOnlineApplication,
					li.AttachedToUnitID
				FROM LedgerItem li
					INNER JOIN LedgerItemPool lip ON li.LedgerItemPoolID = lip.LedgerItemPoolID
					INNER JOIN Property p ON lip.PropertyID = p.PropertyID
					LEFT JOIN Unit au ON li.AttachedToUnitID = au.UnitID								
					INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = p.PropertyID
				

	/* Get current occupant leases */
	UPDATE #RentableItems SET OldLeaseID = (SELECT TOP 1 l.LeaseID
											FROM LeaseLedgerItem lli
												INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
											WHERE l.LeaseStatus IN ('Current', 'Under Eviction')
												AND lli.StartDate <= @date 
												AND lli.EndDate >= @date
												AND lli.LedgerItemID = #RentableItems.LedgerItemID)

	UPDATE #ri
		SET MoveInDate = lli.StartDate,
			DateAvailable = CASE 
								WHEN (plmo.PersonLeaseID IS NULL) THEN (SELECT MAX(MoveOutDate) FROM PersonLease WHERE LeaseID = l.LeaseID)
								ELSE NULL
								END,
			Applicants = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						 FROM Person 
							 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
							 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
							 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
						 WHERE PersonLease.LeaseID = l.LeaseID
							   AND PersonType.[Type] = 'Resident'				   
							   AND PersonLease.MainContact = 1
						 ORDER BY PersonLease.OrderBy, PersonLease.PersonLeaseID
						 FOR XML PATH ('')), 1, 2, ''),
			Unit = u.Number,
			OldLessorType = 'Lease'
	FROM #RentableItems #ri
		INNER JOIN Lease l ON l.LeaseID = #ri.OldLeaseID
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u ON u.UnitID = ulg.UnitID
		INNER JOIN LeaseLedgerItem lli ON lli.LeaseID = l.LeaseID AND lli.LedgerItemID = #ri.LedgerItemID
		LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.MoveOutDate IS NULL

	/* Get current occupant Non-Residents */
	UPDATE #RentableItems SET OldLeaseID = (SELECT TOP 1 nrli.NonResidentLedgerItemID
											FROM NonResidentLedgerItem nrli
											WHERE nrli.StartDate <= @date 
												AND nrli.EndDate >= @date
												AND nrli.LedgerItemID = #RentableItems.LedgerItemID)
	WHERE #RentableItems.OldLeaseID IS NULL

	UPDATE #ri
		SET MoveInDate = nrli.StartDate,
			DateAvailable = null,-- NonResidents are never "on-notice" so don't show this as available if a non-resident is renting it
								 --	It will just become available when the charge expires
			Applicants = p.FirstName + ' ' + p.LastName,
			Unit = null,
			OldLessorType = 'Non-Resident',
			OldLeaseID = p.PersonID
	FROM #RentableItems #ri
		INNER JOIN NonResidentLedgerItem nrli ON nrli.NonResidentLedgerItemID = #ri.OldLeaseID
		INNER JOIN Person p ON p.PersonID = nrli.PersonID
	WHERE OldLeaseID IS NOT NULL AND OldLessorType IS NULL

	/* Get pending occupant leases */
	UPDATE #RentableItems SET NewLeaseID = (SELECT TOP 1 l.LeaseID
											FROM LeaseLedgerItem lli
												INNER JOIN Lease l ON l.LeaseID = lli.LeaseID
											WHERE l.LeaseStatus IN ('Current', 'Under Eviction', 'Pending', 'Pending Renewal', 'Pending Transfer')
												AND lli.EndDate > @date
												AND (#RentableItems.OldLeaseID IS NULL OR l.LeaseID <> #RentableItems.OldLeaseID)
												AND lli.LedgerItemID = #RentableItems.LedgerItemID)


	UPDATE #ri
		SET MoveInDate = lli.StartDate,
			DateAvailable = CASE 
								WHEN #ri.DateAvailable IS NOT NULL THEN #ri.DateAvailable  -- Preserve DateAvailable from above query
								WHEN (plmo.PersonLeaseID IS NULL) THEN (SELECT MAX(MoveOutDate) FROM PersonLease WHERE LeaseID = l.LeaseID)
								ELSE NULL
							END,
			Applicants = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						 FROM Person 
							 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
							 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
							 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
						 WHERE PersonLease.LeaseID = l.LeaseID
							   AND PersonType.[Type] = 'Resident'				   
							   AND PersonLease.MainContact = 1
						 ORDER BY PersonLease.OrderBy, PersonLease.PersonLeaseID
						 FOR XML PATH ('')), 1, 2, ''),
			Unit = u.Number,
			NewLessorType = 'Lease'
	FROM #RentableItems #ri
		INNER JOIN Lease l ON l.LeaseID = #ri.NewLeaseID
		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
		INNER JOIN Unit u ON u.UnitID = ulg.UnitID
		INNER JOIN LeaseLedgerItem lli ON lli.LeaseID = l.LeaseID AND lli.LedgerItemID = #ri.LedgerItemID
		LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.MoveOutDate IS NULL
	WHERE #ri.OldLeaseID IS NULL OR #ri.DateAvailable IS NOT NULL  -- Do this for currently vacant or on notice rentable items
				
																										

	UPDATE #RentableItems SET NewLeaseID = (SELECT TOP 1 nrli.NonResidentLedgerItemID
											FROM NonResidentLedgerItem nrli
											WHERE nrli.EndDate > @date
												AND nrli.LedgerItemID = #RentableItems.LedgerItemID												
												AND (#RentableItems.OldLeaseID IS NULL OR nrli.PersonID <> #RentableItems.OldLeaseID))
	WHERE #RentableItems.NewLeaseID IS NULL
	
	UPDATE #ri
		SET MoveInDate = nrli.StartDate,
			DateAvailable = COALESCE(#ri.DateAvailable, null), --NonResidents are never "on-notice" so don't show this as available if a non-resident is renting it
															   --				 It will just become available when the charge expires
			Applicants = p.FirstName + ' ' + p.LastName,
			Unit = null,
			NewLessorType = 'Non-Resident',
			NewLeaseID = p.PersonID
	FROM #RentableItems #ri
		INNER JOIN NonResidentLedgerItem nrli ON nrli.NonResidentLedgerItemID = #ri.NewLeaseID
		INNER JOIN Person p ON p.PersonID = nrli.PersonID
	WHERE #ri.NewLeaseID IS NOT NULL AND NewLessorType IS NULL

	UPDATE #ri 
		SET [Type] = CASE
						WHEN ((OldLeaseID IS NULL) AND (NewLeaseID IS NULL)) THEN 'Vacant'
						WHEN ((OldLeaseID IS NULL) AND (NewLeaseID IS NOT NULL)) THEN  'Reserved'--'Vacant Pre-Leased'
						WHEN ((OldLeaseID IS NOT NULL) AND (NewLeaseID IS NOT NULL) AND (DateAvailable IS NOT NULL)) THEN 'Reserved'--'Notice to Vacate Pre-Leased'
						WHEN ((OldLeaseID IS NOT NULL) AND (NewLeaseID IS NULL) AND (DateAvailable IS NOT NULL)) THEN 'Notice to Vacate'
						END	
	FROM #RentableItems #ri

				
	SELECT DISTINCT * FROM #RentableItems
	WHERE [Type] IS NOT NULL
		ORDER BY PropertyName, Name		
	
END


GO
