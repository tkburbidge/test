SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO











-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 8, 2012
-- Description:	Generates the data for the NSF Log report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_NSFLog]
	-- Add the parameters for the stored procedure here
	@accountingPeriodID uniqueidentifier = null, 
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	--DECLARE @endDate date = (SELECT EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
	
	CREATE TABLE #NSFLog (
		PropertyName nvarchar(50) not null,
		PropertyID uniqueidentifier not null,
		ObjectID uniqueidentifier not null,
		ObjectType nvarchar(50) not null,
		Name nvarchar(500) not null,
		Unit nvarchar(20) null,
		DateReceived datetime not null,
		DateReturned datetime not null,
		Amount money not null,
		LateFeesCharged money null,
		NSFFeesCharged money null,
		CreditsChargedBack money null,
		Balance money null,
		NSFCount int not null,
		Waived bit null,
		WaivedBy nvarchar(500) null,
		WaivedNotes nvarchar(500) null)

	INSERT INTO #NSFLog
		SELECT DISTINCT
				p.Name AS 'PropertyName',
				p.PropertyID AS 'PropertyID',
				t.ObjectID AS 'ObjectID',
				tt.[Group] AS 'ObjectType',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 FOR XML PATH ('')), 1, 2, '') AS 'Names',
				u.Number AS 'Unit',
				py.[Date] AS 'DateReceived',
				py.ReversedDate AS 'DateReturned',
				py.Amount AS 'Amount',
				null AS 'LateFeesCharged',
				null AS 'NSFFeesCharged',
				null AS 'CreditsChargedBack',
				--CB.Balance AS 'Balance',
				0.00 AS 'Balance',
				((SELECT COUNT(DISTINCT p.PaymentID) 
				FROM Payment p					
					LEFT JOIN PersonNote pn ON p.PaymentID = pn.ObjectID AND pn.InteractionType = 'Waived NSF'
				WHERE p.[Type] = 'NSF'
					AND pn.PersonNoteID IS NULL
					AND p.ObjectID = py.ObjectID) + 

				 (SELECT ISNULL(ImportNSFCount, 0) FROM UnitLeaseGroup WHERE UnitLeaseGroupID = py.Objectid))	AS 'NSFCount',
				--CAST(0 AS BIT) AS 'Waived',
				--null AS 'WaivedBy',
				--null AS 'WaivedNotes'	
				CASE 
					WHEN pn.PersonNoteID IS NOT NULL THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)	END AS 'Waived',
				per.PreferredName + ' ' + per.LastName AS 'WaivedBy',
				pn.Note AS 'WaivedNotes'				
			FROM Payment py
				INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = t.ObjectID
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
				--CROSS APPLY GetObjectBalance(null, ap.EndDate, t.ObjectID, 0, @propertyIDs) AS CB
				LEFT JOIN PersonNote pn ON py.PaymentID = pn.ObjectID AND pn.InteractionType = 'Waived NSF'
				--LEFT JOIN PersonTypeProperty pnptp ON pn.CreatedByPersonTypePropertyID = pnptp.PersonTypePropertyID AND p.PropertyID = pnptp.PropertyID
				--LEFT JOIN PersonType pert ON pnptp.PersonTypeID = pert.PersonTypeID
				--LEFT JOIN Person per ON pert.PersonID = per.PersonID
				LEFT JOIN Person per ON pn.CreatedByPersonID = per.PersonID
			WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
			  AND tt.[Group] = 'Lease'
			  AND py.ReversedDate >= pap.StartDate
			  AND py.ReversedDate <= pap.EndDate
			  AND py.ReversedReason = 'Non-Sufficient Funds'
			  AND l.LeaseID = ((SELECT TOP 1 LeaseID
								FROM Lease 
								INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
								WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID									  
								ORDER BY o.OrderBy))		  
  
		UNION
		
		SELECT DISTINCT
				p.Name AS 'PropertyName',
				p.PropertyID AS 'PropertyID',
				t.ObjectID AS 'ObjectID',
				tt.[Group] AS 'ObjectType',
				pr.PreferredName + ' ' + pr.LastName AS 'Names',
				null AS 'Unit',
				py.[Date] AS 'DateReceived',
				py.ReversedDate AS 'DateReturned',
				py.Amount AS 'Amount',
				null AS 'LateFeesCharged',
				null AS 'NSFFeesCharged',
				null AS 'CreditsChargedBack',
				--CB.Balance AS 'Balance',

				0.00 AS 'Balance',
				((SELECT COUNT(DISTINCT p.PaymentID) 
				FROM Payment p					
					LEFT JOIN PersonNote pn ON p.PaymentID = pn.ObjectID AND pn.InteractionType = 'Waived NSF'
				WHERE p.[Type] = 'NSF'
					AND pn.PersonNoteID IS NULL

					AND p.ObjectID = py.ObjectID))	AS 'NSFCount',
				CAST(0 AS BIT) AS 'Waived',
				null AS 'WaivedBy',
				null AS 'WaivedNotes'						
			FROM Payment py
				INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN Person pr ON t.ObjectID = pr.PersonID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
				--CROSS APPLY GetObjectBalance(null, ap.EndDate, t.ObjectID, 0, @propertyIDs) AS CB
			WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
			  AND tt.[Group] <> 'Lease'
			  AND py.ReversedDate IS NOT NULL
			  AND py.ReversedReason = 'Non-Sufficient Funds'
			  AND py.ReversedDate >= pap.StartDate
			  AND py.ReversedDate <= pap.EndDate	

			  
	UPDATE #nl SET Balance = Bal.Balance
		FROM #NSFLog #nl
			--CROSS APPLY GetObjectBalance(null, @endDate, #nl.ObjectID, 0, @propertyIDs) AS [Bal]
			INNER JOIN PropertyAccountingPeriod pap ON #nl.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			CROSS APPLY GetObjectBalance(null, pap.EndDate, #nl.ObjectID, 0, @propertyIDs) AS [Bal]
			
	UPDATE #NSFLog SET LateFeesCharged = (SELECT ISNULL(SUM(t.Amount), 0)
		FROM [Transaction] t
			INNER JOIN Property p ON t.PropertyID = p.PropertyID
			--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
			INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			--INNER JOIN Settings s ON s.AccountID = pap.AccountID
			LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
		WHERE t.ObjectID = #NSFLog.ObjectID
			-- Get the LedgerItemTypeID associated with any LateFeeSchedule tied to the lease
		  AND t.LedgerItemTypeID  IN (SELECT lfs.LedgerItemTypeID
									  FROM LateFeeSchedule lfs
										INNER JOIN Lease l ON lfs.LateFeeScheduleID = lfs.LateFeeScheduleID AND l.UnitLeaseGroupID = #NSFLog.ObjectID)
		  AND t.TransactionDate <= pap.EndDate
		  AND t.TransactionDate >= pap.StartDate
		  AND t.Amount > 0
		  AND tr.TransactionID IS NULL)
		  
	UPDATE #NSFLog SET NSFFeesCharged = (SELECT ISNULL(SUM(t.Amount), 0)
		FROM [Transaction] t
			INNER JOIN Property p ON t.PropertyID = p.PropertyID
			--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
			INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			INNER JOIN Settings s ON s.AccountID = pap.AccountID
			LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
		WHERE t.ObjectID = #NSFLog.ObjectID
		  AND t.LedgerItemTypeID = s.NSFChargeLedgerItemTypeID
		  AND t.Amount > 0
		  AND t.TransactionDate <= pap.EndDate
		  AND t.TransactionDate >= pap.StartDate
		  AND tr.TransactionID IS NULL)		  
		  
	UPDATE #NSFLog SET CreditsChargedBack = (SELECT ISNULL(SUM(t.Amount), 0)
		FROM [Transaction] t
			INNER JOIN Property p ON t.PropertyID = p.PropertyID
			--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
			INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			INNER JOIN Settings s ON s.AccountID = pap.AccountID
			INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
			INNER JOIN Payment py ON py.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
		WHERE t.ObjectID = #NSFLog.ObjectID
		  AND t.LedgerItemTypeID IN (SELECT LedgerItemTypeID 
										FROM LedgerItemType 
										WHERE AccountID = t.AccountID
										  AND IsCredit = 1
										  AND IsRevokable = 1)
		  AND t.TransactionDate <= pap.EndDate
		  AND t.TransactionDate >= pap.StartDate
		  AND tr.TransactionID IS NOT NULL
		  AND py.ReversedReason = 'Late Fee')		  		  
		
	SELECT * FROM #NSFLog
			
END

















GO
