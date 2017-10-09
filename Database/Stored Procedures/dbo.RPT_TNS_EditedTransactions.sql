SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: June 24, 2013
-- Description:	Generates the data for the EditedTransaction report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_EditedTransactions]
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY,
	@startDate date = null,
	@endDate date = null,
	@origins StringCollection READONLY,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier
	)

	INSERT INTO #PropertyIDs SELECT Value FROM @propertyIDs

	SELECT * FROM (
		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				pay.PaymentID AS 'OriginalID',
				pay.[Date] AS 'Date',
				pay.ReferenceNumber AS 'Reference',
				p.PropertyID AS 'PropertyID',
				t.ObjectID AS 'ObjectID',
				tt.[Group] AS 'ObjectType',
				u.Number AS 'Unit',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'
						   AND PersonLease.MainContact = 1
					 ORDER BY PersonLease.OrderBy, Person.PersonID
					 FOR XML PATH ('')), 1, 2, '') AS 'Name',
				tt.Name AS 'TransactionTypeName',
				pay.[Description] AS 'Description',
				CASE
					WHEN (lit.LedgerItemTypeID IS NOT NULL) THEN lit.Name
					ELSE tt.Name END AS 'LedgerItemTypeName',
				pay.Amount AS 'Amount',
				pay.ReversedReason AS 'ReasonForReversal',
				payR.PaymentID AS 'ReversalID',
				payR.[Date] AS 'ReversalDate',
				payNew.PaymentID AS 'EditedID',
				payNew.[Date] AS 'EditDate',
				payNew.Amount AS 'NewAmount',
				perR.PreferredName + ' ' + perR.LastName AS 'EditingUser',
				payR.Notes AS 'ReversalNotes',
				CAST(0 AS BIT) AS 'IsHapLedger'
			FROM PartialTransactionEdit pte
				INNER JOIN Payment pay ON pte.IsPayment = 1 AND pte.OriginalID = pay.PaymentID
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Payment', 'Deposit', 'Credit')
				INNER JOIN Property p ON t.PropertyID = p.PropertyID AND p.PropertyID IN (SELECT Value FROM @propertyIDs)
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
									AND l.LeaseID = (SELECT TOP 1 Lease.LeaseID
													FROM Lease
													INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
													WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID
													ORDER BY Ordering.OrderBy)
				INNER JOIN Payment payR ON pte.ReversesID = payR.PaymentID
				INNER JOIN PaymentTransaction ptR ON payR.PaymentID = ptR.PaymentID
				INNER JOIN [Transaction] tR ON ptR.TransactionID = tR.TransactionID
				INNER JOIN Person perR ON tR.PersonID = perR.PersonID
				LEFT JOIN Payment payNew ON pte.EditedID = payNew.PaymentID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE pay.ReversedReason NOT IN ('Non-Sufficient Funds', 'NSF', 'Credit Card Recapture')
			  --AND (((SELECT COUNT(*) FROM @origins) = 0) OR t.Origin IN (SELECT Value FROM @origins))
			  --AND payR.[Date] >= @startDate
			  --AND payR.[Date] <= @endDate
			  AND (((@accountingPeriodID IS NULL) AND (payR.[Date] >= @startDate) AND (payR.[Date] <= @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (payR.[Date] >= pap.StartDate) AND (payR.[Date] <= pap.EndDate)))

		UNION ALL

		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				t.TransactionID AS 'OriginalID',
				t.TransactionDate AS 'Date',
				null AS 'Reference',
				p.PropertyID AS 'PropertyID',
				t.ObjectID AS 'ObjectID',
				tt.[Group] AS 'ObjectType',
				u.Number AS 'Unit',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'
						   AND PersonLease.MainContact = 1
					 ORDER BY PersonLease.OrderBy, Person.PersonID
					 FOR XML PATH ('')), 1, 2, '') AS 'Name',
				tt.Name AS 'TransactionTypeName',
				t.[Description] AS 'Description',
				CASE
					WHEN (lit.LedgerItemTypeID IS NOT NULL) THEN lit.Name
					ELSE tt.Name END AS 'LedgerItemTypeName',
				t.Amount AS 'Amount',
				null AS 'ReasonForReversal',
				tR.TransactionID AS 'ReversalID',
				tR.TransactionDate AS 'ReversalDate',
				tNew.TransactionID AS 'EditedID',
				tNew.TransactionDate AS 'EditDate',
				tNew.Amount AS 'NewAmount',
				perR.PreferredName + ' ' + perR.LastName AS 'EditingUser',
				tR.Note AS 'ReversalNotes',
				CAST(0 AS BIT) AS 'IsHapLedger'
			FROM PartialTransactionEdit pte
				INNER JOIN [Transaction] t ON pte.IsPayment = 0 AND pte.OriginalID = t.TransactionID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN [Transaction] tR ON pte.ReversesID = tR.TransactionID
				INNER JOIN Person perR ON tR.PersonID = perR.PersonID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID AND p.PropertyID IN (SELECT Value FROM @propertyIDs)
				INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				LEFT JOIN [Transaction] tNew ON pte.EditedID = tNew.TransactionID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE (((@accountingPeriodID IS NULL) AND (tR.TransactionDate >= @startDate) AND (tR.TransactionDate <= @endDate))

			    OR ((@accountingPeriodID IS NOT NULL) AND (tR.TransactionDate >= pap.StartDate) AND (tR.TransactionDate <= pap.EndDate)))
			  --AND (((SELECT COUNT(*) FROM @origins) = 0) OR t.Origin IN (SELECT Value FROM @origins))

		UNION ALL

		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				pay.PaymentID AS 'OriginalID',
				pay.[Date] AS 'Date',
				pay.ReferenceNumber AS 'Reference',
				p.PropertyID AS 'PropertyID',
				t.ObjectID AS 'ObjectID',
				tt.[Group] AS 'ObjectType',
				null AS 'Unit',
				CASE
					WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name
					ELSE per.PreferredName + ' ' + per.LastName END AS 'Name',
				tt.Name AS 'TransactionTypeName',
				pay.[Description] AS 'Description',
				CASE
					WHEN (lit.LedgerItemTypeID IS NOT NULL) THEN lit.Name
					ELSE tt.Name END AS 'LedgerItemTypeName',
				pay.Amount AS 'Amount',
				pay.ReversedReason AS 'ReasonForReversal',
				payR.PaymentID AS 'ReversalID',
				payR.[Date] AS 'ReversalDate',
				payNew.PaymentID AS 'EditedID',
				payNew.[Date] AS 'EditDate',
				payNew.Amount AS 'NewAmount',
				perR.PreferredName + ' ' + perR.LastName AS 'EditingUser',
				payR.Notes AS 'ReversalNotes',
				CAST(CASE
					WHEN (woit.WoitAccountID IS NOT NULL AND woit.BillingAccountID IS NOT NULL) THEN 1
					ELSE 0
				END AS BIT) AS 'IsHapLedger'
			FROM PartialTransactionEdit pte
				INNER JOIN Payment pay ON pte.IsPayment = 1 AND pte.OriginalID = pay.PaymentID
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID
				INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Payment', 'Deposit', 'Credit') AND tt.[Group] IN ('Prospect', 'Non-Resident Account', 'WOIT Account')
				INNER JOIN Property p ON t.PropertyID = p.PropertyID AND p.PropertyID IN (SELECT Value FROM @propertyIDs)
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				LEFT JOIN Person per ON t.ObjectID = per.PersonID
				LEFT JOIN WOITAccount woit ON t.ObjectID = woit.WOITAccountID
				INNER JOIN Payment payR ON pte.ReversesID = payR.PaymentID
				INNER JOIN PaymentTransaction ptR ON payR.PaymentID = ptR.PaymentID
				INNER JOIN [Transaction] tR ON ptR.TransactionID = tR.TransactionID
				INNER JOIN Person perR ON tR.PersonID = perR.PersonID
				LEFT JOIN Payment payNew ON pte.EditedID = payNew.PaymentID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE pay.ReversedReason NOT IN ('Non-Sufficient Funds', 'NSF', 'Credit Card Recapture')
			  --AND (((SELECT COUNT(*) FROM @origins) = 0) OR t.Origin IN (SELECT Value FROM @origins))
			  --AND payR.[Date] >= @startDate
			  --AND payR.[Date] <= @endDate
			  AND (((@accountingPeriodID IS NULL) AND (payR.[Date] >= @startDate) AND (payR.[Date] <= @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (payR.[Date] >= pap.StartDate) AND (payR.[Date] <= pap.EndDate)))

		UNION ALL

		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				t.TransactionID AS 'OriginalID',
				t.TransactionDate AS 'Date',
				null AS 'Reference',
				p.PropertyID AS 'PropertyID',
				t.ObjectID AS 'ObjectID',
				tt.[Group] AS 'ObjectType',
				null AS 'Unit',
				CASE
					WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name
					ELSE per.PreferredName + ' ' + per.LastName END AS 'Name',
				tt.Name AS 'TransactionTypeName',
				t.[Description] AS 'Description',
				CASE
					WHEN (lit.LedgerItemTypeID IS NOT NULL) THEN lit.Name
					ELSE tt.Name END AS 'LedgerItemTypeName',
				t.Amount AS 'Amount',
				null AS 'ReasonForReversal',
				tR.TransactionID AS 'ReversalID',
				tR.TransactionDate AS 'ReversalDate',
				tNew.TransactionID AS 'EditedID',
				tNew.TransactionDate AS 'EditDate',
				tNew.Amount AS 'NewAmount',
				perR.PreferredName + ' ' + perR.LastName AS 'EditingUser',
				tR.Note AS 'ReversalNotes',
				CAST(CASE
					WHEN (woit.WoitAccountID IS NOT NULL AND woit.BillingAccountID IS NOT NULL) THEN 1
					ELSE 0
				END AS BIT) AS 'IsHapLedger'
			FROM PartialTransactionEdit pte
				INNER JOIN [Transaction] t ON pte.IsPayment = 0 AND pte.OriginalID = t.TransactionID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] IN ('Prospect', 'Non-Resident Account', 'WOIT Account')
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN [Transaction] tR ON pte.ReversesID = tR.TransactionID
				INNER JOIN Person perR ON tR.PersonID = perR.PersonID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID AND p.PropertyID IN (SELECT Value FROM @propertyIDs)
				LEFT JOIN Person per ON t.ObjectID = per.PersonID
				LEFT JOIN WOITAccount woit ON t.ObjectID = woit.WOITAccountID
				LEFT JOIN [Transaction] tNew ON pte.EditedID = tNew.TransactionID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE --tR.TransactionDate >= @startDate
			--  AND tR.TransactionDate <= @endDate
				(((@accountingPeriodID IS NULL) AND (tR.TransactionDate >= @startDate) AND (tR.TransactionDate <= @endDate))
					OR ((@accountingPeriodID IS NOT NULL) AND (tR.TransactionDate >= pap.StartDate) AND (tR.TransactionDate <= pap.EndDate)))
			  --AND (((SELECT COUNT(*) FROM @origins) = 0) OR t.Origin IN (SELECT Value FROM @origins))

		UNION ALL

		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				pay.PaymentID AS 'OriginalID',
				pay.[Date] AS 'Date',
				pay.ReferenceNumber AS 'Reference',
				p.PropertyID AS 'PropertyID',
				t.ObjectID AS 'ObjectID',
				tt.[Group] AS 'ObjectType',
				u.Number AS 'Unit',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'
						   AND PersonLease.MainContact = 1
					 ORDER BY PersonLease.OrderBy, Person.PersonID
					 FOR XML PATH ('')), 1, 2, '') AS 'Name',
				tt.Name AS 'TransactionTypeName',
				pay.[Description] AS 'Description',
				CASE
					WHEN (lit.LedgerItemTypeID IS NOT NULL) THEN lit.Name
					ELSE tt.Name END AS 'LedgerItemTypeName',
				pay.Amount AS 'Amount',
				null AS 'ReasonForReversal',
				payr.PaymentID AS 'RevesredID',
				payr.[Date] AS 'ReversalDate',
				null AS 'EditedID',
				null AS 'EditDate',
				null AS 'NewAmount',
				perR.PreferredName + ' ' + perR.LastName AS 'EditingUser',
				payr.Notes AS 'ReversalNotes',
				CAST(0 AS BIT) AS 'IsHapLedger'
			FROM [Transaction] t
				INNER JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Payment', 'Deposit', 'Credit')
				INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
				INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID AND pay.Reversed = 1
				INNER JOIN PaymentTransaction ptr ON tr.TransactionID = ptr.TransactionID
				INNER JOIN Payment payr ON ptr.PaymentID = payr.PaymentID AND payr.Amount < 0  -- Make sure we get the payment that reversed the original payment
				INNER JOIN Person perR ON tr.PersonID = perR.PersonID
				INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
									AND l.LeaseID = (SELECT TOP 1 Lease.LeaseID
													FROM Lease
													INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
													WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID
													ORDER BY Ordering.OrderBy)
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE --payr.[Date] >= @startDate
			--  AND payr.[Date] <= @endDate
				  pay.PaymentID NOT IN (SELECT OriginalID FROM PartialTransactionEdit)
					AND (((@accountingPeriodID IS NULL) AND (payR.[Date] >= @startDate) AND (payR.[Date] <= @endDate))
					  OR ((@accountingPeriodID IS NOT NULL) AND (payR.[Date] >= pap.StartDate) AND (payR.[Date] <= pap.EndDate)))
			  --AND (((SELECT COUNT(*) FROM @origins) = 0) OR t.Origin IN (SELECT Value FROM @origins))

		UNION ALL

		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				pay.PaymentID AS 'OriginalID',
				pay.[Date] AS 'Date',
				pay.ReferenceNumber AS 'Reference',
				p.PropertyID AS 'PropertyID',
				t.ObjectID AS 'ObjectID',
				tt.[Group] AS 'ObjectType',
				null AS 'Unit',
				CASE
					WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name
					ELSE per.PreferredName + ' ' + per.LastName END AS 'Name',
				tt.Name AS 'TransactionTypeName',
				pay.[Description] AS 'Description',
				CASE
					WHEN (lit.LedgerItemTypeID IS NOT NULL) THEN lit.Name
					ELSE tt.Name END AS 'LedgerItemTypeName',
				pay.Amount AS 'Amount',
				null AS 'ReasonForReversal',
				payr.PaymentID AS 'ReversalID',
				payr.[Date] AS 'ReversalDate',
				null AS 'EditedID',
				null AS 'EditDate',
				null AS 'NewAmount',
				perR.PreferredName + ' ' + perR.LastName AS 'EditingUser',
				payr.Notes AS 'ReversalNotes',
				CAST(CASE
					WHEN (woit.WoitAccountID IS NOT NULL AND woit.BillingAccountID IS NOT NULL) THEN 1
					ELSE 0
				END AS BIT) AS 'IsHapLedger'
			FROM [Transaction] t
				INNER JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Payment', 'Deposit', 'Credit') AND tt.[Group] IN ('Prospect', 'Non-Resident Account', 'WOIT Account')
				INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
				INNER JOIN Payment pay ON pt.PaymentID = pay.PaymentID AND pay.Reversed = 1
				INNER JOIN PaymentTransaction ptr ON tr.TransactionID = ptr.TransactionID
				INNER JOIN Payment payr ON ptr.PaymentID = payr.PaymentID  AND payr.Amount < 0  -- Make sure we get the payment that reversed the original payment
				INNER JOIN Person perR ON tr.PersonID = perR.PersonID
				LEFT JOIN Person per ON t.ObjectID = per.PersonID
				LEFT JOIN WOITAccount woit ON t.ObjectID = woit.WOITAccountID
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			--WHERE payr.[Date] >= @startDate
			--  AND payr.[Date] <= @endDate
			WHERE (((@accountingPeriodID IS NULL) AND (payR.[Date] >= @startDate) AND (payR.[Date] <= @endDate))
			    OR ((@accountingPeriodID IS NOT NULL) AND (payR.[Date] >= pap.StartDate) AND (payR.[Date] <= pap.EndDate)))
			  AND pay.PaymentID NOT IN (SELECT OriginalID FROM PartialTransactionEdit)
			  --AND (((SELECT COUNT(*) FROM @origins) = 0) OR t.Origin IN (SELECT Value FROM @origins))

		UNION ALL

		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				t.TransactionID AS 'OriginalID',
				t.[TransactionDate] AS 'Date',
				null AS 'Reference',
				p.PropertyID AS 'PropertyID',
				t.ObjectID AS 'ObjectID',
				tt.[Group] AS 'ObjectType',
				u.Number AS 'Unit',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'
						   AND PersonLease.MainContact = 1
					 ORDER BY PersonLease.OrderBy, Person.PersonID
					 FOR XML PATH ('')), 1, 2, '') AS 'Name',
				tt.Name AS 'TransactionTypeName',
				t.[Description] AS 'Description',
				CASE
					WHEN (lit.LedgerItemTypeID IS NOT NULL) THEN lit.Name
					ELSE tt.Name END AS 'LedgerItemTypeName',
				t.Amount AS 'Amount',
				null AS 'ReasonForReversal',
				tr.TransactionID AS 'ReversalID',
				tr.[TransactionDate] AS 'ReversalDate',
				null AS 'EditedID',
				null AS 'EditDate',
				null AS 'NewAmount',
				perR.PreferredName + ' ' + perR.LastName AS 'EditingUser',
				tr.Note AS 'ReversalNotes',
				CAST(0 AS BIT) AS 'IsHapLedger'
			FROM [Transaction] t
				INNER JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Charge') AND tt.[Group] IN ('Lease')
				INNER JOIN Person perR ON tr.PersonID = perR.PersonID
				INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
									AND l.LeaseID = (SELECT TOP 1 Lease.LeaseID
													FROM Lease
													INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
													WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID
													ORDER BY Ordering.OrderBy)
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE (((@accountingPeriodID IS NULL) AND (tr.TransactionDate >= @startDate) AND (tr.TransactionDate <= @endDate))

				OR ((@accountingPeriodID IS NOT NULL) AND (tr.TransactionDate >= pap.StartDate) AND (tr.TransactionDate <= pap.EndDate)))
			  AND t.TransactionID NOT IN (SELECT OriginalID FROM PartialTransactionEdit)
			  --AND (((SELECT COUNT(*) FROM @origins) = 0) OR t.Origin IN (SELECT Value FROM @origins))




		UNION ALL

		SELECT	DISTINCT
				p.Name AS 'PropertyName',
				t.TransactionID AS 'OriginalID',
				t.[TransactionDate] AS 'Date',
				null AS 'Reference',
				p.PropertyID AS 'PropertyID',
				t.ObjectID AS 'ObjectID',
				tt.[Group] AS 'ObjectType',
				null AS 'Unit',
				CASE
					WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name
					ELSE per.PreferredName + ' ' + per.LastName END AS 'Name',
				tt.Name AS 'TransactionTypeName',
				t.[Description] AS 'Description',
				CASE
					WHEN (lit.LedgerItemTypeID IS NOT NULL) THEN lit.Name
					ELSE tt.Name END AS 'LedgerItemTypeName',
				t.Amount AS 'Amount',
				null AS 'ReasonForReversal',
				tr.TransactionID AS 'ReversedID',
				tr.[TransactionDate] AS 'ReversalDate',
				null AS 'EditedID',
				null AS 'EditDate',
				null AS 'NewAmount',
				perR.PreferredName + ' ' + perR.LastName AS 'EditingUser',
				tr.Note AS 'ReversalNotes',
				CAST(CASE
					WHEN (woit.WoitAccountID IS NOT NULL AND woit.BillingAccountID IS NOT NULL) THEN 1
					ELSE 0
				END AS BIT) AS 'IsHapLedger'
			FROM [Transaction] t
				INNER JOIN [Transaction] tr ON t.TransactionID = tr.ReversesTransactionID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Charge') AND tt.[Group] IN ('Prospect', 'Non-Resident Account', 'WOIT Account')
				INNER JOIN Person perR ON tr.PersonID = perR.PersonID
				LEFT JOIN Person per ON t.ObjectID = per.PersonID
				LEFT JOIN WOITAccount woit ON t.ObjectID = woit.WOITAccountID
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = t.PropertyID
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			WHERE (((@accountingPeriodID IS NULL) AND (tr.TransactionDate >= @startDate) AND (tr.TransactionDate <= @endDate))

			    OR ((@accountingPeriodID IS NOT NULL) AND (tr.TransactionDate >= pap.StartDate) AND (tr.TransactionDate <= pap.EndDate)))
			  AND t.TransactionID NOT IN (SELECT OriginalID FROM PartialTransactionEdit)
			  --AND (((SELECT COUNT(*) FROM @origins) = 0) OR t.Origin IN (SELECT Value FROM @origins))
	) Transactions
	ORDER BY ReversalDate


END
GO
