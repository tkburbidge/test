SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO








CREATE PROCEDURE [dbo].[RPT_TNS_TransactionSummaryByUnit] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
--DECLARE @startDate date = null
DECLARE @ctr int = 1
DECLARE @maxCtr int
DECLARE @propertyID uniqueidentifier
DECLARE @unitIDs GuidCollection
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;	
    
    CREATE TABLE #RentRoll2 (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		ObjectID uniqueidentifier not null,
		LeaseID uniqueidentifier null,
		LeaseStatus nvarchar(50) null,
		Unit nvarchar(50) null,
		PaddedUnit nvarchar(50) null,
		UnitType nvarchar(50) null,
		Residents nvarchar(250) null,
		MoveInDate date null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		MoveOutDate date null,
		DepositsHeld money null,
		MarketRent money null,
		StartingBalance money null)
		
	CREATE TABLE #RentRoll2Transaction (
		ObjectID uniqueidentifier not null,
		TransactionTypeGroup nvarchar(500) null,
		LedgerItemTypeName nvarchar(500) null,
		[Type] nvarchar(250) null,
		AppliesToRent bit null,
		Amount money null,
		IsLateFee bit null,
		IsRent bit null,
		Origin nchar(1) null)
		
	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		UnitStatus nvarchar(200) not null,
		UnitStatusLedgerItemTypeID uniqueidentifier not null,
		RentLedgerItemTypeID uniqueidentifier not null,
		MarketRent money null,
		Amenities nvarchar(MAX) null)		

	CREATE TABLE #TransactionableObjects (
		ObjectID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		TTType nvarchar(50) null,
		StartingBalance money null,
		DepositsHeld money null)
		
	CREATE TABLE #PropertiesAndDate (
		Sequence int identity,
		PropertyID uniqueidentifier not null,
		StartDate date not null)
		

	INSERT #PropertiesAndDate 
		SELECT pIDs.Value, pap.StartDate
			FROM @propertyIDs pIDs
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.StartDate <= @date AND pap.EndDate >= @date
	
	--SET @startDate = (SELECT TOP 1 ap.StartDate
	--					  FROM AccountingPeriod ap 
	--						INNER JOIN #Properties #p ON ap.AccountID = @accountID
	--					  WHERE ap.StartDate <= @date
	--					    AND ap.EndDate >= @date)
		
	INSERT #TransactionableObjects
		SELECT	DISTINCT t.ObjectID, t.PropertyID, tt.[Group], 0, 0
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.[Group] IN ('Unit', 'Lease')
				INNER JOIN #PropertiesAndDate #pad ON t.PropertyID = #pad.PropertyID
			WHERE t.TransactionDate >= #pad.StartDate --@startDate
			  AND t.TransactionDate <= @date

	UPDATE #TransactionableObjects SET StartingBalance = ISNULL(CurBal.Balance, 0)
		FROM #TransactionableObjects
			INNER JOIN #PropertiesAndDate #pad ON #TransactionableObjects.PropertyID = #pad.PropertyID
			CROSS APPLY GetObjectBalance(null, DATEADD(DAY, -1, #pad.StartDate /*@startDate*/), #TransactionableObjects.ObjectID, 0, @propertyIDs) AS [CurBal]
			
	UPDATE #to SET DepositsHeld = ((SELECT ISNULL(SUM(t.Amount), 0)
					FROM [Transaction] t
						INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					WHERE t.ObjectID = #to.ObjectID
					  AND tt.Name IN ('Deposit', 'Balance Transfer Deposit', 'Deposit Applied to Deposit')
					  AND t.TransactionDate <= @date) -
					(SELECT ISNULL(SUM(tb.Amount), 0)
						FROM [Transaction] tb
							INNER JOIN TransactionType ttb ON tb.TransactionTypeID = ttb.TransactionTypeID
						WHERE tb.ObjectID = #to.ObjectID
						  AND ttb.Name IN ('Deposit Refund')
						  AND tb.TransactionDate <= @date))
		FROM #TransactionableObjects #to
			
	SET @maxCtr = (SELECT MAX(Sequence) FROM #PropertiesAndDate)
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @propertyID = PropertyID FROM #PropertiesAndDate WHERE Sequence = @ctr
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 0
		SET @ctr = @ctr + 1
	END	
	
	INSERT #RentRoll2 
		SELECT  DISTINCT
				p.PropertyID,
				p.Name AS 'PropertyName',
				#to.ObjectID AS 'ObjectID',
				l.LeaseID AS 'LeaseID',
				l.LeaseStatus AS 'LeaseStatus',
				u.Number AS 'Unit',
				u.PaddedNumber AS 'PaddedUnit',
				ut.Name AS 'UnitType',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
							 FROM Person 
								 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
								 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
								 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
							 WHERE PersonLease.LeaseID = l.LeaseID
								   AND PersonType.[Type] = 'Resident'				   
								   AND PersonLease.MainContact = 1				   
							 FOR XML PATH ('')), 1, 2, '')
					AS 'Residents',		
				(SELECT MIN(pl.MoveInDate)
					FROM PersonLease pl
					WHERE pl.LeaseID = l.LeaseID) AS 'MoveInDate',
				l.LeaseStartDate AS 'LeaseStartDate',
				l.LeaseEndDate AS 'LeaseEndDate',
				(SELECT MAX(pl.MoveOutDate)
					FROM PersonLease pl
						INNER JOIN Lease l1 ON pl.LeaseID = l1.LeaseID
						LEFT JOIN PersonLease pl1 ON l1.LeaseID = pl1.LeaseID AND pl1.MoveOutDate IS NULL
					WHERE l1.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					  AND pl1.PersonLeaseID IS NULL
					  AND l1.LeaseID = (SELECT TOP 1 LeaseID 
											FROM Lease
											WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
											  AND LeaseID = l.LeaseID
											ORDER BY LeaseEndDate)) AS 'MoveOutDate',
				#to.DepositsHeld AS 'DepositsHeld',
				#ua.MarketRent AS 'MarketRent',
				ISNULL(#to.StartingBalance, 0) AS 'StartingBalance'									
			FROM #TransactionableObjects #to
				INNER JOIN Property p ON #to.PropertyID = p.PropertyID
				INNER JOIN UnitLeaseGroup ulg ON #to.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
			WHERE l.LeaseID = (SELECT TOP 1 Lease.LeaseID 
								FROM Lease  
								INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
								WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID			     		 
								ORDER BY Ordering.OrderBy)
									 
		UNION
		
		SELECT	DISTINCT
				p.PropertyID,
				p.Name AS 'PropertyName',
				#to.ObjectID AS 'ObjectID',
				null AS 'LeaseID',
				null AS 'LeaseStatus',
				u.Number AS 'Unit',
				u.PaddedNumber AS 'PaddedUnit',
				ut.Name AS 'UnitType',
				null AS 'Residents',		
				null AS 'MoveInDate',
				null AS 'LeaseStartDate',
				null AS 'LeaseEndDate',
				null AS 'MoveOutDate',
				0 AS 'DepositsHeld',
				#ua.MarketRent AS 'MarketRent',
				0 AS 'StartingBalance'	
			FROM #TransactionableObjects #to
				INNER JOIN Unit u ON #to.ObjectID = u.UnitID
				INNER JOIN Property p ON #to.PropertyID = p.PropertyID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
				
	--INSERT INTO #RentRoll2Transaction
	--	SELECT	DISTINCT
	--			#to.ObjectID,
	--			#to.TTType,
	--			lit.Name,
	--			tt.Name,
	--			CASE
	--				WHEN (tt.Name = 'Credit' AND appLit.IsRent = 1) THEN CAST(1 AS bit)
	--				ELSE CAST(0 AS bit) END,
	--			t.Amount,
	--			CASE
	--				WHEN (lit.LedgerItemTypeID = s.LateFeeLedgerItemTypeID) THEN CAST(1 AS bit)
	--				ELSE CAST(0 AS bit) END,
	--			CASE
	--				WHEN (lit.IsRent = 1) THEN CAST(1 AS bit)
	--				ELSE CAST(0 AS bit) END
	--		FROM [Transaction] t
	--			INNER JOIN #TransactionableObjects #to ON t.ObjectID = #to.ObjectID
	--			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
	--					AND ((tt.Name IN ('Payment', 'Credit', 'Charge', 'Tax Charge', 'Deposit Applied to Balance', 'Balance Transfer Payment', 'Payment Refund'))
	--							OR ((tt.Name IN ('Prepayment', 'Over Credit', 'Payment', 'Credit') AND t.Origin = 'T')))
	--			INNER JOIN Settings s ON t.AccountID = s.AccountID
	--			LEFT JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID
	--			LEFT JOIN LedgerItemType appLit ON lit.AppliesToLedgerItemTypeID = appLit.LedgerItemTypeID
	--		WHERE t.TransactionDate >= @startDate
	--		  AND t.TransactionDate <= @date
			  
			  
			  
	INSERT INTO #RentRoll2Transaction
		SELECT
			t.ObjectID,
			tt.[Group],
			lit.Name,
			tt.Name,
			0,
			t.Amount,
			(CASE WHEN lit.LedgerItemTypeID = s.LateFeeLedgerItemTypeID THEN CAST(1 AS BIT)
				  ELSE CAST(0 AS BIT)
			 END) AS IsLateFee,
			lit.IsRent,
			t.Origin				
		FROM [Transaction] t
			INNER JOIN #TransactionableObjects #to ON t.ObjectID = #to.ObjectID
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
			INNER JOIN Settings s ON s.AccountID = @accountID
			INNER JOIN #PropertiesAndDate #pad ON t.PropertyID = #pad.PropertyID
			LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID			
		WHERE tt.Name IN ('Charge')
		  AND t.TransactionDate >= #pad.StartDate --@startDate
		  AND t.TransactionDate <= @date
		  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))		
		    
	INSERT INTO #RentRoll2Transaction
		SELECT
			t.ObjectID,
			t.[Group],
			t.LedgerItemTypeName,
			t.[Type],
			t.AppliesToRent,
			t.Amount,
			t.IsLateFee,
			t.IsRent,
			null
		FROM (SELECT DISTINCT 
				p.PaymentID, 				
				t.ObjectID,
				tt.[Group],
				lit.Name AS LedgerItemTypeName,
				tt.Name AS [Type],
				CASE
					WHEN (tt.Name = 'Credit' AND appLit.IsRent = 1) THEN CAST(1 AS bit)
					ELSE CAST(0 AS bit) END AS AppliesToRent,
				p.Amount,
				0 AS IsLateFee,
				0 As IsRent
				FROM Payment p				
					INNER JOIN PaymentTransaction pt ON pt.PaymentID = p.PaymentID
					INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID 			
					INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
					INNER JOIN #TransactionableObjects #to ON t.ObjectID = #to.ObjectID
					INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
					INNER JOIN #PropertiesAndDate #pad ON t.PropertyID = #pad.PropertyID
					LEFT JOIN LedgerItemType appLit ON lit.AppliesToLedgerItemTypeID = appLit.LedgerItemTypeID
					LEFT JOIN PostingBatch pb ON p.PostingBatchID = pb.PostingBatchID
				WHERE tt.Name IN ('Credit', 'Payment')
				  AND t.LedgerItemTypeID IS NOT NULL
				  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))
				  AND p.ObjectID = t.ObjectID
				  AND p.[Date] >= #pad.StartDate --@startDate
				  AND p.[Date] <= @date) t
		
	INSERT INTO #RentRoll2Transaction
		SELECT
			t.ObjectID,
			tt.[Group],
			COALESCE(lit.Name, tt.Name),
			tt.Name,
			CASE
				WHEN (tt.Name = 'Credit' AND appLit.IsRent = 1) THEN CAST(1 AS bit)
				ELSE CAST(0 AS bit) END AS AppliesToRent,
			t.Amount,
			(CASE WHEN lit.LedgerItemTypeID = s.LateFeeLedgerItemTypeID THEN CAST(1 AS BIT)
				  ELSE CAST(0 AS BIT)
			 END) AS IsLateFee,		
			(CASE WHEN lit.IsRent IS NOT NULL AND lit.IsRent = 1 THEn CAST(1 AS BIT)
				  ELSE CAST(0 AS BIT)
			 END) AS IsRent,
			 null
		FROM [Transaction] t
			INNER JOIN #TransactionableObjects #to ON t.ObjectID = #to.ObjectID
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
			INNER JOIN Settings s ON s.AccountID = @accountID
			INNER JOIN #PropertiesAndDate #pad ON t.PropertyID = #pad.PropertyID
			LEFT JOIN PostingBatch pb ON t.PostingBatchID = pb.PostingBatchID
			LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
			LEFT JOIN LedgerItemType appLit ON lit.AppliesToLedgerItemTypeID = appLit.LedgerItemTypeID
		WHERE ((tt.Name IN ('Deposit Applied to Balance', 'Balance Transfer Payment', 'Payment Refund'))
				 OR ((tt.Name IN ('Payment', 'Credit', 'Deposit', 'Prepayment', 'Over Credit')) AND (t.Origin = 'T')))
		  AND t.TransactionDate >= #pad.StartDate --@startDate
		  AND t.TransactionDate <= @date
		  AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))			  
	
	SELECT * FROM #RentRoll2
		ORDER BY PaddedUnit, LeaseID DESC
	
	SELECT * FROM #RentRoll2Transaction
		ORDER BY ObjectID
		
END



GO
