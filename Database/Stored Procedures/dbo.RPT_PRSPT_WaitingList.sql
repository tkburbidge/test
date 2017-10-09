SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: May 1, 2014
-- Description:	WaitingList Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRSPT_WaitingList] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@filterDate nvarchar(50) = null,
	@startDate date = null,
	@endDate date = null,
	@includeRemoved bit = 0,
	@includeSatisfied bit = 0,
	@includeCurrent bit = 0,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #WaitingList (
		FirstName nvarchar(50) null,
		LastName nvarchar(50) null,
		ObjectType nvarchar(50) null,
		PropertyName nvarchar(50) null,
		ObjectName nvarchar(50) null,
		DateAdded date null,
		DateRemoved date null,
		DateNeeded date null,
		DateSatisfied date null,
		Phone nvarchar(50) null,
		Email nvarchar(200) null)
	
	INSERT #WaitingList
		SELECT	DISTINCT
				per.FirstName AS 'FirstName',
				per.LastName AS 'LastName',
				wl.ObjectType AS 'ObjectType',
				CASE
					WHEN (u.UnitID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = utu.PropertyID)
					WHEN (ut.UnitTypeID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = ut.PropertyID)
					WHEN (li.LedgerItemID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = lipli.PropertyID)
					WHEN (lip.LedgerItemPoolID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = lip.PropertyID)
					END AS 'PropertyName',			
				CASE
					WHEN (u.UnitID IS NOT NULL) THEN u.Number
					WHEN (ut.UnitTypeID IS NOT NULL) THEN ut.Name 
					WHEN (li.LedgerItemID IS NOT NULL) THEN li.[Description]
					WHEN (lip.LedgerItemPoolID IS NOT NULL) THEN lip.Name
					END AS 'ObjectName',
				wl.DateCreated AS 'DateAdded',
				wl.DateRemoved AS 'DateRemoved', 
				wl.DateNeeded AS 'DateNeeded',
				wl.DateSatisfied AS 'DateSatisfied',
				per.Phone1 AS 'Phone',
				per.Email AS 'Email'
			FROM WaitingList wl
				INNER JOIN Person per ON wl.PersonID = per.PersonID
				LEFT JOIN Unit u ON wl.ObjectType = 'Unit' AND wl.ObjectID = u.UnitID
				LEFT JOIN UnitType utu ON u.UnitTypeID = utu.UnitTypeID
				LEFT JOIN UnitType ut ON wl.ObjectType = 'UnitType' AND wl.ObjectID = ut.UnitTypeID
				LEFT JOIN LedgerItem li ON wl.ObjectType = 'RentableItem' AND wl.ObjectID = li.LedgerItemID
				LEFT JOIN LedgerItemPool lipli ON wl.ObjectType = 'RentableItem' AND li.LedgerItemPoolID = lipli.LedgerItemPoolID		
				LEFT JOIN LedgerItemPool lip ON wl.ObjectType = 'RentableItemType' AND wl.ObjectID = lip.LedgerItemPoolID
				LEFT JOIN PropertyAccountingPeriod pap ON (utu.PropertyID = pap.PropertyID OR ut.PropertyID = pap.PropertyID OR lipli.PropertyID = pap.PropertyID OR lip.PropertyID = pap.PropertyID)
																	AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE ((((@accountingPeriodID IS NULL) AND ((@filterDate IS NULL)
					OR ((@filterDate = 'Added') AND (wl.DateCreated >= @startDate) AND (wl.DateCreated <= @endDate))
					OR ((@filterDate = 'Needed') AND (wl.DateNeeded >= @startDate) AND (wl.DateNeeded <= @endDate))
					OR ((@filterDate = 'Removed') AND (wl.DateRemoved >= @startDate) AND (wl.DateRemoved <= @endDate))
					OR ((@filterDate = 'Satisfied') AND (wl.DateSatisfied >= @startDate) AND (wl.DateSatisfied <= @endDate))))
				 OR ((@accountingPeriodID IS NOT NULL) AND ((@filterDate IS NULL)
					OR ((@filterDate = 'Added') AND (wl.DateCreated >= pap.StartDate) AND (wl.DateCreated <= pap.EndDate))
					OR ((@filterDate = 'Needed') AND (wl.DateNeeded >= pap.StartDate) AND (wl.DateNeeded <= pap.EndDate))
					OR ((@filterDate = 'Removed') AND (wl.DateRemoved >= pap.StartDate) AND (wl.DateRemoved <= pap.EndDate))
					OR ((@filterDate = 'Satisfied') AND (wl.DateSatisfied >= pap.StartDate) AND (wl.DateSatisfied <= pap.EndDate)))))
			  AND ((ut.PropertyID IN (SELECT Value FROM @propertyIDs))
					OR (utu.PropertyID IN (SELECT Value FROM @propertyIDs))
					OR (lipli.PropertyID IN (SELECT Value FROM @propertyIDs))
					OR (lip.PropertyID in (SELECT Value FROM @propertyIDs)))
			  AND ((@includeCurrent = 0) AND (@includeRemoved = 0) AND (@includeSatisfied = 0)))
			  
		UNION
		
		SELECT	DISTINCT
				per.FirstName AS 'FirstName',
				per.LastName AS 'LastName',
				wl.ObjectType AS 'ObjectType',
				CASE
					WHEN (u.UnitID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = utu.PropertyID)
					WHEN (ut.UnitTypeID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = ut.PropertyID)
					WHEN (li.LedgerItemID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = lipli.PropertyID)
					WHEN (lip.LedgerItemPoolID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = lip.PropertyID)
					END AS 'PropertyName',			
				CASE
					WHEN (u.UnitID IS NOT NULL) THEN u.Number
					WHEN (ut.UnitTypeID IS NOT NULL) THEN ut.Name 
					WHEN (li.LedgerItemID IS NOT NULL) THEN li.[Description]
					WHEN (lip.LedgerItemPoolID IS NOT NULL) THEN lip.Name
					END AS 'ObjectName',
				wl.DateCreated AS 'DateAdded',
				wl.DateRemoved AS 'DateRemoved', 
				wl.DateNeeded AS 'DateNeeded',
				wl.DateSatisfied AS 'DateSatisfied',
				per.Phone1 AS 'Phone',
				per.Email AS 'Email'
			FROM WaitingList wl
				INNER JOIN Person per ON wl.PersonID = per.PersonID
				LEFT JOIN Unit u ON wl.ObjectType = 'Unit' AND wl.ObjectID = u.UnitID
				LEFT JOIN UnitType utu ON u.UnitTypeID = utu.UnitTypeID
				LEFT JOIN UnitType ut ON wl.ObjectType = 'UnitType' AND wl.ObjectID = ut.UnitTypeID
				LEFT JOIN LedgerItem li ON wl.ObjectType = 'RentableItem' AND wl.ObjectID = li.LedgerItemID
				LEFT JOIN LedgerItemPool lipli ON wl.ObjectType = 'RentableItem' AND li.LedgerItemPoolID = lipli.LedgerItemPoolID		
				LEFT JOIN LedgerItemPool lip ON wl.ObjectType = 'RentableItemType' AND wl.ObjectID = lip.LedgerItemPoolID
				LEFT JOIN PropertyAccountingPeriod pap ON (utu.PropertyID = pap.PropertyID OR ut.PropertyID = pap.PropertyID OR lipli.PropertyID = pap.PropertyID OR lip.PropertyID = pap.PropertyID)
																	AND pap.AccountingPeriodID = @accountingPeriodID				
			WHERE ((((@accountingPeriodID IS NULL) AND ((@filterDate IS NULL)
					OR ((@filterDate = 'Added') AND (wl.DateCreated >= @startDate) AND (wl.DateCreated <= @endDate))
					OR ((@filterDate = 'Needed') AND (wl.DateNeeded >= @startDate) AND (wl.DateNeeded <= @endDate))
					OR ((@filterDate = 'Removed') AND (wl.DateRemoved >= @startDate) AND (wl.DateRemoved <= @endDate))
					OR ((@filterDate = 'Satisfied') AND (wl.DateSatisfied >= @startDate) AND (wl.DateSatisfied <= @endDate))))
				 OR ((@accountingPeriodID IS NOT NULL) AND ((@filterDate IS NULL)
					OR ((@filterDate = 'Added') AND (wl.DateCreated >= pap.StartDate) AND (wl.DateCreated <= pap.EndDate))
					OR ((@filterDate = 'Needed') AND (wl.DateNeeded >= pap.StartDate) AND (wl.DateNeeded <= pap.EndDate))
					OR ((@filterDate = 'Removed') AND (wl.DateRemoved >= pap.StartDate) AND (wl.DateRemoved <= pap.EndDate))
					OR ((@filterDate = 'Satisfied') AND (wl.DateSatisfied >= pap.StartDate) AND (wl.DateSatisfied <= pap.EndDate)))))
			  AND ((ut.PropertyID IN (SELECT Value FROM @propertyIDs))
					OR (utu.PropertyID IN (SELECT Value FROM @propertyIDs))
					OR (lipli.PropertyID IN (SELECT Value FROM @propertyIDs))
					OR (lip.PropertyID in (SELECT Value FROM @propertyIDs)))
			  AND ((@includeCurrent = 1) AND (wl.DateSatisfied IS NULL) AND (wl.DateRemoved IS NULL)))
					
		UNION
		
		SELECT	DISTINCT
				per.FirstName AS 'FirstName',
				per.LastName AS 'LastName',
				wl.ObjectType AS 'ObjectType',
				CASE
					WHEN (u.UnitID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = utu.PropertyID)
					WHEN (ut.UnitTypeID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = ut.PropertyID)
					WHEN (li.LedgerItemID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = lipli.PropertyID)
					WHEN (lip.LedgerItemPoolID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = lip.PropertyID)
					END AS 'PropertyName',			
				CASE
					WHEN (u.UnitID IS NOT NULL) THEN u.Number
					WHEN (ut.UnitTypeID IS NOT NULL) THEN ut.Name 
					WHEN (li.LedgerItemID IS NOT NULL) THEN li.[Description]
					WHEN (lip.LedgerItemPoolID IS NOT NULL) THEN lip.Name
					END AS 'ObjectName',
				wl.DateCreated AS 'DateAdded',
				wl.DateRemoved AS 'DateRemoved', 
				wl.DateNeeded AS 'DateNeeded',
				wl.DateSatisfied AS 'DateSatisfied',
				per.Phone1 AS 'Phone',
				per.Email AS 'Email'
			FROM WaitingList wl
				INNER JOIN Person per ON wl.PersonID = per.PersonID
				LEFT JOIN Unit u ON wl.ObjectType = 'Unit' AND wl.ObjectID = u.UnitID
				LEFT JOIN UnitType utu ON u.UnitTypeID = utu.UnitTypeID
				LEFT JOIN UnitType ut ON wl.ObjectType = 'UnitType' AND wl.ObjectID = ut.UnitTypeID
				LEFT JOIN LedgerItem li ON wl.ObjectType = 'RentableItem' AND wl.ObjectID = li.LedgerItemID
				LEFT JOIN LedgerItemPool lipli ON wl.ObjectType = 'RentableItem' AND li.LedgerItemPoolID = lipli.LedgerItemPoolID		
				LEFT JOIN LedgerItemPool lip ON wl.ObjectType = 'RentableItemType' AND wl.ObjectID = lip.LedgerItemPoolID
				LEFT JOIN PropertyAccountingPeriod pap ON (utu.PropertyID = pap.PropertyID OR ut.PropertyID = pap.PropertyID OR lipli.PropertyID = pap.PropertyID OR lip.PropertyID = pap.PropertyID)
																	AND pap.AccountingPeriodID = @accountingPeriodID				
			WHERE ((((@accountingPeriodID IS NULL) AND ((@filterDate IS NULL)
					OR ((@filterDate = 'Added') AND (wl.DateCreated >= @startDate) AND (wl.DateCreated <= @endDate))
					OR ((@filterDate = 'Needed') AND (wl.DateNeeded >= @startDate) AND (wl.DateNeeded <= @endDate))
					OR ((@filterDate = 'Removed') AND (wl.DateRemoved >= @startDate) AND (wl.DateRemoved <= @endDate))
					OR ((@filterDate = 'Satisfied') AND (wl.DateSatisfied >= @startDate) AND (wl.DateSatisfied <= @endDate))))
				 OR ((@accountingPeriodID IS NOT NULL) AND ((@filterDate IS NULL)
					OR ((@filterDate = 'Added') AND (wl.DateCreated >= pap.StartDate) AND (wl.DateCreated <= pap.EndDate))
					OR ((@filterDate = 'Needed') AND (wl.DateNeeded >= pap.StartDate) AND (wl.DateNeeded <= pap.EndDate))
					OR ((@filterDate = 'Removed') AND (wl.DateRemoved >= pap.StartDate) AND (wl.DateRemoved <= pap.EndDate))
					OR ((@filterDate = 'Satisfied') AND (wl.DateSatisfied >= pap.StartDate) AND (wl.DateSatisfied <= pap.EndDate)))))
			  AND ((ut.PropertyID IN (SELECT Value FROM @propertyIDs))
					OR (utu.PropertyID IN (SELECT Value FROM @propertyIDs))
					OR (lipli.PropertyID IN (SELECT Value FROM @propertyIDs))
					OR (lip.PropertyID in (SELECT Value FROM @propertyIDs)))
			  AND ((@includeRemoved = 1) AND (wl.DateRemoved IS NOT NULL)))
			  
		UNION
		
		SELECT	DISTINCT
				per.FirstName AS 'FirstName',
				per.LastName AS 'LastName',
				wl.ObjectType AS 'ObjectType',
				CASE
					WHEN (u.UnitID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = utu.PropertyID)
					WHEN (ut.UnitTypeID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = ut.PropertyID)
					WHEN (li.LedgerItemID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = lipli.PropertyID)
					WHEN (lip.LedgerItemPoolID IS NOT NULL) THEN (SELECT Name FROM Property WHERE PropertyID = lip.PropertyID)
					END AS 'PropertyName',			
				CASE
					WHEN (u.UnitID IS NOT NULL) THEN u.Number
					WHEN (ut.UnitTypeID IS NOT NULL) THEN ut.Name 
					WHEN (li.LedgerItemID IS NOT NULL) THEN li.[Description]
					WHEN (lip.LedgerItemPoolID IS NOT NULL) THEN lip.Name
					END AS 'ObjectName',
				wl.DateCreated AS 'DateAdded',
				wl.DateRemoved AS 'DateRemoved', 
				wl.DateNeeded AS 'DateNeeded',
				wl.DateSatisfied AS 'DateSatisfied',
				per.Phone1 AS 'Phone',
				per.Email AS 'Email'
			FROM WaitingList wl
				INNER JOIN Person per ON wl.PersonID = per.PersonID
				LEFT JOIN Unit u ON wl.ObjectType = 'Unit' AND wl.ObjectID = u.UnitID
				LEFT JOIN UnitType utu ON u.UnitTypeID = utu.UnitTypeID
				LEFT JOIN UnitType ut ON wl.ObjectType = 'UnitType' AND wl.ObjectID = ut.UnitTypeID
				LEFT JOIN LedgerItem li ON wl.ObjectType = 'RentableItem' AND wl.ObjectID = li.LedgerItemID
				LEFT JOIN LedgerItemPool lipli ON wl.ObjectType = 'RentableItem' AND li.LedgerItemPoolID = lipli.LedgerItemPoolID		
				LEFT JOIN LedgerItemPool lip ON wl.ObjectType = 'RentableItemType' AND wl.ObjectID = lip.LedgerItemPoolID
				LEFT JOIN PropertyAccountingPeriod pap ON (utu.PropertyID = pap.PropertyID OR ut.PropertyID = pap.PropertyID OR lipli.PropertyID = pap.PropertyID OR lip.PropertyID = pap.PropertyID)
																	AND pap.AccountingPeriodID = @accountingPeriodID				
			WHERE ((((@accountingPeriodID IS NULL) AND ((@filterDate IS NULL)
					OR ((@filterDate = 'Added') AND (wl.DateCreated >= @startDate) AND (wl.DateCreated <= @endDate))
					OR ((@filterDate = 'Needed') AND (wl.DateNeeded >= @startDate) AND (wl.DateNeeded <= @endDate))
					OR ((@filterDate = 'Removed') AND (wl.DateRemoved >= @startDate) AND (wl.DateRemoved <= @endDate))
					OR ((@filterDate = 'Satisfied') AND (wl.DateSatisfied >= @startDate) AND (wl.DateSatisfied <= @endDate))))
				 OR ((@accountingPeriodID IS NOT NULL) AND ((@filterDate IS NULL)
					OR ((@filterDate = 'Added') AND (wl.DateCreated >= pap.StartDate) AND (wl.DateCreated <= pap.EndDate))
					OR ((@filterDate = 'Needed') AND (wl.DateNeeded >= pap.StartDate) AND (wl.DateNeeded <= pap.EndDate))
					OR ((@filterDate = 'Removed') AND (wl.DateRemoved >= pap.StartDate) AND (wl.DateRemoved <= pap.EndDate))
					OR ((@filterDate = 'Satisfied') AND (wl.DateSatisfied >= pap.StartDate) AND (wl.DateSatisfied <= pap.EndDate)))))
			  AND ((ut.PropertyID IN (SELECT Value FROM @propertyIDs))
					OR (utu.PropertyID IN (SELECT Value FROM @propertyIDs))
					OR (lipli.PropertyID IN (SELECT Value FROM @propertyIDs))
					OR (lip.PropertyID in (SELECT Value FROM @propertyIDs)))
			  AND ((@includeSatisfied = 1) AND (wl.DateSatisfied IS NOT NULL)))			
					
					
	SELECT DISTINCT * 
		FROM #WaitingList					
					
					
			  --AND (((@includeRemoved = 1) OR ((@includeRemoved = 0) AND (wl.DateRemoved IS NULL)) OR (@filterDate = 'Removed'))
					--OR ((@includeSatisfied = 1) OR ((@includeSatisfied = 0) AND (wl.DateSatisfied IS NULL)) OR (@filterDate = 'Satisfied'))
					--OR ((@includeCurrent = 1) AND (wl.DateRemoved IS NULL) AND (wl.DateSatisfied IS NULL)))))
					
				
		  --((((wl.DateRemoved IS NULL) OR (@includeRemoved = 1)) OR ((wl.DateSatisfied IS NULL) OR (@includeSatisfied = 1)) 
				--OR ((wl.DateRemoved IS NULL) AND (wl.DateSatisfied IS NULL) AND (@includeCurrent = 1)))


END



GO
