SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[GetListTransactions]
	-- Add the parameters for the stored procedure here
	@propertyID uniqueidentifier,
	@types StringCollection READONLY,
	@page int,
	@pageSize int,
	@startDate datetime = null,
	@endDate datetime = null,
	@batch int = null,
	@totalCount int OUTPUT,
	@sortBy nvarchar(50) = null,
	@sortOrderIsAsc bit = null,
	@amount money = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	
	CREATE TABLE #TempTransactions 
	(
		LITID uniqueidentifier NULL,
		ID uniqueidentifier NOT NULL,
		ObjectID uniqueidentifier NULL,
		ObjectType nvarchar(50) NOT NULL,
		Name nvarchar(500) NULL,
		Unit nvarchar(25) NULL,
		[Date] date NULL,
		TransactionTypeName nvarchar(20) NOT NULL,
		[Description] nvarchar(200) NULL,
		LedgerItemTypeName nvarchar(100) NULL,
		Reference nvarchar(50) NULL,
		Amount money NOT NULL,
		[Timestamp] datetime NOT NULL,
		PaddedNumber nvarchar(20) NULL	
	)
	
	CREATE TABLE #TempTransactions1A
	(
		ID uniqueidentifier NOT NULL,
		ObjectID uniqueidentifier NOT NULL,
		ObjectType nvarchar(50) NOT NULL,
		Name nvarchar(500) NULL,
		Unit nvarchar(25) NULL,
		[Date] date NULL,
		TransactionTypeName nvarchar(20) NOT NULL,
		[Description] nvarchar(200) NULL,
		LedgerItemTypeName nvarchar(100) NOT NULL,
		Reference nvarchar(50) NULL,
		Amount money NOT NULL,
		[Timestamp] datetime NOT NULL,
		PaddedNumber nvarchar(20) NULL		
	)	

	IF (EXISTS (SELECT * FROM @types WHERE Value IN ('Payment', 'Deposit', 'Credit')))
	BEGIN
		INSERT INTO #TempTransactions 
		SELECT DISTINCT
				t.LedgerItemTypeID AS 'LITID',
				py.PaymentID AS 'ID', 						
				--l.LeaseID AS 'ObjectID',
				t.ObjectID AS 'ObjectID',
				tt.[Group] AS 'ObjectType',
				--STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
				--	 FROM Person 
				--		 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
				--		 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
				--		 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
				--	 WHERE PersonLease.LeaseID = l.LeaseID
				--		   AND PersonType.[Type] = 'Resident'				   
				--		   AND PersonLease.MainContact = 1				   
				--	 FOR XML PATH ('')), 1, 2, '') AS 'Name',
				null AS 'Name',
				--u.Number AS 'Unit',
				null AS 'Unit',
				(CASE
					WHEN py.PaymentID IS NOT NULL THEN py.[Date]
					ELSE t.TransactionDate END) AS 'Date',
				CASE
					WHEN tt.Name IN ('Balance Transfer Payment', 'Deposit Applied to Balance') THEN 'Payment'
					WHEN tt.Name IN ('Balance Transfer Deposit', 'Deposit Applied to Deposit') THEN 'Deposit'
					ELSE tt.Name END AS 'TransactionTypeName',
				py.[Description] AS 'Description',
				--CASE
				--	WHEN lit.LedgerItemTypeID IS NOT NULL THEN lit.Name
				--	ELSE tt.Name 
				--	END AS 'LedgerItemTypeName',
				tt.Name AS 'LedgerItemTypeID',			
				CASE 
					WHEN py.PaymentID IS NOT NULL THEN py.ReferenceNumber
					ELSE null
					END AS 'Reference',
				py.Amount AS 'Amount',
				py.TimeStamp AS 'Timestamp',
				--u.PaddedNumber	
				null AS 'PaddedNumber'		
			FROM [Transaction] t
				LEFT JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
				LEFT JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name NOT IN ('Prepayment', 'Charge', 'Over Credit', 'Tax Credit')
				--INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
				--INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				--INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				--LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
				INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
				INNER JOIN Payment py ON py.PaymentID = pt.PaymentID
				LEFT JOIN Batch b ON b.BatchID = py.BatchID
				LEFT JOIN PostingBatch pb ON pb.PostingBatchID = py.PostingBatchID				
			WHERE t.PropertyID = @propertyID
			  AND py.[Date] >= @startDate
			  AND py.[Date] <= @endDate
			  AND tt.[Group] = 'Lease'			  
			  AND tt.Name IN (SELECT * FROM @types)
			  --AND t.Amount > 0
			  AND (ta.TransactionID IS NULL OR tta.Name IN ('Tax Credit', 'Tax Payment'))
			  AND ((@batch IS NULL) OR (b.Number = @batch))
			  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
			  --AND l.LeaseID = ((SELECT TOP 1 LeaseID
					--				 FROM Lease
					--				 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
					--				   AND (((SELECT COUNT(*) 
					--								FROM Lease 
					--								WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
					--								  AND LeaseStatus NOT IN ('Cancelled')) = 0)
					--						OR LeaseStatus NOT IN ('Cancelled'))
					--				 ORDER BY LeaseEndDate DESC))
			AND (@amount IS NULL OR py.Amount = @amount)
												 
	
		END
	
		IF (@batch IS NULL AND EXISTS (SELECT * FROM @types WHERE Value IN ('Charge')))
		BEGIN
			INSERT INTO #TempTransactions 
			SELECT DISTINCT 
					t.LedgerItemTypeID AS 'LITID',	
					t.TransactionID AS 'ID',		
					--l.LeaseID AS 'ObjectID',
					t.ObjectID AS 'ObjectID',
					tt.[Group] AS 'ObjectType',
					--STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					--	 FROM Person 
					--		 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
					--		 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
					--		 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					--	 WHERE PersonLease.LeaseID = l.LeaseID
					--		   AND PersonType.[Type] = 'Resident'				   
					--		   AND PersonLease.MainContact = 1				   
					--	 FOR XML PATH ('')), 1, 2, '') AS 'Name',
					null AS 'Name',
					--u.Number AS 'Unit',
					null AS 'Unit',
					t.TransactionDate AS 'Date',
					tt.Name AS 'TransactionTypeName',
					t.[Description] AS 'Description',
					--CASE
					--	WHEN lit.LedgerItemTypeID IS NOT NULL THEN lit.Name
					--	ELSE tt.Name 
					--	END AS 'LedgerItemTypeName',	
					tt.Name AS 'LedgerItemTypeName',			
					null AS 'Reference',
					t.Amount AS 'Amount',
					t.TimeStamp AS 'Timestamp',
					--u.PaddedNumber
					null AS 'PaddedNumber'
				FROM [Transaction] t
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Charge') AND tt.[Group] IN ('Lease')
					--INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
					--INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					--INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					--LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
					LEFT JOIN PostingBatch pb ON pb.PostingBatchID = t.PostingBatchID				
					--LEFT JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
					--LEFT JOIN Payment py ON py.PaymentID = pt.PaymentID
				WHERE t.PropertyID  = @propertyID
				  AND t.TransactionDate >= @startDate
				  AND t.TransactionDate <= @endDate
				  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
				  --AND l.LeaseID = ((SELECT TOP 1 LeaseID
						--				 FROM Lease
						--				 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
						--				   AND (((SELECT COUNT(*) 
						--								FROM Lease 
						--								WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
						--								  AND LeaseStatus NOT IN ('Cancelled')) = 0)
						--						OR LeaseStatus NOT IN ('Cancelled'))
						--				 ORDER BY LeaseEndDate DESC))
			AND (@amount IS NULL OR t.Amount = @amount)

		END

		IF (EXISTS (SELECT * FROM @types WHERE Value IN ('Payment', 'Deposit', 'Credit')))
		BEGIN
			INSERT INTO #TempTransactions 
			SELECT DISTINCT
				t.LedgerItemTypeID AS 'LITID',
				py.PaymentID AS 'ID', 						
				t.ObjectID AS 'ObjectID',
				tt.[Group] AS 'ObjectType',
				--CASE
				--		WHEN pr.PersonID IS NOT NULL THEN pr.PreferredName + ' ' + pr.LastName
				--		WHEN woita.WOITAccountID IS NOT NULL THEN woita.Name
				--		WHEN u.UnitID IS NOT NULL THEN 'Vacant Unit'
				--		END AS 'Name',
				--u.Number AS 'Unit',
				null AS 'Name',
				null AS 'Unit',
				(CASE
					WHEN py.PaymentID IS NOT NULL THEN py.[Date]
					ELSE t.TransactionDate END) AS 'Date',
				CASE
					WHEN tt.Name IN ('Balance Transfer Payment', 'Deposit Applied to Balance') THEN 'Payment'
					WHEN tt.Name IN ('Balance Transfer Deposit', 'Deposit Applied to Deposit') THEN 'Deposit'
					ELSE tt.Name END AS 'TransactionTypeName',
				py.[Description] AS 'Description',
				--CASE
				--	WHEN lit.LedgerItemTypeID IS NOT NULL THEN lit.Name
				--	ELSE tt.Name 
				--	END AS 'LedgerItemTypeName',
				tt.Name AS 'LedgerItemTypeName',			
				CASE 
					WHEN py.PaymentID IS NOT NULL THEN py.ReferenceNumber
					ELSE null
					END AS 'Reference',
				py.Amount AS 'Amount',
				py.TimeStamp AS 'Timestamp',
				--u.PaddedNumber
				null AS 'PaddedNumber'			
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name NOT IN ('Prepayment', 'Charge', 'Over Credit', 'Tax Credit')		
				INNER JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
				INNER JOIN Payment py ON py.PaymentID = pt.PaymentID
				LEFT JOIN [Transaction] ta ON ta.AppliesToTransactionID = t.TransactionID
				LEFT JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID
				LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID			
				--LEFT JOIN [Person] pr ON t.ObjectID = pr.PersonID
				--LEFT JOIN [WOITAccount] woita ON t.ObjectID = woita.WOITAccountID
				--LEFT JOIN [Unit] u on t.ObjectID = u.UnitID
				LEFT JOIN Batch b on py.BatchID = b.BatchID
				LEFT JOIN PostingBatch pb ON pb.PostingBatchID = py.PostingBatchID				
			WHERE t.PropertyID  = @propertyID
			  AND py.[Date] >= @startDate
			  AND py.[Date] <= @endDate
			  AND tt.[Group] NOT IN ('Lease', 'Invoice')
			  AND tt.Name IN (SELECT * FROM @types)
			  AND ((@batch IS NULL) OR (b.Number = @batch))
			  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
			  --AND t.Amount > 0
			  AND (ta.TransactionID IS NULL OR tta.Name IN ('Tax Credit', 'Tax Payment'))
			  AND (@amount IS NULL OR py.Amount = @amount)
		END
		  
		IF (@batch IS NULL AND EXISTS (SELECT * FROM @types WHERE Value IN ('Charge')))
		BEGIN
			INSERT INTO #TempTransactions 
			SELECT DISTINCT 
					t.LedgerItemTypeID AS 'LITID',
					t.TransactionID AS 'ID',				
					t.ObjectID AS 'ObjectID',
					tt.[Group] AS 'ObjectType',
					CASE
						WHEN pr.PersonID IS NOT NULL THEN pr.PreferredName + ' ' + pr.LastName
						WHEN woita.WOITAccountID IS NOT NULL THEN woita.Name
						WHEN u.UnitID IS NOT NULL THEN 'Vacant Unit'
						END AS 'Name',
					u.Number AS 'Unit',
					t.TransactionDate AS 'Date',
					tt.Name AS 'TransactionTypeName',
					t.[Description] AS 'Description',
					--CASE
					--	WHEN lit.LedgerItemTypeID IS NOT NULL THEN lit.Name
					--	ELSE tt.Name 
					--	END AS 'LedgerItemTypeName',
					tt.Name AS 'LedgerItemTypeName',				
					null AS 'Reference',
					t.Amount AS 'Amount',
					t.TimeStamp AS 'Timestamp',
					u.PaddedNumber
				FROM [Transaction] t
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name IN ('Charge') AND tt.[Group] NOT IN ('Lease', 'Invoice')								
					LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
					LEFT JOIN [Person] pr ON t.ObjectID = pr.PersonID
					LEFT JOIN [WOITAccount] woita ON t.ObjectID = woita.WOITAccountID
					LEFT JOIN [Unit] u on t.ObjectID = u.UnitID
					LEFT JOIN PostingBatch pb ON pb.PostingBatchID = t.PostingBatchID
				
					--LEFT JOIN PaymentTransaction pt ON t.TransactionID = pt.TransactionID
					--LEFT JOIN Payment py ON py.PaymentID = pt.PaymentID
				WHERE t.PropertyID  = @propertyID
				  AND t.TransactionDate >= @startDate
				  AND t.TransactionDate <= @endDate
				  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
				  --AND t.Amount > 0
				  AND (@amount IS NULL OR t.Amount = @amount)
		END				  
	
	SET @totalCount = (SELECT COUNT(*) FROM #TempTransactions)
	
	UPDATE #TempTransactions SET LedgerItemTypeName = (SELECT Name 
															FROM LedgerItemType
															WHERE #TempTransactions.LITID = LedgerItemTypeID)
		WHERE LITID IS NOT NULL
	
	
	CREATE TABLE #TempTransactions2
	(
		[identity] int identity,
		ID uniqueidentifier NOT NULL,
		ObjectID uniqueidentifier NOT NULL,
		ObjectType nvarchar(50) NOT NULL,
		Name nvarchar(500) NULL,
		Unit nvarchar(25) NULL,
		[Date] date NULL,
		TransactionTypeName nvarchar(20) NOT NULL,
		[Description] nvarchar(200) NULL,
		LedgerItemTypeName nvarchar(100) NOT NULL,
		Reference nvarchar(50) NULL,
		Amount money NOT NULL,
		[Timestamp] datetime NOT NULL,
		PaddedNumber nvarchar(20) NULL		
	)
	
	INSERT INTO #TempTransactions1A 
		SELECT	#tt.ID,
				l.LeaseID AS 'ObjectID',
				#tt.ObjectType,
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
				#tt.[Date] AS 'Date',	
				#tt.TransactionTypeName AS 'TransactionTypeName',
				#tt.[Description] AS 'Description',
				#tt.LedgerItemTypeName AS 'LedgerItemTypeName',
				#tt.Reference AS 'Reference',
				#tt.Amount AS 'Amount',
				#tt.Timestamp AS 'Timestamp',
				u.PaddedNumber AS 'PaddedNumber'			 
			FROM #TempTransactions #tt
				INNER JOIN UnitLeaseGroup ulg ON #tt.ObjectID = ulg.UnitLeaseGroupID 
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
			WHERE #tt.ObjectType = 'Lease'
			  AND l.LeaseID = (SELECT TOP 1 Lease.LeaseID 
							   FROM Lease  
							   INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
							   WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID			     		 
							   ORDER BY Ordering.OrderBy)
			AND (@amount IS NULL OR #tt.Amount = @amount)
		UNION
		
		SELECT	DISTINCT
				#tt.ID AS 'ID',
				#tt.ObjectID AS 'ObjectID',
				#tt.ObjectType AS 'ObjectType',
				CASE
					WHEN per.PersonID IS NOT NULL THEN per.PreferredName + ' ' + per.LastName
					WHEN woita.WOITAccountID IS NOT NULL THEN woita.Name
					WHEN u.UnitID IS NOT NULL THEN 'Vacant Unit'
					END AS 'Name',
				u.Number AS 'Unit',
				#tt.[Date] AS 'Date',
				#tt.TransactionTypeName AS 'TransactionTypeName',
				#tt.[Description] AS 'Description',
				#tt.LedgerItemTypeName AS 'LedgerItemTypeName',
				#tt.Reference AS 'Reference',
				#tt.Amount AS 'Amount',
				#tt.Timestamp AS 'Timestamp',
				u.PaddedNumber
			FROM #TempTransactions #tt
				LEFT JOIN [Person] per ON #tt.ObjectID = per.PersonID
				LEFT JOIN [WOITAccount] woita ON #tt.ObjectID = woita.WOITAccountID
				LEFT JOIN [Unit] u ON #tt.ObjectID = u.UnitID
			WHERE #tt.ObjectType NOT IN ('Lease', 'Invoice')
				AND (@amount IS NULL OR #tt.Amount = @amount)
				
	INSERT INTO #TempTransactions2
		SELECT *
		FROM #TempTransactions1A									 
		ORDER BY
			CASE WHEN @sortBy = 'Date' and @sortOrderIsAsc = 1  THEN [Date] END ASC,
			CASE WHEN @sortBy = 'Date' and @sortOrderIsAsc = 0  THEN [Date] END DESC,
			CASE WHEN @sortBy = 'Reference' and @sortOrderIsAsc = 1  THEN [Reference] END ASC,
			CASE WHEN @sortBy = 'Reference' and @sortOrderIsAsc = 0  THEN [Reference] END DESC,
			CASE WHEN @sortBy = 'Type' and @sortOrderIsAsc = 1  THEN [TransactionTypeName] END ASC,
			CASE WHEN @sortBy = 'Type' and @sortOrderIsAsc = 0  THEN [TransactionTypeName] END DESC,
			CASE WHEN @sortBy = 'Unit' and @sortOrderIsAsc = 1  THEN [PaddedNumber] END ASC,
			CASE WHEN @sortBy = 'Unit' and @sortOrderIsAsc = 0  THEN [PaddedNumber] END DESC,
			CASE WHEN @sortBy = 'Name' and @sortOrderIsAsc = 1  THEN [Name] END ASC,
			CASE WHEN @sortBy = 'Name' and @sortOrderIsAsc = 0  THEN [Name] END DESC,
			CASE WHEN @sortBy = 'Description' and @sortOrderIsAsc = 1  THEN [Description] END ASC,
			CASE WHEN @sortBy = 'Description' and @sortOrderIsAsc = 0  THEN [Description] END DESC,
			CASE WHEN @sortBy = 'Amount' and @sortOrderIsAsc = 1  THEN [Amount] END ASC,
			CASE WHEN @sortBy = 'Amount' and @sortOrderIsAsc = 0  THEN [Amount] END DESC,
			CASE WHEN @sortBy is null THEN [Date] END DESC
	IF @batch IS NULL 
	BEGIN
		SELECT TOP (@pageSize) * FROM 
		(SELECT *, row_number() OVER (ORDER BY [identity]) AS [rownumber] 
		 FROM #TempTransactions2) AS PagedTransactions	 
		WHERE PagedTransactions.rownumber > (((@page - 1) * @pageSize))
	END
	ELSE 
	BEGIN
		SELECT TOP (@pageSize) * FROM 
		(SELECT *, row_number() OVER (ORDER BY [identity]) AS [rownumber] 
		 FROM #TempTransactions2) AS PagedTransactions	 
		WHERE PagedTransactions.rownumber > (((@page - 1) * @pageSize))
	END		
END
GO
