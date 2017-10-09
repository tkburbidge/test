SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO





CREATE PROCEDURE [dbo].[RPT_TNS_DepositSummaryByCategory] 
	-- Add the parameters for the stored procedure here
	@objectTypes StringCollection READONLY,
	@leaseStatuses StringCollection READONLY,
	@propertyIDs GuidCollection READONLY,
	@ledgerItemTypeIDs GuidCollection READONLY,
	@date date = null,
	@objectID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #DepositSummary (
		PropertyName nvarchar(50) not null,
		ObjectID uniqueidentifier not null,
		TObjectID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		ObjectType nvarchar(50) not null,
		Unit nvarchar(50) null,
		PaddedNumber nvarchar(50) null,
		UnitTypeID uniqueidentifier,
		Names nvarchar(500) null,
		LeaseStatus nvarchar(50) null,
		MoveInDate date null,
		LeaseEndDate date null,
		NoticeToVacateDate date null,
		MoveOutDate date null,
		UnitRequiredDeposit money null,
		LeaseRequiredDeposit money null,
		DepositsPaidIn money null,
		DepositsPaidOut money null,
		LedgerItemTypeID uniqueidentifier null,
		Category nvarchar(50) null)

		
	CREATE TABLE #Accounts (
		PropertyName nvarchar(50) not null,
		ObjectID uniqueidentifier not null,
		TObjectID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		ObjectType nvarchar(50) not null,
		Unit nvarchar(50) null,		
		PaddedNumber nvarchar(50) null,
		UnitTypeID uniqueidentifier,
		Names nvarchar(500) null,
		LeaseStatus nvarchar(50) null,
		MoveInDate date null,
		LeaseEndDate date null,
		NoticeToVacateDate date null,
		MoveOutDate date null)
		
	CREATE TABLE #PropertyIDs (
		PropertyID uniqueidentifier
	)

	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs		
			
	CREATE TABLE #LeaseStatuses (
		[Status] nvarchar(100)
	)

	INSERT INTO #LeaseStatuses
		SELECT Value FROM @leaseStatuses

	CREATE TABLE #ObjectTypes (
		[Type] nvarchar(100)
	)

	CREATE TABLE #LedgerItemTypes (
		LedgerItemTypeID uniqueidentifier not null
	)

	INSERT INTO #ObjectTypes
		SELECT Value FROM @objectTypes
		--WHERE Value <> 'Lease'

	INSERT #LedgerItemTypes



		SELECT Value FROM @ledgerItemTypeIDs	

	CREATE TABLE #Deposits (
		TransactionID uniqueidentifier,
		AppliesToLedgerItemTypeID uniqueidentifier,
		ObjectID uniqueidentifier,
		PropertyID uniqueidentifier,
		Amount money,
		TransactionTypeName nvarchar(100),
		TransactionTypeGroup nvarchar(100),
		[Date] date,
		LedgerItemTypeID uniqueidentifier,
		Category nvarchar(100),
		[Type] nvarchar(100) -- PaidIn, PaidOut, LeaseRequired
	)

	INSERT INTO #Deposits
		SELECT 
			t.TransactionID,
			COALESCE(art.LedgerItemTypeID, at.LedgerItemTypeID),
			t.ObjectID,
			t.PropertyID,
			t.Amount,
			tt.Name,
			tt.[Group],
			t.TransactionDate,
			--t.LedgerItemTypeID,
			(CASE WHEN tt.Name IN ('Deposit', 'Balance Transfer Deposit', 'Deposit Interest Payment') THEN t.LedgerItemTypeID
				 ELSE COALESCE(art.LedgerItemTypeID, at.LedgerItemTypeID)
			END),
			lit.Name,
			(CASE WHEN tt.Name IN ('Deposit', 'Balance Transfer Deposit', 'Deposit Interest Payment') THEN 'PaidIn'
				 ELSE 'PaidOut'
			END)
		FROM [Transaction] t 
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID 
			LEFT JOIN [Transaction] at ON at.TransactionID = t.AppliesToTransactionID
			LEFT JOIN [Transaction] rt ON rt.TransactionID = t.ReversesTransactionID
			LEFT JOIN [Transaction] art ON art.TransactionID = rt.AppliesToTransactionID
			LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID			
			INNER JOIN #PropertyIDs #p ON #p.PropertyID = t.PropertyID
			INNER JOIN #ObjectTypes #ot ON #ot.[Type] = tt.[Group]
		WHERE
			tt.Name IN ('Deposit', 'Balance Transfer Deposit', 'Deposit Interest Payment',
						'Deposit Refund', 'Deposit Applied to Balance')
			AND t.TransactionDate <= @date
			AND ((@objectID IS NULL) OR (t.ObjectID = @objectID))

	-- For old balance transfers, we don't have a LedgerItemTypeID so we get the first JournalEntry
	-- that is tied to a Deposit Ledger Item Type
	UPDATE d
		SET LedgerItemTypeID = lit.LedgerItemTypeID
	FROM #Deposits d
		INNER JOIN JournalEntry je ON je.TransactionID = d.TransactionID
		INNER JOIN LedgerItemType lit ON lit.GLAccountID = je.GLAccountID AND lit.IsDeposit = 1
	WHERE d.LedgerItemTypeID IS NULL


	IF ((SELECT COUNT(*) FROM @objectTypes WHERE Value = 'Lease') > 0)
	BEGIN
		INSERT INTO #Deposits
			SELECT 
				lli.LeaseLedgerItemID,
				lli.LeaseLedgerItemID,
				ulg.UnitLeaseGroupID,
				b.PropertyID,
				lli.Amount,
				'Deposit',
				'Lease',
				null,
				lit.LedgerItemTypeID,
				lit.Name,
				'LeaseRequired'
			FROM UnitLeaseGroup ulg
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN LeaseLedgerItem lli ON l.LeaseID = lli.LeaseID
				INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
				INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsDeposit = 1
				INNER JOIN #PropertyIDs #p ON #p.PropertyID = b.PropertyID
			WHERE ((@objectID IS NULL) OR (ulg.UnitLeaseGroupID = @objectID))	

	END
	
	IF ((SELECT COUNT(*) FROM #LedgerItemTypes) > 0)
	BEGIN
		DELETE #d
		 FROM #Deposits #d
		 WHERE #d.LedgerItemTypeID IS NOT NULL
			AND #d.LedgerItemTypeID NOT IN (SELECT LedgerItemTypeID FROM #LedgerItemTypes)
			
	END
	
	IF ((SELECT COUNT(*) FROM @objectTypes WHERE Value = 'Lease') > 0)
	BEGIN
		INSERT INTO #Accounts 
			SELECT DISTINCT
					p.Name AS 'PropertyName', 
					l.LeaseID AS 'ObjectID',
					ulg.UnitLeaseGroupID AS 'TObjectID',
					p.PropertyID AS 'PropertyID',
					'Lease' AS 'ObjectType',
					u.Number AS 'Unit',
					u.PaddedNumber AS 'PaddedNumber',
					ut.UnitTypeID,
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
					(SELECT MIN(pl.MoveInDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID) AS 'MoveInDate',
					l.LeaseEndDate AS 'LeaseEndDate',
					(SELECT MIN(pl.NoticeGivenDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID) AS 'NoticeToVacateDate',
					(SELECT MIN(pl.MoveOutDate) FROM PersonLease pl WHERE pl.LeaseID = l.LeaseID) AS 'MoveOutDate'
				FROM UnitLeaseGroup ulg
					INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
					INNER JOIN Unit u ON ulg.UnitID = u.UnitID
					INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID					
					INNER JOIN Property p ON ut.PropertyID = p.PropertyID
					INNER JOIN #LeaseStatuses #ls ON #ls.[Status] = l.LeaseStatus
					INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = p.PropertyID
				WHERE  ((@objectID IS NULL) OR (ulg.UnitLeaseGroupID = @objectID))				
				  AND l.LeaseID = ((SELECT TOP 1 LeaseID
									FROM Lease 
									INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
									WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID									  
									ORDER BY o.OrderBy))	  
				 AND ulg.UnitLeaseGroupID IN (SELECT ObjectID FROM #Deposits)
	END

	IF ((SELECT COUNT(*) FROM @objectTypes WHERE Value <> 'Lease') > 0)
	BEGIN
	INSERT INTO #Accounts 			

		SELECT DISTINCT p.Name AS 'PropertyName', 
				pr.PersonID AS 'ObjectID',
				pr.PersonID AS 'TObjectID',
				ptp.PropertyID AS 'PropertyID',
				pt.[Type] AS 'ObjectType',
				null AS 'Unit',
				null AS 'PaddedNumber',
				null AS 'UnitTypeID',
				pr.PreferredName + ' ' + pr.LastName AS 'Names',	
				null AS 'LeaseStatus',
				null AS 'MoveInDate',
				null AS 'LeaseEndDate',
				null AS 'NoticeToVacateDate',
				null AS 'MoveOutDate'		
			FROM Person pr				
				INNER JOIN PersonType pt ON pt.PersonID = pr.PersonID
				INNER JOIN PersonTypeProperty ptp ON ptp.PersonTypeID = pt.PersonTypeID
				INNER JOIN Property p ON ptp.PropertyID = p.PropertyID
				INNER JOIN #PropertyIDs #pids ON #pids.PropertyID = ptp.PropertyID
				INNER JOIN #ObjectTypes #ot ON #ot.[Type] = pt.[Type]
			WHERE ((@objectID IS NULL) OR (pr.PersonID = @objectID))
			  AND pr.PersonID IN (SELECT ObjectID FROM #Deposits)
			  
	END
	--SELECT * FROM #Deposits --where [type] = 'PaidOut'

	INSERT INTO #DepositSummary
		SELECT #a.*,0,0,0,0, DepositCategories.LedgerItemTypeID, lit.Name
		FROM #Accounts #a
			INNER JOIN (SELECT DISTINCT #d.ObjectID, #d.LedgerItemTypeID, #d.PropertyID
						FROM #Deposits #d) DepositCategories ON DepositCategories.ObjectID = #a.TObjectID AND DepositCategories.PropertyID = #a.PropertyID
			LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = DepositCategories.LedgerItemTypeID

	UPDATE #DepositSummary SET DepositsPaidIn = (SELECT ISNULL(SUM(#d.Amount), 0)
		FROM #Deposits #d			
		WHERE #d.ObjectID = #DepositSummary.TObjectID		  
		  AND #d.TransactionTypeName IN ('Deposit', 'Balance Transfer Deposit', 'Deposit Interest Payment')
		  AND #d.[Type] = 'PaidIn'
		  AND ((#d.LedgerItemTypeID = #DepositSummary.LedgerItemTypeID) OR (#d.LedgerItemTypeID IS NULL AND #DepositSummary.LedgerItemTypeID IS NULL)))		  
		  
	UPDATE #DepositSummary SET DepositsPaidOut = (SELECT ISNULL(SUM(#d.Amount), 0)		
		FROM #Deposits #d			
		WHERE #d.ObjectID = #DepositSummary.TObjectID		  		
		  AND #d.TransactionTypeName IN ('Deposit Refund', 'Deposit Applied to Balance')
		  --AND ((#d.AppliesToLedgerItemTypeID = #DepositSummary.LedgerItemTypeID) OR (#d.AppliesToLedgerItemTypeID IS NULL AND #DepositSummary.LedgerItemTypeID IS NULL))
		  AND ((#d.LedgerItemTypeID = #DepositSummary.LedgerItemTypeID) OR (#d.LedgerItemTypeID IS NULL AND #DepositSummary.LedgerItemTypeID IS NULL))
		  AND #d.[Type] = 'PaidOut')
		  
	UPDATE #DepositSummary SET LeaseRequiredDeposit = (SELECT ISNULL(SUM(#d.Amount), 0)
		FROM #Deposits #d			
		WHERE #d.ObjectID = #DepositSummary.TObjectID
			AND #d.LedgerItemTypeID = #DepositSummary.LedgerItemTypeID
			AND #d.[Type] = 'LeaseRequired')

	--UPDATE #DepositSummary SET UnitRequiredDeposit = (SELECT ISNULL(SUM(#d.Amount), 0)
	--	FROM #Deposits #d			
	--	WHERE #d.ObjectID = #DepositSummary.TObjectID
	--		AND #d.LedgerItemTypeID = #DepositSummary.LedgerItemTypeID
	--		AND #d.[Type] = 'UnitRequired')
		  
	SELECT PropertyName, ObjectID, PropertyID, ObjectType, Unit, Names, LeaseStatus, MoveInDate, LeaseEndDate, NoticeToVacateDate,
			MoveOutDate, Category, ISNULL(UnitRequiredDeposit, 0) AS 'UnitRequiredDeposit', ISNULL(LeaseRequiredDeposit, 0) AS 'LeaseRequiredDeposit', 
			ISNULL(DepositsPaidIn, 0) AS 'DepositsPaidIn', ISNULL(DepositsPaidOut, 0) AS 'DepositsPaidOut'
		FROM #DepositSummary 
		ORDER BY PaddedNumber, Names

END
GO
