SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Feb. 24, 2012
-- Description:	Generates the data for the RentRoll report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_Historical_RentRoll] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY, 
	@date date	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	--DECLARE @accountingPeriodID uniqueidentifier
	--DECLARE @startDate date, @endDate date

	--SELECT @accountingPeriodID = ap.AccountingPeriodID,
	--	   @startDate = ap.StartDate,
	--	   @endDate = ap.EndDate
	--FROM AccountingPeriod ap
	--WHERE ap.AccountID = @accountID
	--	AND ap.StartDate <= @date
	--	AND ap.EndDate >= @date

	CREATE TABLE #RROccupants 
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null
	)

	INSERT INTO #RROccupants
		EXEC GetOccupantsByDate @accountID, @date, @propertyIDs

	CREATE TABLE #RentRoll 
	(
		ID uniqueidentifier,
		PropertyName nvarchar(200),		
		PropertyID uniqueidentifier null,
		UnitLeaseGroupID uniqueidentifier null,
		LeaseID uniqueidentifier null,
		LeaseStatus nvarchar(100) null,
		Unit nvarchar(100),
		UnitID uniqueidentifier null,
		PaddedUnit nvarchar(100),
		UnitTypeID uniqueidentifier,
		UnitType nvarchar(100),		
		UnitStatus nvarchar(100),
		SquareFootage int,
		Residents nvarchar(4000),
		MoveInDate date null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		MoveOutDate date null,
		TransactionDate date,
		LedgerItemTypeID uniqueidentifier,
		LedgerItemTypeName nvarchar(100),
		IsCharge bit,
		IsRent bit,
		[Description] nvarchar(100),	
		Amount money,
		DepositsHeld money,
		MarketRent money,
		Balance money,
		OrderBy int,
		SuretyBondsTotal money null
	)

	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		UnitStatus nvarchar(200) not null,
		UnitStatusLedgerItemTypeID uniqueidentifier not null,
		RentLedgerItemTypeID uniqueidentifier not null,
		MarketRent decimal null,
		Amenities nvarchar(MAX) null)
		
	CREATE TABLE #PropertiesAndDates (
		Sequence int identity not null,
		PropertyID uniqueidentifier not null, 
		StartDate date not null,
		EndDate date not null)
		
	DECLARE @propertyID uniqueidentifier, @ctr int = 1, @maxCtr int, @unitIDs GuidCollection
	

	INSERT #PropertiesAndDates 
		SELECT pIDs.Value, pap.StartDate, pap.EndDate 
			FROM @propertyIDs pIDs
				INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.StartDate <= @date AND pap.EndDate >= @date
			
	SET @maxCtr = (SELECT MAX(Sequence) FROM #PropertiesAndDates)	
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @propertyID = PropertyID FROM #PropertiesAndDates WHERE Sequence = @ctr
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
						WHERE u.IsHoldingUnit = 0
							AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)

		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 0
		SET @ctr = @ctr + 1
	END	

	INSERT INTO #rentRoll
		SELECT DISTINCT
				t.TransactionID,
				p.Name AS 'PropertyName',	
				p.PropertyID,			
				CASE 
					WHEN (ulg.UnitLeaseGroupID IS NULL) THEN NULL
					ELSE ulg.UnitLeaseGroupID 
					END AS 'UnitLeaseGroupID',
				NULL AS 'LeaseID',
				NULL AS 'LeaseStatus',				
				u.Number AS 'Unit',
				u.UnitID AS 'UnitID',
				u.PaddedNumber AS 'PaddedUnit',		
				ut.UnitTypeID,	
				ut.Name AS 'UnitType',
				US.[Status] AS 'UnitStatus',
				--ut.SquareFootage AS 'SquareFootage',
				u.SquareFootage AS 'SquareFootage',
				NULL AS 'Residents',			
				NULL AS 'MoveInDate',	
				NULL AS 'LeaseStartDate',			
				NULL AS 'LeaseEndDate',
				NULL AS 'MoveOutDate',	
				t.TransactionDate,
				lit.LedgerItemTypeID,
				lit.Name,
				lit.IsCharge,
				lit.IsRent,
				t.[Description],
				t.Amount,
				0 AS 'DepositsHeld',
				--(ISNULL((SELECT TOP 1 ISNULL(Amount, 0) FROM GetLatestMarketRentByUnitTypeID(ut.UnitTypeID, @date) ORDER BY DateEntered DESC), 0)) As 'MarketRent',			
				--0 AS 'MarketRent',
				#ua.MarketRent AS 'MarketRent',
				0 AS 'Balance',				
				CASE 				
					WHEN lit.IsRent = 1 THEN 0
					WHEN lit.IsCharge = 1 THEN 1
					ELSE 2
					END 'OrderBy',
				0 AS 'SuretyBondsTotal'
			FROM [Transaction] t
				INNER JOIN TransactionType tt on tt.TransactionTypeID = t.TransactionTypeID
				LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID						
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
				--INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID
				--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID AND ap.AccountingPeriodID = @accountingPeriodID
				LEFT JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID			
				LEFT JOIN Unit u ON t.ObjectID = u.UnitID OR ulg.UnitID = u.UnitID
				LEFT JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
				LEFT JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID			
				INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID				
				OUTER APPLY GetUnitStatusByUnitID(u.UnitID, null) AS US							
			WHERE 
			  --AND t.Origin IN ('A', 'O', 'I')
				  tr.TransactionID IS NULL
			  AND t.ReversesTransactionID IS NULL
			  AND tt.Name = 'Charge'
			  AND tt.[Group] = 'Lease'
			  AND (t.TransactionDate >= #pad.StartDate /*@startDate*/ AND t.TransactionDate <= #pad.EndDate /*@endDate*/)		  		  
			
	INSERT INTO #rentRoll
		SELECT DISTINCT
				pay.PaymentID,
				p.Name AS 'PropertyName',
				p.PropertyID,
				CASE 
					WHEN (ulg.UnitLeaseGroupID IS NULL) THEN NULL
					ELSE ulg.UnitLeaseGroupID 
					END AS 'UnitLeaseGroupID',
				NULL AS 'LeaseID',
				NULL AS 'LeaseStatus',				
				u.Number AS 'Unit',
				u.UnitID AS 'UnitID',
				u.PaddedNumber AS 'PaddedUnit',		
				ut.UnitTypeID,	
				ut.Name AS 'UnitType',
				US.[Status] AS 'UnitStatus',
				--ut.SquareFootage AS 'SquareFootage',		
				u.SquareFootage AS 'SquareFootage',	
				NULL AS 'Residents',			
				NULL AS 'MoveInDate',
				NULL AS 'LeaseStartDate',
				NULL AS 'LeaseEndDate',			
				NULL AS 'MoveOutDate',	
				pay.[Date],		
				lit.LedgerItemTypeID,
				lit.Name,
				lit.IsCharge,
				lit.IsRent,
				pay.[Description],
				pay.Amount,											
				0 AS 'DepositHeld',
				--(ISNULL((SELECT TOP 1 ISNULL(Amount, 0) FROM GetLatestMarketRentByUnitTypeID(ut.UnitTypeID, @date) ORDER BY DateEntered DESC), 0)) As 'MarketRent',			
				--0 AS 'MarketRent',
				#ua.MarketRent AS 'MarketRent',
				0 AS 'Balance',				
				CASE 				
					WHEN lit.IsRent = 1 THEN 0
					WHEN lit.IsCharge = 1 THEN 1
					ELSE 2
					END AS 'OrderBy',
				0 AS 'SuretyBondsTotal'
			FROM Payment pay
				INNER JOIN PaymentTransaction pt ON pay.PaymentID = pt.PaymentID 
				INNER JOIN [Transaction] t ON t.TransactionID = pt.TransactionID
				INNER JOIN TransactionType tt on tt.TransactionTypeID = t.TransactionTypeID
				INNER JOIN Property p ON t.PropertyID = p.PropertyID
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
				--INNER JOIN PropertyAccountingPeriod pap ON p.PropertyID = pap.PropertyID
				--INNER JOIN AccountingPeriod ap ON pap.AccountingPeriodID = ap.AccountingPeriodID AND ap.AccountingPeriodID = @accountingPeriodID
				LEFT JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID			
				LEFT JOIN Unit u ON t.ObjectID = u.UnitID OR ulg.UnitID = u.UnitID
				LEFT JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
				LEFT JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID						
				INNER JOIN LedgerItemType lit ON t.LedgerItemTypeID = lit.LedgerItemTypeID				
				OUTER APPLY GetUnitStatusByUnitID(u.UnitID, null) AS US							
			WHERE 
			  --AND t.Origin IN ('A', 'O', 'I')
			  pay.ReversedDate IS NULL
			  AND pay.Amount > 0
			  AND tr.TransactionID IS NULL
			  AND t.ReversesTransactionID IS NULL
			  AND tt.Name = 'Credit'
			  AND tt.[Group] = 'Lease'			    		  
			  AND (pay.[Date] >= #pad.StartDate /*@startDate*/ AND pay.[Date] <= #pad.EndDate /*@endDate*/)		  		  
	

	-- Remove any rows for people that weren't living in the unit at the date of the report
	

	DELETE FROM #RentRoll 
	WHERE UnitLeaseGroupID IS NOT NULL
		AND UnitLeaseGroupID NOT IN (SELECT DISTINCT UnitLeaseGroupID FROM #RROccupants WHERE UnitLeaseGroupID IS NOT NULL)
			
		
	-- New GPR change will not report vacant units.  Add units that are not found to have
	-- transactions from above			
	INSERT INTO	#rentRoll
			SELECT DISTINCT
				null,
				p.Name AS 'PropertyName',
				p.PropertyID,
				-- If we had an occupant but there were no charges then set the UnitLeaseGroupID
				(CASE WHEN #rro.UnitLeaseGroupID IS NULL THEN NULL
					  ELSE #rro.UnitLeaseGroupID
				 END) AS 'UnitLeaseGroupID',
				NULL AS 'LeaseID',
				NULL AS 'LeaseStatus',				
				u.Number AS 'Unit',
				u.UnitID AS 'UnitID',
				u.PaddedNumber AS 'PaddedUnit',		
				ut.UnitTypeID,	
				ut.Name AS 'UnitType',
				US.[Status] AS 'UnitStatus',
				--ut.SquareFootage AS 'SquareFootage',		
				u.SquareFootage AS 'SquareFootage',	
				NULL AS 'Residents',			
				NULL AS 'MoveInDate',
				NULL AS 'LeaseStartDate',
				NULL AS 'LeaseEndDate',			
				NULL AS 'MoveOutDate',	
				NULL AS 'Date',		
				NULL AS 'LedgerItemTypeID',
				NULL AS 'LedgerItemTypeName',
				1,
				1,
				'',
				0,
				0 AS 'DepositHeld',
				--(ISNULL((SELECT TOP 1 ISNULL(Amount, 0) FROM GetLatestMarketRentByUnitTypeID(ut.UnitTypeID, @date) ORDER BY DateEntered DESC), 0)) As 'MarketRent',			
				--0 AS 'MarketRent',
				#ua.MarketRent AS 'MarketRent',
				0 AS 'Balance',				
				0 AS 'OrderBy',
				0 AS 'SuretyBondsTotal'
			FROM #UnitAmenities #ua
				LEFT JOIN #RentRoll #r2 ON #r2.UnitID = #ua.UnitID	
				-- If there were not charges or credits but for some reason there was
				-- a current occupant then we need to show that unit as occupied.
				-- Add a zero row
				LEFT JOIN #RROccupants #rro ON #rro.UnitID = #ua.UnitID			
				INNER JOIN Unit u ON #ua.UnitID = u.UnitID				
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID				
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID				
				OUTER APPLY GetUnitStatusByUnitID(u.UnitID, null) AS US							
			WHERE p.PropertyID IN (SELECT Value FROM @propertyIDs)
			  -- We join in the #RentRoll table here where there is no UniID
			  -- which means that no charges or credits existed for the unit
			  AND #r2.UnitID IS NULL

	

	DECLARE @postingDate date =	(SELECT TOP 1 TransactionDate 
								 FROM (SELECT TransactionDate, COUNT(*) AS 'TransactionCount'
										FROM #RentRoll
										GROUP BY TransactionDate) t
									 ORDER BY [TransactionCount] DESC)
									
		
		
	--UPDATE #RentRoll
	--	SET MarketRent = (ISNULL((SELECT TOP 1 ISNULL(Amount, 0) FROM GetLatestMarketRentByUnitTypeID(#RentRoll.UnitTypeID, @postingDate) ORDER BY DateEntered DESC), 0))
				
	-- Get the last lease where the date is in the lease date range
		UPDATE rr
			SET LeaseID = l.LeaseID,
			 LeaseStatus = l.LeaseStatus,
			 LeaseStartDate = l.LeaseStartDate,
			 LeaseEndDate = l.LeaseEndDate				 
		FROM #RentRoll rr
			INNER JOIN Lease l ON l.UnitLeaseGroupID = rr.UnitLeaseGroupID
		WHERE rr.UnitLeaseGroupID IS NOT NULL
			AND (l.LeaseID = (SELECT TOP 1 LeaseID			
								FROM Lease 								
								WHERE UnitLeaseGroupID = l.UnitLeaseGroupID
								  AND LeaseStartDate <= @date
								  AND LeaseEndDate >= @date
								  AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
								ORDER BY DateCreated DESC))
		
		-- Get the last lease where the EndDate <= @date (Month-to-Month Leases) 
		UPDATE rr
			SET LeaseID = l.LeaseID,
			 LeaseStatus = l.LeaseStatus,
			 LeaseStartDate = l.LeaseStartDate,
			 LeaseEndDate = l.LeaseEndDate			 
		FROM #RentRoll rr
			INNER JOIN Lease l ON l.UnitLeaseGroupID = rr.UnitLeaseGroupID
		WHERE rr.UnitLeaseGroupID IS NOT NULL
			AND rr.LeaseID IS NULL
			AND (l.LeaseID = (SELECT TOP 1 LeaseID			
								FROM Lease 								
								WHERE UnitLeaseGroupID = l.UnitLeaseGroupID								  
								  AND LeaseEndDate <= @date
								  AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
								ORDER BY LeaseEndDate DESC))
		 

		-- For the messed up lease entries, grab the first lease
		-- associated with the UnitLeaseGroup
		UPDATE rr
			 SET LeaseID = l.LeaseID,
			 LeaseStatus = l.LeaseStatus,
			 LeaseStartDate = l.LeaseStartDate,
			 LeaseEndDate = l.LeaseEndDate			 				 
		FROM #RentRoll rr
			INNER JOIN Lease l ON l.UnitLeaseGroupID = rr.UnitLeaseGroupID
		WHERE rr.UnitLeaseGroupID IS NOT NULL
			AND rr.LeaseID IS NULL
			AND (l.LeaseID = (SELECT TOP 1 LeaseID			
								FROM Lease 
								WHERE UnitLeaseGroupID = l.UnitLeaseGroupID							 
								AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
								ORDER BY LeaseStartDate))
	
	---- Get the lease that was in effect at the time of this report			
	--UPDATE rr
	--	 SET LeaseID = l.LeaseID,
	--		 LeaseStatus = l.LeaseStatus,
	--		 LeaseEndDate = l.LeaseEndDate
	--FROM #RentRoll rr
	--	INNER JOIN Lease l ON l.UnitLeaseGroupID = rr.UnitLeaseGroupID
	--WHERE rr.UnitLeaseGroupID IS NOT NULL
	--	AND (l.LeaseID = (SELECT TOP 1 LeaseID			
	--						FROM Lease 
	--						INNER JOIN Ordering o ON o.[Type] = 'Lease' AND o.Value = Lease.LeaseStatus
	--						WHERE UnitLeaseGroupID = l.UnitLeaseGroupID
	--						  AND LeaseStartDate <= @endDate
	--						ORDER BY LeaseStartDate DESC, o.OrderBy))			 
		 

	---- For the messed up lease entries, grab the first lease
	---- associated with the UnitLeaseGroup
	--UPDATE rr
	--	 SET LeaseID = l.LeaseID,
	--		 LeaseStatus = l.LeaseStatus,
	--		 LeaseEndDate = l.LeaseEndDate
	--FROM #RentRoll rr
	--	INNER JOIN Lease l ON l.UnitLeaseGroupID = rr.UnitLeaseGroupID
	--WHERE rr.UnitLeaseGroupID IS NOT NULL
	--	AND rr.LeaseID IS NULL
	--	AND (l.LeaseID = (SELECT TOP 1 LeaseID			
	--						FROM Lease 
	--						WHERE UnitLeaseGroupID = l.UnitLeaseGroupID							 
	--						ORDER BY LeaseStartDate))			 

	-- Calculate deposits
	UPDATE #RentRoll SET DepositsHeld = ((SELECT ISNULL(SUM(t.Amount), 0)
											FROM [Transaction] t
												INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
											WHERE t.ObjectID = #RentRoll.UnitLeaseGroupID
											  AND tt.Name IN ('Deposit', 'Balance Transfer Deposit', 'Deposit Applied to Deposit')
											  AND t.TransactionDate <= @date) -
											(SELECT ISNULL(SUM(tb.Amount), 0)
												FROM [Transaction] tb
													INNER JOIN TransactionType ttb ON tb.TransactionTypeID = ttb.TransactionTypeID
												WHERE tb.ObjectID = #RentRoll.UnitLeaseGroupID
												  AND ttb.Name IN ('Deposit Refund')
												  AND tb.TransactionDate <= @date))
		WHERE UnitLeaseGroupID IS NOT NULL		
		
	-- Calculate Surety Bonds
	UPDATE #RentRoll SET SuretyBondsTotal = (SELECT ISNULL(SUM(ISNULL(sb.Coverage, 0) + ISNULL(sb.PetCoverage, 0)), 0)
												FROM SuretyBond sb
												WHERE sb.UnitLeaseGroupID = #RentRoll.UnitLeaseGroupID
												  AND sb.PaidDate <= @date) 									  

	-- Calculate Balances
	UPDATE #RentRoll SET Balance = (SELECT Balance FROM GetObjectBalance(null, @date, #RentRoll.UnitLeaseGroupID, 0, @propertyIDs))
		WHERE UnitLeaseGroupID IS NOT NULL

	-- Get resident names
	UPDATE #RentRoll SET Residents = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
									 FROM Person 
										 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
										 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
										 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
									 WHERE PersonLease.LeaseID = #RentRoll.LeaseID
										   AND PersonType.[Type] = 'Resident'				   
										   AND PersonLease.MainContact = 1				   
									 FOR XML PATH ('')), 1, 2, '')				
		WHERE #RentRoll.LeaseID IS NOT NULL								 

	-- Get Move In Date
	UPDATE #RentRoll SET MoveInDate = (SELECT MIN(pl.MoveInDate)
										FROM PersonLease pl
										WHERE pl.LeaseID = #RentRoll.LeaseID)
		WHERE #RentRoll.LeaseID IS NOT NULL									

	-- Get Move Out Date
	UPDATE #RentRoll SET MoveOutDate = (SELECT MAX(pl.MoveOutDate)
										FROM PersonLease pl					
											LEFT JOIN PersonLease pl1 ON pl1.LeaseID = pl.LeaseID AND pl1.MoveOutDate IS NULL
										WHERE pl.LeaseID = #RentRoll.LeaseID 
											AND pl1.PersonLeaseID IS NULL) 
		WHERE #RentRoll.UnitLeaseGroupID IS NOT NULL										

	CREATE TABLE #Vacancy (
		UnitID nvarchar(100),
		Amount money
	)

	--INSERT INTO #Vacancy
	--	SELECT t.Note, t.Amount
	--		FROM TransactionGroup tg
	--		INNER JOIN [Transaction] t ON t.TransactionID = tg.TransactionID
	--		INNER JOIN JournalEntry je ON je.TransactionID = t.TransactionID
	--		--INNER JOIN AccountingPeriod ap ON ap.AccountID = @accountID AND ap.AccountingPeriodID = @accountingPeriodID
	--		INNER JOIN #Properties #pids ON #pids.PropertyID = t.PropertyID
	--		WHERE tg.AccountID = @accountID
	--			AND t.TransactionDate >= @startDate
	--			AND t.TransactionDate <= @endDate
	--			AND t.Origin = 'G'
	--			AND je.AccountingBasis = 'Accrual'
	--			AND t.Note IS NOT NULL
	--			AND LEN(t.Note) = 36

	--UPDATE #RentRoll SET Amount = ISNULL((SELECT SUM(ISNULL(Amount, 0))
	--									   FROM #Vacancy #v
	--									   WHERE #v.UnitID = #RentRoll.UnitID), 0)
	--	WHERE #RentRoll.UnitLeaseGroupID IS NULL
	--		  AND #RentRoll.LedgerItemTypeID IS NULL

	SELECT ID,
			PropertyName,
			UnitLeaseGroupID,
			LeaseID,
			LeaseStatus,
			Unit,
			UnitID,
			PaddedUnit,
			UnitTypeID,
			UnitType, 
			ISNULL(SquareFootage, 0) AS SquareFootage,
			Residents,
			MoveInDate,
			LeaseStartDate,
			LeaseEndDate,
			MoveOutDate,
			TransactionDate, 
			LedgerItemTypeID,
			LedgerItemTypeName,
			IsCharge,
			IsRent,
			[Description],
			Amount,
			DepositsHeld,
			IsNull(MarketRent, 0) AS MarketRent,
			Balance,
			OrderBy,
			SuretyBondsTotal
		FROM #RentRoll ORDER BY PaddedUnit, UnitLeaseGroupID
	
END
GO
