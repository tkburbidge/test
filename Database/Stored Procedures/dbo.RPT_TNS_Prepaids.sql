SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 6, 2012
-- Description:	Generates the data for the Prepaids Report which lists the residents and other people that currently have a prepaid account.
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_Prepaids]
	-- Add the parameters for the stored procedure here
	@accountingPeriodID uniqueidentifier = null,
	@objectTypes StringCollection READONLY,
	@leaseStatuses StringCollection READONLY,
	@propertyIDs GuidCollection READONLY
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--DECLARE @startDate date, @endDate date, @dayBeforeStartDate date
	--SELECT @startDate = StartDate, @endDate = EndDate, @dayBeforeStartDate = DATEADD(day, -1, StartDate) FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID

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


	CREATE TABLE #Prepaids (
		PropertyName nvarchar(50) not null,
		Unit nvarchar(20) null,
		PaddedNumber nvarchar(20) null,
		TransactionObjectID uniqueidentifier null,
		PropertyID uniqueidentifier null,
		ObjectID uniqueidentifier not null,
		ObjectType nvarchar(20) not null,
		Name nvarchar(4000) null,
		LeaseStatus nvarchar(50) null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		MoveOutDate date null,
		PeriodBalance money null,
		PreviousBalance money null,
		TimesLate int null,
		PrepaidReason nvarchar(2000) null)

	INSERT #Prepaids
		SELECT p.Name As 'PropertyName', u.Number AS 'Unit', u.PaddedNumber AS 'PaddedNumber', ulg.UnitLeaseGroupID AS 'TransactionObjectID', p.PropertyID AS 'PropertyID',
				l.LeaseID AS 'ObjectID', 'Lease' AS 'ObjectType',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'
						   AND PersonLease.MainContact = 1
					 FOR XML PATH ('')), 1, 2, '') AS 'Name',
				l.LeaseStatus AS 'LeaseStatus', l.LeaseStartDate AS 'LeaseStartDate', l.LeaseEndDate AS 'LeaseEndDate',
				(SELECT MAX(pl.MoveOutDate)
					FROM PersonLease pl
						LEFT JOIN PersonLease pl2 ON pl2.LeaseID = l.LeaseID AND pl2.MoveOutDate IS NULL
					WHERE pl.LeaseID = l.LeaseID
					  AND pl2.PersonLeaseID IS NULL) AS 'MoveOutDate',
				--CB.Balance AS 'PeriodBalance',
				--PB.Balance as 'PreviousBalance',
				0.00 AS 'PeriodBalance',
				0.00 AS 'PreviousBalance',
				((SELECT COUNT(*) FROM ULGAPInformation WHERE ObjectID = ulg.UnitLeaseGroupID AND Late = 1) +
				ISNULL((SELECT ImportTimesLate FROM UnitLeaseGroup WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID), 0)) AS 'TimesLate',
				ulgap.PrepaidReason AS 'PrepaidReason'
			FROM UnitLeaseGroup ulg
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
				LEFT JOIN ULGAPInformation ulgap ON ulg.UnitLeaseGroupID = ulgap.ObjectID AND ulgap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN Property p ON b.PropertyID = p.PropertyID
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
				--CROSS APPLY GetObjectBalance(ap.StartDate, ap.EndDate, l.UnitLeaseGroupID, 0, @propertyIDs) AS CB
				--CROSS APPLY GetObjectBalance(null, DATEADD(day, -1, ap.StartDate), l.UnitLeaseGroupID, 0, @propertyIDs) AS PB
			WHERE 'Lease' IN (SELECT Value FROM @objectTypes)
			  AND l.LeaseStatus IN (SELECT Value FROM @leaseStatuses)
			 AND l.LeaseID = ((SELECT TOP 1 LeaseID
								FROM Lease
								INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
								WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
								ORDER BY o.OrderBy))

		UNION

		SELECT p.Name As 'PropertyName', u.Number AS 'Unit', u.PaddedNumber AS 'PaddedNumber', t.ObjectID AS 'TransactionObjectID', t.PropertyID AS 'PropertyID',
				CASE
					WHEN (woita.BillingAccountID IS NOT NULL AND l.LeaseID IS NOT NULL) THEN l.LeaseID
					WHEN (pr.PersonID IS NOT NULL) THEN pr.PersonID
					WHEN (woita.WOITAccountID IS NOT NULL) THEN woita.WOITAccountID
					END AS 'ObjectID',
				CASE
					WHEN (woita.BillingAccountID IS NOT NULL) THEN 'HAP Account'
					ELSE tt.[Group]
				END AS 'ObjectType',
				CASE
					WHEN (woita.BillingAccountID IS NOT NULL) THEN
						STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						FROM Person
							INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID
							INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						WHERE PersonLease.LeaseID = l.LeaseID
							AND PersonType.[Type] = 'Resident'
							AND PersonLease.MainContact = 1
						FOR XML PATH ('')), 1, 2, '')
					WHEN (pr.PersonID IS NOT NULL) THEN pr.PreferredName + ' ' + pr.LastName
					WHEN (woita.WOITAccountID IS NOT NULL) THEN woita.Name
					END AS 'Name',
				null AS 'LeaseStatus', null AS 'LeaseStartDate', null AS 'LeaseEndDate', null AS 'MoveOutDate',
				--CB.Balance AS 'PeriodBalance',
				--PB.Balance AS 'PreviousBalance',
				0.00 AS 'PeriodBalance',
				0.00 AS 'PreviousBalance',
				(SELECT COUNT(*) FROM ULGAPInformation WHERE ObjectID = t.ObjectID AND Late = 1) AS 'TimesLate',
				ulgap.PrepaidReason AS 'PrepaidReason'
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
				LEFT JOIN Person pr ON t.ObjectID = pr.PersonID
				LEFT JOIN WOITAccount woita ON t.ObjectID = woita.WOITAccountID
				LEFT JOIN ULGAPInformation ulgap ON t.ObjectID = ulgap.ObjectID AND ulgap.AccountingPeriodID = @accountingPeriodID
				--CROSS APPLY GetObjectBalance(ap.StartDate, ap.EndDate, t.ObjectID, 0, @propertyIDs) AS CB
				--CROSS APPLY GetObjectBalance(null, DATEADD(day, -1, ap.StartDate), t.ObjectID, 0, @propertyIDs) AS PB
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
				LEFT JOIN UnitLeaseGroup ulg ON woita.BillingAccountID = ulg.UnitLeaseGroupID
				LEFT JOIN Unit u ON ulg.UnitID = u.UnitID
				LEFT JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			WHERE t.Amount > 0
			  --AND tt.Name = 'Prepayment'
			  AND tt.[Group] IN (SELECT Value FROM @objectTypes)
			  AND tt.[Group] IN ('Prospect', 'Non-Resident Account', 'WOIT Account')
			  AND (l.LeaseID IS NULL OR l.LeaseID = (SELECT TOP 1 Lease.LeaseID
													 FROM Lease
													 INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
													 WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID
													 ORDER BY Ordering.OrderBy))

	UPDATE #pp SET PeriodBalance = CurBal.Balance, PreviousBalance = PrevBal.Balance
		FROM #Prepaids #pp
			--CROSS APPLY GetObjectBalance(@startDate, @endDate, #pp.TransactionObjectID, 0, @propertyIDs) AS [CurBal]
			--CROSS APPLY GetObjectBalance(null, @dayBeforeStartDate, #pp.TransactionObjectID, 0, @propertyIDs) AS [PrevBal]
			INNER JOIN #PropertiesAndDates #pad ON #pp.PropertyID = #pad.PropertyID --AND #pad.Sequence = @ctr
			CROSS APPLY GetObjectBalance(#pad.StartDate, #pad.EndDate, #pp.TransactionObjectID, 0, @propertyIDs) AS [CurBal]
			CROSS APPLY GetObjectBalance(null, #pad.DayBeforeStartDate, #pp.TransactionObjectID, 0, @propertyIDs) AS [PrevBal]

	SELECT PropertyName, Unit, PropertyID, ObjectID, ObjectType, Name, LeaseStatus, LeaseStartDate, LeaseEndDate, MoveOutDate,
			PeriodBalance, PreviousBalance, TimesLate, PrepaidReason
		FROM #Prepaids
		WHERE (PeriodBalance + PreviousBalance) < 0
		ORDER BY PaddedNumber, Name

END
GO
