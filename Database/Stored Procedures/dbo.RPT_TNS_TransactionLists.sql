SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 9, 2012
-- Description:	Generates the data for the TransactionSummary Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_TransactionLists] 
	-- Add the parameters for the stored procedure here
	@startDate datetime = null,
	@endDate datetime = null,
	@propertyIDs GuidCollection READONLY,
	@ledgerItemTypeNames StringCollection READONLY,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    
    CREATE TABLE #TransactionList (
		ID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		PropertyID uniqueidentifier not null,
		ObjectID uniqueidentifier not null,
		ObjectType nvarchar(50) null,
		Name nvarchar(200) null,
		Unit nvarchar(50) null,
		UnitID uniqueidentifier null,
		[Date] date null,
		TransactionTypeName nvarchar(50) null,
		[Description] nvarchar(500) null,
		LedgerItemTypeName nvarchar(50) not null,
		Notes nvarchar(200) null,
		Reference nvarchar(100) null,
		Amount money null,
		[Timestamp] datetime null,
		LedgerItemTypeID uniqueidentifier null)
		

	-- Add all the Ledger Item Types that will be returned into the temp table
	INSERT INTO #TransactionList
	SELECT DISTINCT
			py.PaymentID as ID,
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
				 FOR XML PATH ('')), 1, 2, '') AS 'Name',
			u.Number AS 'Unit',
			u.UnitID AS 'UnitID',
			py.[Date] AS 'Date',
			tt.Name AS 'TransactionTypeName',
			py.[Description] AS 'Description',
			CASE
				WHEN lit.LedgerItemTypeID IS NOT NULL THEN lit.Name
				ELSE tt.Name 
				END AS 'LedgerItemTypeName',
			py.Notes AS 'Notes',
			py.ReferenceNumber AS 'Reference',
			py.Amount AS 'Amount',
			py.TimeStamp AS 'Timestamp',
			lit.LedgerItemTypeID
		FROM Payment py
			INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN Property p ON t.PropertyID = p.PropertyID
			INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
			LEFT JOIN PostingBatch pb ON py.PostingBatchID = pb.PostingBatchID
			LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND tt.Name IN ('Payment', 'Credit', 'Deposit', 'Payment Refund', 'Deposit Refund')
		  AND tt.[Group] IN ('Lease')
		  --AND py.Date >= @startDate
		  --AND py.Date <= @endDate
		  AND (((@accountingPeriodID IS NULL) AND (py.[Date] >= @startDate) AND (py.[Date] <= @endDate))
		    OR ((@accountingPeriodID IS NOT NULL) AND (py.[Date] >= pap.StartDate) AND (py.[Date] <= pap.EndDate)))
		  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
		  -- When we do a balance transfer or a deposit application a Payment or Credit
		  -- is posted to be allocated to charges but no LedgerItemTypeID is specified
		  -- for that transaction.  Don't include those transactions with this condition
		  AND NOT (tt.Name IN ('Payment', 'Credit') AND t.LedgerItemTypeID IS NULL) 
		  AND t.ObjectID = py.ObjectID
		  AND l.LeaseID = ((SELECT TOP 1 LeaseID
							FROM Lease 
							INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
							WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID									  
							ORDER BY o.OrderBy))
		  AND ((lit.LedgerItemTypeID IS NULL) OR (0 = (SELECT COUNT(*) FROM @ledgerItemTypeNames)) OR (lit.Name IN (SELECT Value FROM @ledgerItemTypeNames)))
								 
	UNION
	
	SELECT DISTINCT
			t.TransactionID AS 'ID',
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
				 FOR XML PATH ('')), 1, 2, '') AS 'Name',
			u.Number AS 'Unit',
			u.UnitID AS 'UnitID',
			t.TransactionDate AS 'Date',
			tt.Name AS 'TransactionTypeName',			
			t.[Description] AS 'Description',
			CASE
				WHEN tt.Name IN ('Deposit Applied to Deposit', 'Balance Transfer Deposit') THEN tt.Name
				WHEN lit.LedgerItemTypeID IS NOT NULL THEN lit.Name
				ELSE tt.Name 
				END AS 'LedgerItemTypeName',
			t.Note AS 'Notes',
			null AS 'Reference',
			t.Amount AS 'Amount',
			t.TimeStamp AS 'Timestamp',
			lit.LedgerItemTypeID
		FROM [Transaction] t
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN Property p ON t.PropertyID = p.PropertyID
			INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
			LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID
			LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND tt.Name IN ('Charge', 'Deposit Applied to Balance', 'Deposit Applied to Deposit', 'Balance Transfer Payment', 'Balance Transfer Deposit')
		  AND tt.[Group] IN ('Lease')
		  --AND t.TransactionDate >= @startDate
		  --AND t.TransactionDate <= @endDate	
		  AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate >= @startDate) AND (t.TransactionDate <= @endDate))
		    OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate >= pap.StartDate) AND (t.TransactionDate <= pap.EndDate)))
		  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
		  -- Get the LedgerItemType.Name or the TransactionType.Name for the category
		  AND l.LeaseID = ((SELECT TOP 1 LeaseID
								FROM Lease 
								INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
								WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID									  
								ORDER BY o.OrderBy))	
		  AND ((lit.LedgerItemTypeID IS NULL) OR (0 = (SELECT COUNT(*) FROM @ledgerItemTypeNames)) OR (lit.Name IN (SELECT Value FROM @ledgerItemTypeNames)))						 			  		
		  
	UNION
	
	SELECT DISTINCT
			py.PaymentID AS 'ID',
			p.Name AS 'PropertyName',
			p.PropertyID AS 'PropertyID',
			t.ObjectID AS 'ObjectID',
			tt.[Group] AS 'ObjectType',
			CASE
				WHEN (pr.PersonID IS NOT NULL) THEN pr.FirstName + ' ' + pr.LastName 
				WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name
				WHEN (u.UnitID IS NOT NULL) THEN u.Number
				END AS 'Name',
			u.Number AS 'Unit',
			u.UnitID AS 'UnitID',
			py.[Date] AS 'Date',
			tt.Name AS 'TransactionTypeName',			
			py.[Description] AS 'Description',
			CASE
				WHEN lit.LedgerItemTypeID IS NOT NULL THEN lit.Name
				ELSE tt.Name 
				END AS 'LedgerItemTypeName',
			py.Notes AS 'Notes',
			py.ReferenceNumber AS 'Reference',
			py.Amount AS 'Amount',
			py.TimeStamp AS 'Timestamp',
			lit.LedgerItemTypeID
		FROM Payment py
			INNER JOIN PaymentTransaction pt ON py.PaymentID = pt.PaymentID
			INNER JOIN [Transaction] t ON pt.TransactionID = t.TransactionID
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN Property p ON t.PropertyID = p.PropertyID
			LEFT JOIN Person pr ON t.ObjectID = pr.PersonID
			LEFT JOIN WOITAccount woit ON t.ObjectID = woit.WOITAccountID
			LEFT JOIN Unit u ON t.ObjectID = u.UnitID
			LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
			LEFT JOIN PostingBatch pb ON py.PostingBatchID = pb.PostingBatchID
			LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND tt.Name IN ('Payment', 'Credit', 'Deposit', 'Payment Refund', 'Deposit Refund')
		  AND tt.[Group] IN ('Prospect', 'Non-Resident Account', 'WOIT Account', 'Unit')
		  --AND py.Date >= @startDate
		  --AND py.Date <= @endDate
		  AND (((@accountingPeriodID IS NULL) AND (py.[Date] >= @startDate) AND (py.[Date] <= @endDate))
		    OR ((@accountingPeriodID IS NOT NULL) AND (py.[Date] >= pap.StartDate) AND (py.[Date] <= pap.EndDate)))
		  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
		  -- When we do a balance transfer or a deposit application a Payment or Credit
		  -- is posted to be allocated to charges but no LedgerItemTypeID is specified
		  -- for that transaction.  Don't include those transactions with this condition
		  AND NOT (tt.Name IN ('Payment', 'Credit') AND t.LedgerItemTypeID IS NULL) 
		  AND ((lit.LedgerItemTypeID IS NULL) OR (0 = (SELECT COUNT(*) FROM @ledgerItemTypeNames)) OR (lit.Name IN (SELECT Value FROM @ledgerItemTypeNames)))

	
	UNION
			  
	SELECT DISTINCT
			t.TransactionID AS 'ID',
			p.Name AS 'PropertyName',
			p.PropertyID AS 'PropertyID',
			t.ObjectID AS 'ObjectID',
			tt.[Group] AS 'ObjectType',
			CASE
				WHEN (pr.PersonID IS NOT NULL) THEN pr.FirstName + ' ' + pr.LastName 
				WHEN (woit.WOITAccountID IS NOT NULL) THEN woit.Name
				WHEN (u.UnitID IS NOT NULL) THEN u.Number
				END AS 'Name',
			u.Number AS 'Unit',
			u.UnitID AS 'UnitID',
			t.TransactionDate AS 'Date',
			tt.Name AS 'TransactionTypeName',			
			t.[Description] AS 'Description',
			CASE
				WHEN tt.Name IN ('Deposit Applied to Deposit', 'Balance Transfer Deposit') THEN tt.Name
				WHEN lit.LedgerItemTypeID IS NOT NULL THEN lit.Name
				ELSE tt.Name 
				END AS 'LedgerItemTypeName',
			t.Note AS 'Notes',
			null AS 'Reference',
			t.Amount AS 'Amount',
			t.TimeStamp AS 'Timestamp',
			lit.LedgerItemTypeID
		FROM [Transaction] t
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN Property p ON t.PropertyID = p.PropertyID
			LEFT JOIN Person pr ON t.ObjectID = pr.PersonID
			LEFT JOIN WOITAccount woit ON t.ObjectID = woit.WOITAccountID
			LEFT JOIN Unit u ON t.ObjectID = u.UnitID
			LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
			LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID
			LEFT JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND tt.Name IN ('Charge', 'Deposit Applied to Balance', 'Deposit Applied to Deposit', 'Balance Transfer Payment', 'Balance Transfer Deposit')
		  AND tt.[Group] IN ('Prospect', 'Non-Resident Account', 'WOIT Account', 'Unit')
		  --AND t.TransactionDate >= @startDate
		  --AND t.TransactionDate <= @endDate	
		  AND (((@accountingPeriodID IS NULL) AND (t.TransactionDate >= @startDate) AND (t.TransactionDate <= @endDate))
		    OR ((@accountingPeriodID IS NOT NULL) AND (t.TransactionDate >= pap.StartDate) AND (t.TransactionDate <= pap.EndDate)))
		  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
		  AND ((lit.LedgerItemTypeID IS NULL) OR (0 = (SELECT COUNT(*) FROM @ledgerItemTypeNames)) OR (lit.Name IN (SELECT Value FROM @ledgerItemTypeNames)))
	  
	SELECT * FROM #TransactionList ORDER BY TransactionTypeName, LedgerItemTypeName, Date, Timestamp

END


GO
