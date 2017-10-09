SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 3, 2012
-- Description:	Generates the data for Delinquency report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_Delinquency] 
	-- Add the parameters for the stored procedure here
	@accountingPeriodID uniqueidentifier = null, 
	@objectTypes StringCollection READONLY,
	@leaseStatuses StringCollection READONLY,
	@propertyIDs GuidCollection READONLY
AS

DECLARE @startDate date
DECLARE @dayBeforeStartDate date
DECLARE @endDate date

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertiesAndDates (
		Sequence int identity,
		PropertyID uniqueidentifier NOT NULL,
		StartDate date NOT NULL,
		EndDate date NOT NULL,
		DayBeforeStartDate date NOT NULL)
		
	INSERT #PropertiesAndDates 
		SELECT pIDs.Value, pap.StartDate, pap.EndDate, DATEADD(day, -1, pap.StartDate)
			FROM @propertyIDs pIDs
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		
	
	CREATE TABLE #Deliquents (
		PropertyName nvarchar(50) not null,
		Unit nvarchar(50) null,
		PaddedUnit nvarchar(50) null,
		PropertyID uniqueidentifier not null,
		ObjectID uniqueidentifier not null,
		ObjectType nvarchar(50) null,
		Name nvarchar(4000) null,
		PhoneNumber nvarchar(50) null,
		LeaseStatus nvarchar(50) null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		MoveOutDate date null,
		PeriodBalance money null,
		PreviousBalance money null,
		TimesLate int null,
		DelinquencyReason nvarchar(2000) null,
		UnitLeaseGroupID uniqueidentifier null)
	
	INSERT INTO #Deliquents
		SELECT DISTINCT p.Name AS 'PropertyName', u.Number AS 'Unit', u.PaddedNumber, p.PropertyID AS 'PropertyID', l.LeaseID AS 'ObjectID', 'Lease' AS 'ObjectType',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 FOR XML PATH ('')), 1, 2, '') AS 'Name',
				(SELECT TOP 1 per1.Phone1
					FROM Person per1
						INNER JOIN PersonLease pl ON per1.PersonID = pl.PersonID AND pl.MainContact = 1
					WHERE pl.LeaseID = l.LeaseID
					ORDER BY pl.OrderBy) AS 'PhoneNumber',
				l.LeaseStatus AS 'LeaseStatus', l.LeaseStartDate AS 'LeaseStartDate', l.LeaseEndDate AS 'LeaseEndDate',
				(SELECT MAX(pl.MoveOutDate)
					FROM PersonLease pl
						LEFT JOIN PersonLease pl2 ON pl2.LeaseID = l.LeaseID AND pl2.MoveOutDate IS NULL
					WHERE pl.LeaseID = l.LeaseID
					  AND pl2.PersonLeaseID IS NULL) AS 'MoveOutDate',
				--CB.Balance AS 'PeriodBalance', 
				--PB.Balance AS 'PreviousBalance',
				0 AS 'PeriodBalance', 0 AS 'PreviousBalance',
				((SELECT COUNT(*) FROM ULGAPInformation WHERE ObjectID = ulg.UnitLeaseGroupID AND Late = 1) +
				ISNULL((SELECT ImportTimesLate FROM UnitLeaseGroup WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID), 0)) AS 'TimesLate',
				ulgap.DelinquentReason AS 'DelinquencyReason',
				ulg.UnitLeaseGroupID AS 'UnitLeaseGroupID'
			FROM UnitLeaseGroup ulg
				--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON b.PropertyID = p.PropertyID
				LEFT JOIN ULGAPInformation ulgap ON ulgap.ObjectID = ulg.UnitLeaseGroupID AND ulgap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
				--CROSS APPLY GetObjectBalance(null, DATEADD(day, -1, ap.StartDate), l.UnitLeaseGroupID, 0, @propertyIDs) AS PB
				--CROSS APPLY GetObjectBalance(ap.StartDate, ap.EndDate, l.UnitLeaseGroupID, 0, @propertyIDs) AS CB
			WHERE 'Lease' IN (SELECT Value FROM @objectTypes)
			  AND l.LeaseStatus IN (SELECT Value FROM @leaseStatuses)
			  AND l.LeaseID = ((SELECT TOP 1 LeaseID
								FROM Lease 
								INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
								WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								ORDER BY o.OrderBy))
													 
		UNION

		SELECT DISTINCT p.Name AS 'PropertyName',
				u.Number AS 'Unit',
				null AS 'PaddedUnit',
				p.PropertyID AS 'PropertyID',
				CASE
					WHEN (woit.BillingAccountID IS NOT NULL AND l.LeaseID IS NOT NULL) THEN l.LeaseID
					ELSE t.ObjectID
				END AS 'ObjectID',
				CASE
					WHEN (woit.BillingAccountID IS NOT NULL) THEN 'HAP Account'
					ELSE tt.[Group]
				END AS 'ObjectType',
				CASE
					WHEN (woit.BillingAccountID IS NOT NULL) THEN
						STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						FROM Person 
							INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID
							INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
							INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
						WHERE PersonLease.LeaseID = l.LeaseID
							AND PersonType.[Type] = 'Resident'
							AND PersonLease.MainContact = 1
						FOR XML PATH ('')), 1, 2, '')
					WHEN (pr.PersonID IS NOT NULL) THEN pr.PreferredName + ' ' + pr.LastName 
					WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name
				END AS 'Name',
				pr.Phone1 AS 'PhoneNumber',
				null AS 'LeaseStatus', null AS 'LeaseStartDate', null AS 'LeaseEndDate', null AS 'MoveOutDate',
				--CB.Balance AS 'PeriodBalance',
				--PB.Balance AS 'PreviousBalance',
				0 AS 'PeriodBalance', 0 AS 'PreviousBalance',
				((SELECT COUNT(*) FROM ULGAPInformation WHERE ObjectID = t.ObjectID AND Late = 1)) AS 'TimesLate',
				ulgap.DelinquentReason AS 'DelinquencyReason',
				t.ObjectID AS 'UnitLeaseGroupID'
			FROM [Transaction] t
				--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN [TransactionType] tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				LEFT JOIN Person pr ON t.ObjectID = pr.PersonID
				LEFT JOIN WOITAccount woit ON t.ObjectID = woit.WOITAccountID
				LEFT JOIN ULGAPInformation ulgap ON t.ObjectID = ulgap.ObjectID AND ulgap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
				LEFT JOIN UnitLeaseGroup ulg ON woit.BillingAccountID = ulg.UnitLeaseGroupID
				LEFT JOIN Unit u ON ulg.UnitID = u.UnitID
				LEFT JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				--CROSS APPLY GetObjectBalance(null, DATEADD(day, -1, ap.StartDate), t.ObjectID, 0, @propertyIDs) AS PB
				--CROSS APPLY GetObjectBalance(ap.StartDate, ap.EndDate, t.ObjectID, 0, @propertyIDs) AS CB
			WHERE tt.[Group] IN (SELECT Value FROM @objectTypes)
			  AND tt.[Group] IN ('Non-Resident Account', 'Prospect', 'WOIT Account')
			  AND (l.LeaseID IS NULL OR l.LeaseID = (SELECT TOP 1 Lease.LeaseID 
													 FROM Lease  
													 INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
													 WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID			     		 
													 ORDER BY Ordering.OrderBy))

	UPDATE #D SET PreviousBalance = PrevBal.Balance, PeriodBalance = CurBal.Balance
		FROM #Deliquents #D
			INNER JOIN #PropertiesAndDates #pad ON #D.PropertyID = #pad.PropertyID --AND #pad.Sequence = @ctr
			CROSS APPLY GetObjectBalance(null, DATEADD(DAY, -1, #pad.StartDate), #D.UnitLeaseGroupID, 0, @propertyIDs) AS [PrevBal]
			CROSS APPLY GetObjectBalance(#pad.StartDate, #pad.EndDate, #D.UnitLeaseGroupID, 0, @propertyIDs) AS [CurBal]
	
	SELECT * FROM #Deliquents
	WHERE (PeriodBalance + PreviousBalance) > 0
	ORDER BY PropertyName, PaddedUnit, Name
	 
END
GO
