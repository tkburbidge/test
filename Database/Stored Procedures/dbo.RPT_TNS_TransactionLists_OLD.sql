SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 9, 2012
-- Description:	Generates the data for the Transaction List report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_TransactionLists_OLD]
	-- Add the parameters for the stored procedure here
	@startDate datetime = null,
	@endDate datetime = null,
	@propertyIDs GuidCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	(SELECT DISTINCT 
			p.Name AS 'PropertyName', 
			p.PropertyID AS 'PropertyID',
			l.LeaseID AS 'ObjectID',
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
			(CASE
				WHEN py.PaymentID IS NOT NULL THEN py.[Date]
				ELSE t.TransactionDate END) AS 'Date',
			CASE
				WHEN tt.Name IN ('Balance Transfer Payment', 'Deposit Applied to Balance', 'Payment Refund') THEN 'Payment'
				WHEN tt.Name IN ('Balance Transfer Deposit', 'Deposit Applied to Deposit', 'Deposit Refund') THEN 'Deposit'
				ELSE tt.Name END AS 'TransactionTypeName',
			py.[Description] AS 'Description',
			CASE
				WHEN lit.LedgerItemTypeID IS NOT NULL THEN lit.Name
				ELSE tt.Name 
				END AS 'LedgerItemTypeName',
			CASE
				WHEN py.PaymentID IS NOT NULL THEN py.Notes
				ELSE t.Note
				END AS 'Notes',
			CASE 
				WHEN py.PaymentID IS NOT NULL THEN py.ReferenceNumber
				ELSE null
				END AS 'Reference',
			py.Amount AS 'Amount',
			py.TimeStamp AS 'Timestamp'			
		FROM [Transaction] t
			LEFT JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name NOT IN ('Prepayment', 'Charge', 'Over Credit')
			INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Property p ON t.PropertyID = p.PropertyID
			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
			INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
			INNER JOIN Payment py ON py.PaymentID = pt.PaymentID
			LEFT JOIN PaymentTransaction ptPayDep ON py.PaymentID = ptPayDep.PaymentID
			LEFT JOIN [Transaction] PayDepT ON ptPayDep.TransactionID = PayDepT.TransactionID AND PayDepT.TransactionID <> t.TransactionID
			LEFT JOIN TransactionType PayDepTT ON PayDepT.TransactionTypeID = PayDepTT.TransactionTypeID AND PayDepTT.Name IN ('Deposit') AND tt.Name IN ('Payment')
		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
		  AND py.[Date] >= @startDate
		  AND py.[Date] <= @endDate
		  AND tt.[Group] = 'Lease'
		  AND t.Amount > 0
		  AND PayDepT.TransactionID IS NULL
		  AND l.LeaseID = (SELECT LeaseID 
						   FROM Lease
						   WHERE LeaseID = l.LeaseID
							 AND LeaseEndDate = (SELECT TOP 1 LeaseEndDate 
												 FROM Lease
												 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
												 ORDER BY LeaseEndDate DESC))		
												 
	--UNION
	
	--	SELECT DISTINCT 
	--			p.Name AS 'PropertyName', 
	--			p.PropertyID AS 'PropertyID',
	--			l.LeaseID AS 'ObjectID',
	--			tt.[Group] AS 'ObjectType',
	--			STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
	--				 FROM Person 
	--					 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
	--					 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
	--					 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
	--				 WHERE PersonLease.LeaseID = l.LeaseID
	--					   AND PersonType.[Type] = 'Resident'				   
	--					   AND PersonLease.MainContact = 1				   
	--				 FOR XML PATH ('')), 1, 2, '') AS 'Name',
	--			u.Number AS 'Unit',
	--			t.TransactionDate AS 'Date',
	--			CASE
	--				WHEN tt.Name IN ('Balance Transfer Payment', 'Deposit Applied to Balance') THEN 'Payment'
	--				WHEN tt.Name IN ('Balance Transfer Deposit', 'Deposit Applied to Deposit') THEN 'Deposit'
	--				ELSE tt.Name END AS 'TransactionTypeName',
	--			t.[Description] AS 'Description',
	--			CASE
	--				WHEN lit.LedgerItemTypeID IS NOT NULL THEN lit.Name
	--				ELSE tt.Name 
	--				END AS 'LedgerItemTypeName',
	--			t.Note AS 'Notes',
	--			null AS 'Reference',
	--			t.Amount AS 'Amount',
	--			t.TimeStamp AS 'Timestamp'
	--		FROM [Transaction] t
	--			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Charge') AND tt.[Group] IN ('Lease')
	--			INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
	--			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
	--			INNER JOIN Property p ON t.PropertyID = p.PropertyID
	--			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--			LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
	--			--LEFT JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
	--			--LEFT JOIN Payment py ON py.PaymentID = pt.PaymentID
	--		WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
	--		  AND t.TransactionDate >= @startDate
	--		  AND t.TransactionDate <= @endDate
	--		  AND t.Amount > 0
	--		  AND l.LeaseID = (SELECT LeaseID 
	--						   FROM Lease
	--						   WHERE LeaseID = l.LeaseID
	--							 AND LeaseEndDate = (SELECT TOP 1 LeaseEndDate 
	--												 FROM Lease
	--												 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--												 ORDER BY LeaseEndDate DESC))
													 		
	--UNION
		
	--	SELECT DISTINCT 
	--		p.Name AS 'PropertyName', 
	--		p.PropertyID AS 'PropertyID',
	--		t.ObjectID AS 'ObjectID',
	--		tt.[Group] AS 'ObjectType',
	--		pr.PreferredName + ' ' + pr.LastName AS 'Name',
	--		null AS 'Unit',
	--		(CASE
	--			WHEN py.PaymentID IS NOT NULL THEN py.[Date]
	--			ELSE t.TransactionDate END) AS 'Date',
	--		CASE
	--			WHEN tt.Name IN ('Balance Transfer Payment', 'Deposit Applied to Balance') THEN 'Payment'
	--			WHEN tt.Name IN ('Balance Transfer Deposit', 'Deposit Applied to Deposit') THEN 'Deposit'
	--			ELSE tt.Name END AS 'TransactionTypeName',
	--		t.[Description] AS 'Description',
	--		CASE
	--			WHEN lit.LedgerItemTypeID IS NOT NULL THEN lit.Name
	--			ELSE tt.Name 
	--			END AS 'LedgerItemTypeName',
	--		CASE
	--			WHEN py.PaymentID IS NOT NULL THEN py.Notes
	--			ELSE t.Note
	--			END AS 'Notes',
	--		CASE 
	--			WHEN py.PaymentID IS NOT NULL THEN py.ReferenceNumber
	--			ELSE null
	--			END AS 'Reference',
	--		t.Amount AS 'Amount',
	--		t.TimeStamp AS 'Timestamp'
	--	FROM [Transaction] t
	--		INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
	--		INNER JOIN Property p ON t.PropertyID = p.PropertyID
	--		INNER JOIN Person pr ON t.ObjectID = pr.PersonID
	--		LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
	--		LEFT JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
	--		LEFT JOIN Payment py ON py.PaymentID = pt.PaymentID
	--	WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
	--	  AND (((py.PaymentID IS NOT NULL) AND (py.[Date] >= @startDate)) OR t.TransactionDate >= @startDate)
	--	  AND (((py.PaymentID IS NOT NULL) AND (py.[Date] >= @endDate)) OR t.TransactionDate <= @endDate)
	--	  AND tt.[Group] NOT IN ('Lease', 'Invoice')
	--	  AND tt.Name NOT IN ('Prepayment', 'Over Credit')
	--	  AND t.Amount > 0
	) ORDER BY 'TransactionTypeName', 'LedgerItemTypeName', 'Date', 'Timestamp'
			  
	
END
GO
