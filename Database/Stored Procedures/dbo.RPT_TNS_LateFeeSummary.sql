SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Rick Bertelsen
-- Create date: June 12, 2013
-- Description:	This report returns a row for each account that had late fees posted or waived durjing the accounting period passed in as a parameter
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_LateFeeSummary] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #LateFees (
		AccountingPeriodID uniqueidentifier null,
		Property nvarchar(50) null,
		ObjectID uniqueidentifier null,
		PropertyID uniqueidentifier null,
		ObjectType nvarchar(50) null,
		Unit nvarchar(50) null,
		PaddedUnit nvarchar(50) null,
		Names nvarchar(250) null,
		TransactionID uniqueidentifier null,
		ReversedTransactionID uniqueidentifier null,
		NonPeriodReversedTransactionID uniqueidentifier null,
		LateFeesCharged money null,	
		LateFeesReversed money null,
		NonCurrentPeriodLateFeesReversed money null,
		ConcessionRevoked money null,
		WaivedLateFeesNotes nvarchar(500) null				
		)
		
	CREATE TABLE #LateFeesToReturn (
		AccountingPeriodID uniqueidentifier null,
		Property nvarchar(50) null,
		ObjectID uniqueidentifier null,
		PropertyID uniqueidentifier null,
		ObjectType nvarchar(50) null,
		Unit nvarchar(50) null,
		PaddedUnit nvarchar(50) null,
		Names nvarchar(250) null,
		LateFeesCharged money null,
		LateFeesReversed money null,
		NonCurrentPeriodLateFeesReversed money null
		)		
	
	CREATE TABLE #LFSPropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #LFSPropertyIDs SELECT Value FROM @propertyIDs
	
	INSERT #LateFees
		SELECT	@accountingPeriodID AS 'AccountingPeriodID',
				p.Name AS 'Property',
				t.ObjectID AS 'ObjectID',
				p.PropertyID AS 'PropertyID',
				'Lease' AS 'ObjectType',
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
				t.TransactionID AS 'TransactionID',
				null AS 'ReversedTransactionID',
				null AS 'NonPeriodReversedTransactionID',
				t.Amount AS 'LateFeesCharged',
				null AS 'LateFeesReversed',
				null AS 'NonCurrentPeriodLateFeesReversed',
				null AS 'ConcessionRevoked',
				null AS 'WaivedLateFeesNotes'				
			FROM UnitLeaseGroup ulg
				--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				--INNER JOIN Settings s ON ulg.AccountID = s.AccountID
				--INNER JOIN LedgerItemType lit ON s.LateFeeLedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID --AND ((l.LeaseStartDate <= ap.EndDate) AND (l.LeaseEndDate >= ap.StartDate))
				INNER JOIN LateFeeSchedule lfs ON l.LateFeeScheduleID = lfs.LateFeeScheduleID
				INNER JOIN LedgerItemType lit ON lfs.LedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN [Transaction] t ON ulg.UnitLeaseGroupID = t.ObjectID AND lit.LedgerItemTypeID = t.LedgerItemTypeID
													--AND t.TransactionDate >= ap.StartDate AND t.TransactionDate <= ap.EndDate
													AND t.TransactionDate >= pap.StartDate AND t.TransactionDate <= pap.EndDate
													AND t.ReversesTransactionID IS NULL
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] = 'Lease'
				INNER JOIN #LFSPropertyIDs pids ON pids.PropertyID = p.PropertyID
			WHERE ulg.AccountID = @accountID				
				AND l.LeaseID = ((SELECT TOP 1 LeaseID
							FROM Lease 
							INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
							WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID									  
							ORDER BY o.OrderBy))
											
	-- Reversals of late fees where the original late fee is in the current period
	INSERT #LateFees
		SELECT	@accountingPeriodID AS 'AccountingPeriodID',
				p.Name AS 'Property',
				t.ObjectID AS 'ObjectID',
				p.PropertyID AS 'PropertyID',
				'Lease' AS 'ObjectType',
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
				null AS 'TransactionID',
				tr.TransactionID AS 'ReversedTransactionID',
				null AS 'NonPeriodReversedTransactionID',
				null AS 'LateFeesCharged',
				tr.Amount AS 'LateFeesReversed',
				null AS 'NonCurrentPeriodLateFeesReversed',
				null AS 'ConcessionRevoked',
				null AS 'WaivedLateFeesNotes'				
			FROM UnitLeaseGroup ulg
				--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				--INNER JOIN Settings s ON ulg.AccountID = s.AccountID
				--INNER JOIN LedgerItemType lit ON s.LateFeeLedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID --AND ((l.LeaseStartDate <= ap.EndDate) AND (l.LeaseEndDate >= ap.StartDate))
				INNER JOIN LateFeeSchedule lfs ON l.LateFeeScheduleID = lfs.LateFeeScheduleID
				INNER JOIN LedgerItemType lit ON lfs.LedgerItemTypeID = lit.LedgerItemTypeID
				--INNER JOIN [Transaction] t ON ulg.UnitLeaseGroupID = t.ObjectID AND lit.LedgerItemTypeID = t.LedgerItemTypeID		
				INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID		
				INNER JOIN [Transaction] tr ON lit.LedgerItemTypeID = tr.LedgerItemTypeID --tr.ReversesTransactionID = t.TransactionID --AND tr.Origin = 'L'
												 AND tr.ObjectID = ulg.UnitLeaseGroupID
												 --AND tr.TransactionDate >= ap.StartDate AND tr.TransactionDate <= ap.EndDate
												 AND tr.TransactionDate >= pap.StartDate AND tr.TransactionDate <= pap.EndDate
												 AND tr.ReversesTransactionID IS NOT NULL
				INNER JOIN TransactionType tt ON tr.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] = 'Lease'
				INNER JOIN [Transaction] t ON t.TransactionID = tr.ReversesTransactionID 
											--AND t.TransactionDate >= ap.StartDate AND t.TransactionDate <= ap.EndDate
											AND t.TransactionDate >= pap.StartDate AND t.TransactionDate <= pap.EndDate
				INNER JOIN #LFSPropertyIDs pids ON pids.PropertyID = p.PropertyID
			WHERE ulg.AccountID = @accountID
				AND l.LeaseID = ((SELECT TOP 1 LeaseID
							FROM Lease 
							INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
							WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID									  
							ORDER BY o.OrderBy))
							

	-- Reversals of late fees where the original late fee is outside current period
	INSERT #LateFees
		SELECT	@accountingPeriodID AS 'AccountingPeriodID',
				p.Name AS 'Property',
				t.ObjectID AS 'ObjectID',
				p.PropertyID AS 'PropertyID',
				'Lease' AS 'ObjectType',
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
				null AS 'TransactionID',
				null AS 'ReversedTransactionID',
				tr.TransactionID AS 'NonPeriodReversedTransactionID',
				null AS 'LateFeesCharged',
				null AS 'LateFeesReversed',
				tr.Amount AS 'NonCurrentPeriodLateFeesReversed',
				null AS 'ConcessionRevoked',
				null AS 'WaivedLateFeesNotes'				
			FROM UnitLeaseGroup ulg
				--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				--INNER JOIN Settings s ON ulg.AccountID = s.AccountID
				--INNER JOIN LedgerItemType lit ON s.LateFeeLedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID --AND ((l.LeaseStartDate <= ap.EndDate) AND (l.LeaseEndDate >= ap.StartDate))
				INNER JOIN LateFeeSchedule lfs ON l.LateFeeScheduleID = lfs.LateFeeScheduleID
				INNER JOIN LedgerItemType lit ON lfs.LedgerItemTypeID = lit.LedgerItemTypeID
				--INNER JOIN [Transaction] t ON ulg.UnitLeaseGroupID = t.ObjectID AND lit.LedgerItemTypeID = t.LedgerItemTypeID	
				INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID			
				INNER JOIN [Transaction] tr ON lit.LedgerItemTypeID = tr.LedgerItemTypeID--tr.ReversesTransactionID = t.TransactionID --AND tr.Origin = 'L'
												AND tr.ObjectID = ulg.UnitLeaseGroupID
												--AND tr.TransactionDate >= ap.StartDate AND tr.TransactionDate <= ap.EndDate
												AND tr.TransactionDate >= pap.StartDate AND tr.TransactionDate <= pap.EndDate
												AND tr.ReversesTransactionID IS NOT NULL
				INNER JOIN TransactionType tt ON tr.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] = 'Lease'
				INNER JOIN [Transaction] t ON t.TransactionID = tr.ReversesTransactionID 
											--AND (t.TransactionDate < ap.StartDate OR t.TransactionDate > ap.EndDate)
											AND (t.TransactionDate < pap.StartDate OR t.TransactionDate > pap.EndDate)
				INNER JOIN #LFSPropertyIDs pids ON pids.PropertyID = p.PropertyID
			WHERE ulg.AccountID = @accountID
				AND l.LeaseID = ((SELECT TOP 1 LeaseID
							FROM Lease 
							INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
							WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID									  
							ORDER BY o.OrderBy))							
			
										
	-- Late fees charged to non-leasees
	INSERT #LateFees
		SELECT	@accountingPeriodID AS 'AccountingPeriodID',
				p.Name AS 'Property',
				t.ObjectID AS 'ObjectID',
				p.PropertyID AS 'PropertyID',
				tt.[Group] AS 'ObjectType',
				null AS 'Unit',
				null AS 'PaddedUnit',
				CASE
					WHEN (per.PersonID IS NOT NULL) THEN per.PreferredName + ' ' + per.LastName
					WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name END AS 'Names',
				t.TransactionID AS 'TransactionID',
				null AS 'ReversedTransactionID',
				null AS 'NonPeriodReversedTransactionID',
				t.Amount AS 'LateFeesCharged',
				null AS 'LateFeesReversed',
				null AS 'NonCurrentPeriodLateFeesReversed',
				null AS 'ConcessionRevoked',
				null AS 'WaivedLateFeesNotes'
			FROM Property p --Settings s 
				--INNER JOIN AccountingPeriod ap ON s.AccountID = ap.AccountID AND ap.AccountingPeriodID = @accountingPeriodID
				--INNER JOIN LedgerItemType lit ON s.LateFeeLedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN LateFeeSchedule lfs ON p.LateFeeScheduleID = lfs.LateFeeScheduleID
				INNER JOIN LedgerItemType lit ON lfs.LedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN [Transaction] t ON lit.LedgerItemTypeID = t.LedgerItemTypeID
													AND p.PropertyID = t.PropertyID
													--AND t.TransactionDate >= ap.StartDate AND t.TransactionDate <= ap.EndDate
													AND t.ReversesTransactionID IS NULL
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] IN ('Non-Resident Account', 'Prospect', 'WOIT Account')
				--INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
													AND t.TransactionDate >= pap.StartDate AND t.TransactionDate <= pap.EndDate
				INNER JOIN #LFSPropertyIDs pids ON pids.PropertyID = p.PropertyID
				LEFT JOIN Person per ON t.ObjectID = per.PersonID
				LEFT JOIN WOITAccount woit ON t.ObjectID = woit.WOITAccountID
			--WHERE s.AccountID = @accountID				

	-- Reversals of late fees where the original late fee is in the current period
	INSERT #LateFees
		SELECT	@accountingPeriodID AS 'AccountingPeriodID',
				p.Name AS 'Property',
				t.ObjectID AS 'ObjectID',
				p.PropertyID AS 'PropertyID',
				tt.[Group] AS 'ObjectType',
				null AS 'Unit',
				null AS 'PaddedUnit',
				CASE
					WHEN (per.PersonID IS NOT NULL) THEN per.PreferredName + ' ' + per.LastName
					WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name END AS 'Names',
				null AS 'TransactionID',
				tr.TransactionID AS 'ReversedTransactionID',
				null AS 'NonPeriodReversedTransactionID',
				null AS 'LateFeesCharged',
				tr.Amount AS 'LateFeesReversed',
				null AS 'NonCurrentPeriodLateFeesReversed',
				null AS 'ConcessionRevoked',
				null AS 'WaivedLateFeesNotes'
			FROM Property p --Settings s 
				--INNER JOIN AccountingPeriod ap ON s.AccountID = ap.AccountID AND ap.AccountingPeriodID = @accountingPeriodID
				--INNER JOIN LedgerItemType lit ON s.LateFeeLedgerItemTypeID = lit.LedgerItemTypeID	
				INNER JOIN LateFeeSchedule lfs ON p.LateFeeScheduleID = lfs.LateFeeScheduleID
				INNER JOIN LedgerItemType lit ON lfs.LedgerItemTypeID = lit.LedgerItemTypeID					
				INNER JOIN [Transaction] tr ON lit.LedgerItemTypeID = tr.LedgerItemTypeID
												 --AND tr.TransactionDate >= ap.StartDate AND tr.TransactionDate <= ap.EndDate
												 AND tr.ReversesTransactionID IS NOT NULL
				INNER JOIN TransactionType tt ON tr.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] IN ('Non-Resident Account', 'Prospect', 'WOIT Account')
				INNER JOIN [Transaction] t ON t.TransactionID = tr.ReversesTransactionID 
											AND p.PropertyID = t.PropertyID
											--AND t.TransactionDate >= ap.StartDate AND t.TransactionDate <= ap.EndDate
				--INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
												AND tr.TransactionDate >= pap.StartDate AND tr.TransactionDate <= pap.EndDate
												AND t.TransactionDate >= pap.StartDate AND t.TransactionDate <= pap.EndDate
				INNER JOIN #LFSPropertyIDs pids ON pids.PropertyID = p.PropertyID
				LEFT JOIN Person per ON t.ObjectID = per.PersonID
				LEFT JOIN WOITAccount woit ON t.ObjectID = woit.WOITAccountID
			--WHERE  tr.AccountID = @accountID
	
	-- Reversals of late fees where the original late fee is not in the current period			
	INSERT #LateFees
		SELECT	@accountingPeriodID AS 'AccountingPeriodID',
				p.Name AS 'Property',
				tr.ObjectID AS 'ObjectID',
				p.PropertyID AS 'PropertyID',
				tt.[Group] AS 'ObjectType',
				null AS 'Unit',
				null AS 'PaddedUnit',
				CASE
					WHEN (per.PersonID IS NOT NULL) THEN per.PreferredName + ' ' + per.LastName
					WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name END AS 'Names',
				null AS 'TransactionID',
				null AS 'ReversedTransactionID',
				tr.TransactionID AS 'NonPeriodReversedTransactionID',
				null AS 'LateFeesCharged',
				null AS 'LateFeesReversed',
				tr.Amount AS 'NonCurrentPeriodLateFeesReversed',
				null AS 'ConcessionRevoked',
				null AS 'WaivedLateFeesNotes'
			FROM Property p --Settings s 
				--INNER JOIN AccountingPeriod ap ON s.AccountID = ap.AccountID AND ap.AccountingPeriodID = @accountingPeriodID
				--INNER JOIN LedgerItemType lit ON s.LateFeeLedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN LateFeeSchedule lfs ON p.LateFeeScheduleID = lfs.LateFeeScheduleID
				INNER JOIN LedgerItemType lit ON lfs.LedgerItemTypeID = lit.LedgerItemTypeID
				--INNER JOIN [Transaction] t ON ulg.UnitLeaseGroupID = t.ObjectID AND lit.LedgerItemTypeID = t.LedgerItemTypeID				
				INNER JOIN [Transaction] tr ON lit.LedgerItemTypeID = tr.LedgerItemTypeID --tr.ReversesTransactionID = t.TransactionID --AND tr.Origin = 'L'												 
												 --AND tr.TransactionDate >= ap.StartDate AND tr.TransactionDate <= ap.EndDate
												 AND tr.ReversesTransactionID IS NOT NULL
				INNER JOIN TransactionType tt ON tr.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] IN ('Non-Resident Account', 'Prospect', 'WOIT Account')
				INNER JOIN [Transaction] t ON t.TransactionID = tr.ReversesTransactionID 
											AND p.PropertyID = t.PropertyID
											--AND (t.TransactionDate < ap.StartDate OR t.TransactionDate > ap.EndDate)
				--INNER JOIN Property p ON tr.PropertyID = p.PropertyID
				INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
												AND tr.TransactionDate >= pap.StartDate AND tr.TransactionDate <= pap.EndDate
												AND (t.TransactionDate < pap.StartDate OR t.TransactionDate > pap.EndDate)
				INNER JOIN #LFSPropertyIDs pids ON pids.PropertyID = p.PropertyID
				LEFT JOIN Person per ON tr.ObjectID = per.PersonID
				LEFT JOIN WOITAccount woit ON tr.ObjectID = woit.WOITAccountID
			--WHERE tr.AccountID = @accountID
			
			
			
			
	INSERT #LateFeesToReturn	
		SELECT DISTINCT
				#lf.AccountingPeriodID,
				#lf.Property,
				#lf.ObjectID,
				#lf.PropertyID,
				#lf.ObjectType,
				#lf.Unit,
				#lf.PaddedUnit,
				#lf.Names,
				ISNULL(SUM(ISNULL(#lf.LateFeesCharged, 0)), 0) AS 'LateFeesCharged',
				ISNULL(SUM(ISNULL(#lf.LateFeesReversed, 0)), 0) AS 'LateFeesReversed',
				ISNULL(SUM(ISNULL(#lf.NonCurrentPeriodLateFeesReversed, 0)), 0) AS 'NonCurrentPeriodLateFeesReversed'

			FROM #LateFees #lf	
			GROUP BY #lf.Property, #lf.ObjectID, #lf.PropertyID, #lf.ObjectType, #lf.Unit, #lf.PaddedUnit, #lf.Names, #lf.AccountingPeriodID
			
	SELECT #lf2r.Property,
			#lf2r.ObjectID,
			#lf2r.PropertyID,
			#lf2r.ObjectType,
			#lf2r.Unit,
			#lf2r.PaddedUnit,
			#lf2r.Names,
			(#lf2r.LateFeesCharged /*+ #lf2r.LateFeesReversed*/) AS 'LateFeesCharged',
			#lf2r.LateFeesReversed,
			#lf2r.NonCurrentPeriodLateFeesReversed,
		ISNULL((SELECT ISNULL(SUM(pay.Amount), 0)
			FROM Payment pay
				--INNER JOIN AccountingPeriod ap ON #lf2r.AccountingPeriodID = ap.AccountingPeriodID
				INNER JOIN PropertyAccountingPeriod pap ON #lf2r.PropertyID = pap.PropertyID AND #lf2r.AccountingPeriodID = pap.AccountingPeriodID
			WHERE pay.ObjectID = #lf2r.ObjectID AND pay.[Date] >= pap.StartDate AND pay.[Date] <= pap.EndDate AND pay.[Type] = 'Late Payment' AND pay.AccountID = @accountID
			GROUP BY pay.ObjectID), 0) AS 'ConcessionRevoked',
		null AS 'WaivedLateFeesNotes'
		FROM #LateFeesToReturn #lf2r
	UNION ALL
		SELECT p.Name, 
			ulg.UnitLeaseGroupID,
			p.PropertyID,
			'Lease',
			u.Number,
			u.PaddedNumber,
			STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 FOR XML PATH ('')), 1, 2, '') AS 'Names',
			0,
			0,
			0,
			0,
			pn.Note	AS 'WaivedLateFeesNotes'				 
		FROM PersonNote pn
			--INNER JOIN AccountingPeriod ap ON ap.AccountingPeriodID = @accountingPeriodID
			INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = pn.ObjectID
			INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN Property p ON ut.PropertyID = p.PropertyID
			INNER JOIN #LFSPropertyIDs pids ON pids.PropertyID = p.PropertyID
			INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE pn.InteractionType = 'Late Fee Waived'
		  AND pn.[Date]	>= pap.StartDate AND pn.[Date] <= pap.EndDate
		  AND pn.AccountID = @accountID
		  AND l.LeaseID = ((SELECT TOP 1 LeaseID
							FROM Lease 
							INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
							WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID									  
							ORDER BY o.OrderBy))

END



GO
