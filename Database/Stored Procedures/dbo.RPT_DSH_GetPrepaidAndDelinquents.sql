SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE PROCEDURE [dbo].[RPT_DSH_GetPrepaidAndDelinquents] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #PrepaidAndDelinquents (
		PropertyName nvarchar(50) not null,
		PropertyID uniqueidentifier not null,
		ObjectID uniqueidentifier not null,
		ObjectType nvarchar(50) not null,
		LeaseID uniqueidentifier null,
		LeaseStatus nvarchar(20) null,
		Unit nvarchar(50) null,
		PaddedUnit nvarchar(50) null,
		Names nvarchar(4000) null,
		Balance money null,
		ULGAPInformationID uniqueidentifier null,
		Reason nvarchar(500) null,
		EndDate date null,
		UnitLeaseGroupID uniqueidentifier null)

	INSERT INTO #PrepaidAndDelinquents
		SELECT	p.Name AS 'PropertyName',
				p.PropertyID AS 'PropertyID',
				l.UnitLeaseGroupID AS 'ObjectID',
				'Lease' AS 'ObjectType',
				l.LeaseID AS 'LeaseID',
				l.LeaseStatus as 'LeaseStatus',
				u.Number AS 'Unit',
				u.PaddedNumber AS 'PaddedUnit',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 FOR XML PATH ('')), 1, 2, '') AS 'Names',	
				--CB.Balance AS 'Balance',
				0 AS 'Balance',
				ulgap.ULGAPInformationID AS 'ULGAPInformationID',
				--CASE 
				--	WHEN (CB.Balance < 0) THEN ulgap.PrepaidReason 
				--	WHEN (CB.Balance > 0) THEN ulgap.DelinquentReason
				--	END AS 'Reason',
				null AS 'Reason',
				pap.EndDate AS 'EndDate',
				null AS 'UnitLeaseGroupID'	
			FROM UnitLeaseGroup ulg
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON b.PropertyID = p.PropertyID
				INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyAccountingPeriodID = p.CurrentPropertyAccountingPeriodID
				INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = pap.AccountingPeriodID
				LEFT JOIN ULGAPInformation ulgap ON ulgap.ObjectID = ulg.UnitLeaseGroupID AND ulgap.AccountingPeriodID = ap.AccountingPeriodID
				--CROSS APPLY GetObjectBalance(null, ap.EndDate, l.UnitLeaseGroupID, 0, @propertyIDs) AS CB 
			WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
			  --AND CB.Balance <> 0
			  AND l.LeaseID = (SELECT TOP 1 Lease.LeaseID 
								FROM Lease  
								INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
								WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID			     		 
								ORDER BY Ordering.OrderBy)
													 
		UNION
		
		SELECT	p.Name AS 'PropertyName',
				p.PropertyID AS 'PropertyID',
				t.ObjectID AS 'ObjectID',
				tt.[Group] AS 'ObjectType',
				l.LeaseID AS 'LeaseID',
				null as 'LeaseStatus',
				u.Number AS 'Unit',
				u.PaddedNumber AS 'PaddedUnit',
				CASE
					WHEN (woita.BillingAccountID IS NOT NULL) THEN
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
					WHEN (woita.WOITAccountID IS NOT NULL) THEN woita.Name
					END AS 'Names',
				--CB.Balance AS 'Balance',
				0 AS 'Balance',
				ulgap.ULGAPInformationID AS 'ULGAPInformationID',
				--CASE 
				--	WHEN (CB.Balance < 0) THEN ulgap.PrepaidReason 
				--	WHEN (CB.Balance > 0) THEN ulgap.DelinquentReason
				--	END AS 'Reason',
				null AS 'Reason',
				pap.EndDate AS 'EndDate',
				woita.BillingAccountID AS 'UnitLeaseGroupID'
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyAccountingPeriodID = p.CurrentPropertyAccountingPeriodID
				INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = pap.AccountingPeriodID
				LEFT JOIN Person pr ON t.ObjectID = pr.PersonID
				LEFT JOIN WOITAccount woita ON t.ObjectID = woita.WOITAccountID
				LEFT JOIN ULGAPInformation ulgap ON ulgap.ObjectID = t.ObjectID AND ulgap.AccountingPeriodID = ap.AccountingPeriodID
				LEFT JOIN UnitLeaseGroup ulg ON woita.BillingAccountID = ulg.UnitLeaseGroupID
				LEFT JOIN Unit u ON ulg.UnitID = u.UnitID
				LEFT JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				--CROSS APPLY GetObjectBalance(null, ap.EndDate, t.ObjectID, 0, @propertyIDs) AS CB 
			WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
			  --AND CB.Balance <> 0	
			  AND tt.[Group] IN ('Non-Resident Account', 'Prospect', 'WOIT Account')
			  AND (l.LeaseID IS NULL OR l.LeaseID = (SELECT TOP 1 Lease.LeaseID 
													 FROM Lease  
													 INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
													 WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID			     		 
													 ORDER BY Ordering.OrderBy))
			  
	UPDATE #PAD SET Balance = CB.Balance
		FROM #PrepaidAndDelinquents #PAD
			CROSS APPLY GetObjectBalance(null, #PAD.EndDate, #PAD.ObjectID, 0, @propertyIDs) AS CB
		WHERE #PAD.ObjectID = CB.ObjectID
				  
	UPDATE #PAD SET Reason = CASE 
								WHEN (#PAD.Balance < 0) THEN ulgap.PrepaidReason 
								WHEN (#PAD.Balance > 0) THEN ulgap.DelinquentReason
							END 
		FROM #PrepaidAndDelinquents #PAD
			INNER JOIN Property p ON #PAD.PropertyID = p.PropertyID
			INNER JOIN PropertyAccountingPeriod pap ON pap.PropertyAccountingPeriodID = p.CurrentPropertyAccountingPeriodID
			LEFT JOIN ULGAPInformation ulgap ON ulgap.ObjectID = #PAD.ObjectID AND ulgap.AccountingPeriodID = pap.AccountingPeriodID
				  
	SELECT PropertyName, PropertyID, ObjectID, ObjectType, LeaseID,LeaseStatus, Unit, PaddedUnit, Names, Balance, ULGAPInformationID, Reason, UnitLeaseGroupID
		FROM #PrepaidAndDelinquents
		WHERE Balance <> 0
		ORDER BY PropertyName, PaddedUnit, Names
		--ORDER BY p.Name, u.PaddedNumber, Names												 
			
END
GO
