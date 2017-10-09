SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 28, 2012
-- Description:	Lists the Lease Applications by Salesperson
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_LeaseApplications] 
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
	
	CREATE TABLE #LeaseApplicants (
		Unit nvarchar(50) null,
		Applicants nvarchar(200) null,
		ApplicationDate date null,
		MoveInDate date null,
		Rent money null,
		OtherCharges money null,
		UnitType nvarchar(50) null, 
		MovingFrom nvarchar(100) null, 
		Industry nvarchar(100) null,
		ReasonForLeaving nvarchar(500) null,
		Cancelled bit null,
		Denied bit null,
		PropertyName nvarchar(100) null,
		LeaseID uniqueidentifier null,
		UnitID uniqueidentifier null,
		MarketRent money null,
		LastMoveOutDate date null,
		DaysVacant int null,
		UnitLeaseGroupID uniqueidentifier null)

	CREATE TABLE #MaxDaysByProperty (
		PropertyID uniqueidentifier not null,
		MaxDays int not null)
	
	INSERT #MaxDaysByProperty
		SELECT pIDs.Value, ISNULL(MAX(amr.DaysToComplete), 0)
			FROM @propertyIDs pIDs
				LEFT JOIN AutoMakeReady amr ON pIDs.Value = amr.PropertyID
			GROUP BY pIDs.Value

	INSERT #LeaseApplicants
	SELECT	DISTINCT
			u.Number AS 'Unit',
			STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				 FROM Person 
					 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 --INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				 WHERE PersonLease.LeaseID = l.LeaseID
					   AND PersonType.[Type] = 'Resident'				   
					   AND PersonLease.MainContact = 1		
				 ORDER BY PersonLease.OrderBy					   		   
				 FOR XML PATH ('')), 1, 2, '') AS 'Applicants',			
			(SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID) AS 'ApplicationDate',
			(SELECT MIN(pl.MoveInDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID) AS 'MoveInDate',
			ISNULL((SELECT SUM(lli.Amount)
				FROM LeaseLedgerItem lli
					INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
					INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1 AND lit.IsCharge = 1
				WHERE lli.LeaseID = l.LeaseID), 0) AS 'Rent',
			ISNULL((SELECT SUM(CASE WHEN lit.IsCharge = 1 THEN lli.Amount ELSE -lli.Amount END)
				FROM LeaseLedgerItem lli
					INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
					INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 0 AND (lit.IsCharge = 1 OR lit.IsCredit = 1)
				WHERE lli.LeaseID = l.LeaseID), 0) AS 'OtherCharges',
			ut.Name AS 'UnitType',
			STUFF((SELECT ', ' + MovingFrom
					FROM (SELECT DISTINCT MovingFrom, OrderBy
							FROM Prospect 
								INNER JOIN PersonLease ON Prospect.PersonID = PersonLease.PersonID		
								INNER JOIN PersonType ON Prospect.PersonID = PersonType.PersonID
									--INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
							WHERE PersonLease.LeaseID = l.LeaseID
							  AND PersonType.[Type] = 'Resident'				   
							  AND PersonLease.MainContact = 1) MovingFroms	
					ORDER BY OrderBy			   
				FOR XML PATH ('')), 1, 2, '') AS 'MovingFrom',			
			STUFF((SELECT ', ' + Industry
					FROM (SELECT DISTINCT Industry, OrderBy
							FROM Employment 
								INNER JOIN PersonLease ON Employment.PersonID = PersonLease.PersonID		
								INNER JOIN PersonType ON Employment.PersonID = PersonType.PersonID
									--INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
							WHERE PersonLease.LeaseID = l.LeaseID
							  AND PersonType.[Type] = 'Resident'				   
							  AND PersonLease.MainContact = 1) Industries				  
						  ORDER BY OrderBy							  
				FOR XML PATH ('')), 1, 2, '') AS 'Industry',		
			
		   (CASE WHEN ulg.PreviousUnitLeaseGroupID IS NOT NULL THEN '(PT) ' ELSE '' END) +
			ISNULL(STUFF((SELECT '; ' + Note
					FROM (SELECT TOP 1 Note, InteractionType, DateCreated
							FROM PersonNote 										
								INNER JOIN PersonLease ON PersonLease.PersonID = PersonNote.PersonID
							WHERE PersonLease.LeaseID = l.LeaseID


								AND InteractionType IN ('Cancelled', 'Denied')							
							) ReasonsForLeaving				   						   
							ORDER BY InteractionType DESC, DateCreated DESC
				FOR XML PATH ('')), 1, 2, ''), '') AS 'ReasonForLeaving',
			CASE
				WHEN (l.LeaseStatus = 'Cancelled') THEN CAST(1 AS bit)
				ELSE CAST(0 AS bit) END AS 'Cancelled',	
			CASE
				WHEN (l.LeaseStatus = 'Denied') THEN CAST(1 AS bit)
				ELSE CAST(0 AS bit) END AS 'Denied',			
			--CASE
			--	WHEN (SELECT COUNT(*) FROM PersonNote WHERE PersonID = pl.PersonID AND InteractionType = 'Denied') > 0 THEN CAST(1 AS bit)
			--	ELSE CAST(0 AS bit) END AS 'Denied',
			p.Name AS 'PropertyName',
				l.LeaseID AS 'LeaseID',
				u.UnitID AS 'UnitID',  
				null AS 'MarketRent',
				null AS 'LastMoveOutDate',
				null AS 'DaysVacant',
				ulg.UnitLeaseGroupID
		FROM Lease l
			INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
			INNER JOIN Person per ON pl.PersonID = per.PersonID
			INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN Property p ON ut.PropertyID = p.PropertyID		
			LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID	
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)		  
		  AND pl.MainContact = 1
		  -- Ensure the first application occurred within the given date range
		  --AND @startDate <= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)
		  --AND @endDate >= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)
		  AND (((@accountingPeriodID IS NULL)
			  AND (@startDate <= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
			  AND (@endDate >= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID)))
			OR ((@accountingPeriodID IS NOT NULL)	  
			  AND (pap.StartDate <= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))
			  AND (pap.EndDate >= (SELECT MIN(pl.ApplicationDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID))))			
		  AND l.LeaseID = (SELECT TOP 1 l2.LeaseID
						   FROM Lease l2
						   WHERE l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
						   ORDER BY l2.LeaseStartDate)		  

	UPDATE #la SET MarketRent = [MarRent].Amount
		FROM #LeaseApplicants #la
			CROSS APPLY GetMarketRentByDate(#la.UnitID, #la.ApplicationDate, 1) [MarRent]

	UPDATE #LeaseApplicants SET LastMoveOutDate = (SELECT TOP 1 MoveOutDate
													FROM
														(
															SELECT ulg.UnitLeaseGroupID, MAX(pl.MoveOutDate) AS MoveOutDate
															FROM UnitLeaseGroup ulg
															INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND LeaseStatus IN ('Former', 'Evicted')
															INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.ResidencyStatus IN ('Former', 'Evicted')
															WHERE ulg.UnitID = #LeaseApplicants.UnitID
															GROUP BY ulg.UnitLeaseGroupID
														) AS MoveOuts
													WHERE MoveOuts.MoveOutDate < #LeaseApplicants.ApplicationDate
													ORDER BY MoveOuts.MoveOutDate DESC)

	UPDATE #LeaseApplicants SET DaysVacant = DATEDIFF(DAY, LastMoveOutDate, MoveInDate)
		WHERE LastMoveOutDate IS NOT NULL
			AND MoveInDate IS NOT NULL

	SELECT * FROM #LeaseApplicants
		ORDER BY PropertyName, Unit
	
END

GO
