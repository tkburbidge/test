SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- NOTE: 3/15/2012 - EndingBalance was not being calculated correctly.
--		 It was not taking into account the beginning balance.  It was
--		 removed completly as the ending balance can easily be calcualted
--		 in the report using beginning balance, charges, and credits

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 7, 2012
-- Description:	Generates the data for the Transaction Balances Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_TransactionBalances_] 
	-- Add the parameters for the stored procedure here
	@startDate datetime = null,
	@endDate datetime = null,
	@objectTypes StringCollection READONLY, 
	@leaseStatuses StringCollection READONLY,
	@propertyIDs GuidCollection READONLY
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #TransactionBalance (
		PropertyName nvarchar(50) not null,
		PropertyID uniqueidentifier not null,
		ObjectID uniqueidentifier not null,
		ObjectType nvarchar(50) not null,
		LeaseID uniqueidentifier null,
		Unit nvarchar(50) null,
		PaddedNumber nvarchar(50) null,
		Names nvarchar(500) null,
		LeaseStatus nvarchar(50) null,
		BeginningBalance money null,
		Charges money null,
		Credits money null,
		--EndingBalance money null,
		LeaseStartDate datetime null,
		LeaseEndDate datetime null,
		MoveInDate datetime null,
		MoveOutDate datetime null)
		
	INSERT INTO #TransactionBalance
		SELECT DISTINCT
				p.Name AS 'PropertyName',
				p.PropertyID AS 'PropertyID',
				ulg.UnitLeaseGroupID AS 'ObjectID',
				'Lease' AS 'ObjectType',
				l.LeaseID AS 'LeaseID',
				u.Number AS 'Unit',
				u.PaddedNumber AS 'PaddedNumber',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 FOR XML PATH ('')), 1, 2, '') AS 'Names',	
				l.LeaseStatus AS 'LeaseStatus',
				ISNULL(BB.Balance, 0) AS 'BeginningBalance',
				null AS 'Charges',
				null AS 'Credits',
				--ISNULL(EB.Balance, 0) AS 'EndingBalance',
				l.LeaseStartDate AS 'LeaseStartDate',	
				l.LeaseEndDate AS 'LeaseEndDate',
				(SELECT MIN(pl.MoveInDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID) AS 'MoveInDate',
				(SELECT MIN(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID) AS 'MoveOutDate'		
			FROM UnitLeaseGroup ulg
				LEFT JOIN [Transaction] t ON t.ObjectID = ulg.UnitLeaseGroupID
				LEFT JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON b.PropertyID = p.PropertyID
				OUTER APPLY GetObjectBalance(null, DATEADD(day, -1, @startDate), l.UnitLeaseGroupID, 0, @propertyIDs) AS BB
				--OUTER APPLY GetObjectBalance(@startDate, @endDate, l.UnitLeaseGroupID, @propertyIDs) AS EB
			WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
			  AND l.LeaseStatus IN (SELECT Value FROM @leaseStatuses)
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
				null AS 'LeaseID',
				null AS 'Unit',
				null AS 'PaddedNumber',
				CASE
					WHEN pr.PersonID IS NOT NULL THEN pr.PreferredName + ' ' + pr.LastName
					WHEN woita.WOITAccountID IS NOT NULL THEN woita.Name
					END AS 'Names',
				null AS 'LeaseStatus',
				ISNULL(BB.Balance, 0) AS 'BeginningBalance',
				null AS 'Charges',
				null AS 'Credits',
				--ISNULL(EB.Balance, 0) AS 'EndingBalance',
				null AS 'LeaseStartDate',	
				null AS 'LeaseEndDate',
				null AS 'MoveInDate',
				null AS 'MoveOutDate'		
			FROM [Transaction] t 
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
				LEFT JOIN Person pr ON t.ObjectID = pr.PersonID
				LEFT JOIN WOITAccount woita ON t.ObjectID = woita.WOITAccountID
				OUTER APPLY GetObjectBalance(null, DATEADD(day, -1, @startDate), t.ObjectID, 0, @propertyIDs) AS BB
				--OUTER APPLY GetObjectBalance(@startDate, @endDate, t.ObjectID, @propertyIDs) AS EB
			WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
			  AND tt.[Group] IN ('Non-Resident Account', 'Prospect', 'WOIT Account')
			  AND tt.[Group] IN (SELECT Value FROM @objectTypes)
			  AND tt.Name IN ('Charge', 'Credit', 'Payment')	
			  --AND t.TransactionDate >= @startDate
			  --AND t.TransactionDate <= @endDate			    
			  
			
	UPDATE #TransactionBalance SET Charges = (SELECT ISNULL(SUM(ISNULL(t.Amount, 0)), 0)
		FROM [Transaction] t
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID
		WHERE t.ObjectID = #TransactionBalance.ObjectID
		  AND tt.Name IN ('Charge')
		  AND t.TransactionDate >= @startDate
		  AND t.TransactionDate <= @endDate
		  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))		
		    
	UPDATE #TransactionBalance SET Credits = (SELECT ISNULL(SUM(ISNULL(DistinctPayments.Amount, 0)), 0)
		FROM (SELECT DISTINCT p.PaymentID, p.Amount
				FROM Payment p
					INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
					INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID 			
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					LEFT JOIN PostingBatch pb ON p.PostingBatchID = pb.PostingBatchID
				WHERE t.ObjectID = #TransactionBalance.ObjectID
				  AND tt.Name IN ('Credit', 'Payment')
				  AND t.LedgerItemTypeID IS NOT NULL
				  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
				  AND p.[Date] >= @startDate
				  AND p.[Date] <= @endDate) DistinctPayments)	  
		
	UPDATE #TransactionBalance SET Credits = (ISNULL(Credits, 0) + (SELECT ISNULL(SUM(t.Amount), 0)
		FROM [Transaction] t
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID
		WHERE t.ObjectID = #TransactionBalance.ObjectID
		  AND tt.Name IN ('Deposit Applied to Balance', 'Balance Transfer Payment', 'Payment Refund')
		  AND t.TransactionDate >= @startDate
		  AND t.TransactionDate <= @endDate
		  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))))
		  		
	SELECT * FROM #TransactionBalance
		ORDER BY PropertyName, PaddedNumber, Names


END
GO
