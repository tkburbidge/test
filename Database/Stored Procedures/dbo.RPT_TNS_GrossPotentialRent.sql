SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Nick Olsen
-- Create date: July 21, 2012
-- Description:	Gets the data for the GPR report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_TNS_GrossPotentialRent] 
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection readonly,
	@accountingPeriodID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    
	DECLARE @lossToLeaseLedgerItemTypeID uniqueidentifier
	DECLARE @gainToLeaseLedgerItemTypeID uniqueidentifier

	--SELECT @startDate = StartDate, @endDate = EndDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID
	SELECT @lossToLeaseLedgerItemTypeID = LossToLeaseLedgerItemTypeID, @gainToLeaseLedgerItemTypeID = GainToLeaseLedgerItemTypeID FROM Settings WHERE AccountID = @accountID

	CREATE TABLE #units 
	(	
		PropertyID uniqueidentifier,
		PropertyName nvarchar(100),
		UnitID uniqueidentifier,
		UnitTypeID uniqueidentifier,
		UnitNumber nvarchar(50),
		PaddedNumber nvarchar(50),
		UnitType nvarchar(50),
		SquareFeet int,
		UnitLeaseGroupID uniqueidentifier null,		
		MarketRent money null,
		LossToLease money,
		GainToLease money,
		ActualRent money,
		VacancyLoss money,
		Credits money,
		RentCollected money,		
		RentDelinquency money,
		GainToLeaseDelinquency money
	)

	CREATE TABLE #Residents
	(
		UnitLeaseGroupID uniqueidentifier,
		LeaseID uniqueidentifier, 
		LeaseStartDate date,
		LeaseEndDate date,
		Residents nvarchar(1000)
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
		
	DECLARE @propertyID uniqueidentifier, @ctr int = 1, @maxCtr int, @unitIDs GuidCollection, @date date
	
	INSERT #PropertiesAndDates SELECT pIDs.Value, pap.StartDate, pap.EndDate
		FROM @propertyIDs pIDs
			INNER JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID
			
	SET @maxCtr = (SELECT MAX(Sequence) FROM #PropertiesAndDates)
	SET @date = (SELECT StartDate FROM AccountingPeriod WHERE AccountingPeriodID = @accountingPeriodID)
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @propertyID = PropertyID, @date = EndDate FROM #PropertiesAndDates WHERE Sequence = @ctr
		DELETE FROM @unitIDs
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
							WHERE u.ExcludedFromOccupancy = 0
		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 0
		SET @ctr = @ctr + 1
	END				

	INSERT INTO #units
		SELECT 
			p.PropertyID,
			p.Name,
			u.UnitID,
			u.UnitTypeID,
			u.Number,
			u.PaddedNumber,
			ut.Name,
			--ut.SquareFootage,
			u.SquareFootage,
			null AS 'UnitLeaseGroupID',			
			--NULL AS 'MarketRent',
			#ua.MarketRent AS 'MarketRent',
			0 AS 'LossToLease', 
			0 AS 'GainToLease', 
			0 AS 'ActualRent',
			0 AS 'VacancyLoss', 
			0 AS 'Credits', 
			0 AS 'RentCollected',			
			0 AS 'Delinquency',
			0 AS 'GainToLeaseDelinquency'						
		FROM Unit u
		INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
		INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
		INNER JOIN Building b on b.BuildingID = u.BuildingID
		INNER JOIN Property p on p.PropertyID = b.PropertyID	
		INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = p.PropertyID
		WHERE u.IsHoldingUnit = 0
			
	--UPDATE #units SET MarketRent = (SELECT TOP 1 mr.Amount 
	--									   FROM MarketRent mr									   									   
	--									   WHERE mr.UnitTypeID = #units.UnitTypeID
	--											AND mr.DateChanged <= @startDate
	--									   ORDER BY mr.DateChanged)
												
	--UPDATE #units SET MarketRent = (SELECT TOP 1 ISNULL(mr.Amount , 0)
	--									   FROM MarketRent mr									   
	--									   WHERE mr.UnitTypeID = #units.UnitTypeID
	--									   ORDER BY mr.DateChanged)
	--					WHERE #units.MarketRent IS NULL
						
	---- Just in case
	--UPDATE #units SET MarketRent = 0 WHERE MarketRent IS NULL						
						   									   	
	-- Get all loss to lease that applied to rent					   									   							   							   
	UPDATE #units SET LossToLease = (SELECT ISNULL(SUM(t.Amount), 0)
											FROM [Transaction] t
											INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = t.ObjectID
											INNER JOIN [Transaction] ta ON ta.TransactionID = t.AppliesToTransactionID
											INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
											LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID											
											LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID		
											INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = t.PropertyID									
											WHERE ulg.UnitID = #units.UnitID
												-- Transaction is in the given month
												AND t.TransactionDate >= #pad.StartDate--@startDate
												AND t.TransactionDate <= #pad.EndDate--@endDate
												AND t.LedgerItemTypeID = @lossToLeaseLedgerItemTypeID 
												-- Applied to a transaction in the given month
												AND ta.TransactionDate >= #pad.StartDate--@startDate
												AND ta.TransactionDate <= #pad.EndDate--@endDate												
												AND (alit.IsRent = 1 OR alit.LedgerItemTypeID = @gainToLeaseLedgerItemTypeID)
												AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
												AND t.ReversesTransactionID IS NULL
												AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))

	-- Get all gain to lease
	UPDATE #units SET GainToLease = (SELECT ISNULL(SUM(t.Amount), 0)
											FROM [Transaction] t
											INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = t.ObjectID
											LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
											LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID	
											INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = t.PropertyID										
											WHERE ulg.UnitID = #units.UnitID
												AND t.TransactionDate >= #pad.StartDate--@startDate
												AND t.TransactionDate <= #pad.EndDate--@endDate
												AND t.LedgerItemTypeID = @gainToLeaseLedgerItemTypeID
												AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
												AND t.ReversesTransactionID IS NULL
												AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))

	-- Get all rent charges charged to a given lease											
	UPDATE #units SET ActualRent = (SELECT ISNULL(SUM(t.Amount), 0)
											FROM [Transaction] t
											INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = t.ObjectID
											INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
											LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
											LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID		
											INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = t.PropertyID									
											WHERE ulg.UnitID = #units.UnitID
												AND t.TransactionDate >= #pad.StartDate--@startDate
												AND t.TransactionDate <= #pad.EndDate--@endDate
												AND lit.IsRent = 1
												AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
												AND t.ReversesTransactionID IS NULL
												AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))

	-- Get all rent charges charged to a unit
	UPDATE #units SET ActualRent = ActualRent + (SELECT ISNULL(SUM(t.Amount), 0)
														FROM [Transaction] t													
														INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
														LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
														LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID	
														INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = t.PropertyID										
														WHERE t.ObjectID = #units.UnitID
															AND t.TransactionDate >= #pad.StartDate--@startDate
															AND t.TransactionDate <= #pad.EndDate--@endDate
															AND lit.IsRent = 1
															AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
															AND t.ReversesTransactionID IS NULL
															AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))

	UPDATE #units SET RentDelinquency = ActualRent
	UPDATE #units SET GainToLeaseDelinquency = GainToLease

	UPDATE #units SET ActualRent = ActualRent - LossToLease + GainToLease

	-- Get vacancy loss that was applied to rent											
	UPDATE #units SET VacancyLoss = (SELECT ISNULL(SUM(t.Amount), 0)
											FROM [Transaction] t									    
											INNER JOIN [Transaction] ta ON ta.TransactionID = t.AppliesToTransactionID
											INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
											LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID	
											LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID											
											INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = t.PropertyID
											WHERE t.ObjectID = #units.UnitID
												-- Transaction is in the given month
												AND t.TransactionDate >= #pad.StartDate--@startDate
												AND t.TransactionDate <= #pad.EndDate--@endDate
												-- Applied to a transaction in the given month
												AND ta.TransactionDate >= #pad.StartDate--@startDate
												AND ta.TransactionDate <= #pad.EndDate--@endDate
												-- Applied to a rent transaction
												AND alit.IsRent = 1				
												-- Transaction isn't reversed								
												AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)	
												AND t.ReversesTransactionID IS NULL	
												AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1))																				
												AND t.LedgerItemTypeID IN (SELECT us.StatusLedgerItemTypeID
																		   FROM UnitStatus us
																		   WHERE us.AccountID = @accountID))
			
	-- Get credits that were applied to rent											
	UPDATE #units SET Credits = (SELECT ISNULL(SUM(t.Amount), 0)
											FROM [Transaction] t
											INNER JOIN [TransactionType] tt on t.TransactionTypeID = tt.TransactionTypeID
											-- Join in applied to rent transactions
											INNER JOIN [Transaction] ta ON t.AppliesToTransactionID = ta.TransactionID
											INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = t.ObjectID
											LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID											
											INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
											LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID	
											LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID
											INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = t.PropertyID										
											WHERE ulg.UnitID = #units.UnitID
												-- Transaction is in the given month
												AND t.TransactionDate >= #pad.StartDate--@startDate
												AND t.TransactionDate <= #pad.EndDate--@endDate
												-- Applied to a transaction in the given month
												AND ta.TransactionDate >= #pad.StartDate--@startDate
												AND ta.TransactionDate <= #pad.EndDate--@endDate
												-- Credit transaction
												AND tt.Name = 'Credit'
													-- If a balance transferred credit is applied to a rent charge then the ledger item
													-- type will be null
												AND (lit.IsCredit = 1 OR lit.LedgerItemTypeID IS NULL)
												-- But not loss to lease
												AND lit.LedgerItemTypeID <> @lossToLeaseLedgerItemTypeID
												-- Applied to rent
												AND (alit.IsRent = 1 OR alit.LedgerItemTypeID = @gainToLeaseLedgerItemTypeID)
												-- Transaction isn't reversed								
												AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
												AND t.ReversesTransactionID IS NULL
												AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))

	UPDATE #units SET RentCollected = (SELECT ISNULL(SUM(t.Amount), 0)
										FROM [Transaction] t
										INNER JOIN [TransactionType] tt on t.TransactionTypeID = tt.TransactionTypeID
										-- Join in applied to rent transactions
										INNER JOIN [Transaction] ta ON t.AppliesToTransactionID = ta.TransactionID
										INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = t.ObjectID
										--INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
										INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
										LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
										LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID	
										INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = t.PropertyID										
										WHERE ulg.UnitID = #units.UnitID
											-- Transaction is in the given month
											AND t.TransactionDate >= #pad.StartDate--@startDate
											AND t.TransactionDate <= #pad.EndDate--@endDate
											-- Applied to a transaction in the given month
											AND ta.TransactionDate >= #pad.StartDate--@startDate
											AND ta.TransactionDate <= #pad.EndDate--@endDate
											-- Payment transaction											
											--AND lit.IsPayment = 1
											AND tt.Name = 'Payment'
											-- Applied to rent
											AND (alit.IsRent = 1 OR alit.LedgerItemTypeID = @gainToLeaseLedgerItemTypeID)
											AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
											AND t.ReversesTransactionID IS NULL
											AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))		
																												
	UPDATE #units SET RentDelinquency = RentDelinquency - (SELECT ISNULL(SUM(t.Amount), 0)
															FROM [Transaction] t
															-- Join in applied to rent transactions
															INNER JOIN [Transaction] ta ON t.AppliesToTransactionID = ta.TransactionID
															INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = t.ObjectID
															LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
															INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
															LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
															LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID		
															INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = t.PropertyID									
															WHERE ulg.UnitID = #units.UnitID
																-- Transaction is in the given month
																AND t.TransactionDate >= #pad.StartDate--@startDate
																AND t.TransactionDate <= #pad.EndDate--@endDate
																-- Applied to a transaction in the given month
																AND ta.TransactionDate >= #pad.StartDate--@startDate
																AND ta.TransactionDate <= #pad.EndDate--@endDate
																-- Credit transaction
																	-- If a deposit is applied to a rent charge the ledger item
																	-- type will be null											
																AND (lit.IsCredit = 1 OR lit.IsPayment = 1 OR lit.LedgerItemTypeID IS NULL)															
																-- Applied to rent
																AND (alit.IsRent = 1 AND alit.LedgerItemTypeID <> @gainToLeaseLedgerItemTypeID)
																AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
																AND t.ReversesTransactionID IS NULL
																AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))		
																
	UPDATE #units SET GainToLeaseDelinquency = GainToLeaseDelinquency - (SELECT ISNULL(SUM(t.Amount), 0)
																		FROM [Transaction] t
																		-- Join in applied to rent transactions
																		INNER JOIN [Transaction] ta ON t.AppliesToTransactionID = ta.TransactionID
																		INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = t.ObjectID
																		LEFT JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
																		INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
																		LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
																		LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID	
																		INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = t.PropertyID										
																		WHERE ulg.UnitID = #units.UnitID
																			-- Transaction is in the given month
																			AND t.TransactionDate >= #pad.StartDate--@startDate
																			AND t.TransactionDate <= #pad.EndDate--@endDate
																			-- Applied to a transaction in the given month
																			AND ta.TransactionDate >= #pad.StartDate--@startDate
																			AND ta.TransactionDate <= #pad.EndDate--@endDate
																			-- Credit transaction	
																				-- If a deposit is applied to a gain to lease charge the ledger item
																				-- type will be null															
																			AND (lit.IsCredit = 1 OR lit.IsPayment = 1 OR lit.LedgerItemTypeID IS NULL)															
																			-- Applied to rent
																			AND alit.LedgerItemTypeID = @gainToLeaseLedgerItemTypeID
																			AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
																			AND t.ReversesTransactionID IS NULL
																			AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))																											
	-- Update vacancy loss delinquency
	UPDATE #units SET RentDelinquency = RentDelinquency - (SELECT ISNULL(SUM(t.Amount), 0)
															FROM [Transaction] t
															-- Join in applied to rent transactions
															INNER JOIN [Transaction] ta ON t.AppliesToTransactionID = ta.TransactionID														
															INNER JOIN LedgerItemType lit ON lit.LedgerItemTypeID = t.LedgerItemTypeID
															INNER JOIN LedgerItemType alit ON alit.LedgerItemTypeID = ta.LedgerItemTypeID
															LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
															LEFT JOIN [PostingBatch] pb ON pb.PostingBatchID = t.PostingBatchID											
															INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = t.PropertyID
															WHERE t.ObjectID = #units.UnitID
																-- Transaction is in the given month
																AND t.TransactionDate >= #pad.StartDate--@startDate
																AND t.TransactionDate <= #pad.EndDate--@endDate
																-- Applied to a transaction in the given month
																AND ta.TransactionDate >= #pad.StartDate--@startDate
																AND ta.TransactionDate <= #pad.EndDate--@endDate
																-- Credit transaction											
																AND (lit.IsCredit = 1 OR lit.IsPayment = 1)															
																-- Applied to rent
																AND alit.IsRent = 1
																AND (tr.TransactionID IS NULL OR tr.TransactionDate > #pad.EndDate)
																AND t.ReversesTransactionID IS NULL
																AND ((pb.PostingBatchID IS NULL) OR (pb.IsPosted = 1)))

	UPDATE #units SET UnitLeaseGroupID = (SELECT TOP 1 UnitLeaseGroupID
								   FROM	(SELECT TOP 100000 Accounts.* -- Hack to be able to use ORDER BY in a sub query
										  -- Get all the move in and move out dates for each account for the properties defined
										  FROM	(SELECT ulg.UnitID,		
													  ulg.UnitLeaseGroupID,							  
													  MIN(pl.MoveInDate) AS 'MoveInDate', 
													  MAX(pl.MoveOutDate) AS 'MoveOutDate',
													  (SELECT COUNT(*) FROM PersonLease WHERE LeaseID = l.LeaseID AND MoveOutDate IS NULL) AS 'NoMoveOut',
													  #pad.PropertyID
												   FROM Lease l
												   INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID							   							   
												   INNER JOIN Unit u ON u.UnitID = ulg.UnitID
												   INNER JOIN Building b ON b.BuildingID = u.BuildingID
												   INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID		
												   INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = b.PropertyID					   
												   WHERE l.LeaseStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted')
													AND pl.ResidencyStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted')																					
												   GROUP BY ulg.UnitID, ulg.UnitLeaseGroupID, l.LeaseID, #pad.PropertyID) AS Accounts
												   INNER JOIN #PropertiesAndDates #pad2 on #pad2.PropertyID = Accounts.PropertyID
											-- Limit the accounts so that the mov ein date is before the end date
											-- and there is no move out date or the move out date is after the end date
											WHERE MoveInDate <= #pad2.EndDate AND (MoveOutDate IS NULL OR NoMoveOut > 0 OR MoveOutDate >= #pad2.EndDate)
											ORDER BY MoveInDate DESC) AS LimitedAccounts
									WHERE LimitedAccounts.UnitID = #units.UnitID)								

	INSERT INTO #Residents
		SELECT #units.UnitLeaseGroupID,
				l.LeaseID,
				l.LeaseStartDate,
				l.LeaseEndDate,
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						FROM Person 
							INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID							
						WHERE PersonLease.LeaseID = l.LeaseID
							AND PersonLease.MainContact = 1
						FOR XML PATH ('')), 1, 2, '') AS 'Name'
		FROM Lease l
			INNER JOIN #units on #units.UnitLeaseGroupID = l.UnitLeaseGroupID
			INNER JOIN #PropertiesAndDates #pad on #pad.PropertyID = #units.PropertyID
			WHERE  l.LeaseID = (SELECT TOP 1 l2.LeaseID
								 FROM Lease l2
								 WHERE l2.UnitLeaseGroupID = l.UnitLeaseGroupID
									AND l2.LeaseStartDate <= #pad.EndDate
								 ORDER BY l2.LeaseStartDate DESC)													
								
	SELECT 
		#units.PropertyName, 
		#units.UnitNumber, 
		#units.UnitType,
		#units.SquareFeet,
		#Residents.Residents,
		#Residents.LeaseID,
		#Residents.LeaseStartDate,
		#Residents.LeaseEndDate,
		#units.MarketRent, 
		#units.LossToLease, 
		#units.GainToLease, 
		#units.ActualRent, 
		#units.VacancyLoss,
		#units.Credits,
		#units.RentCollected,
		#units.RentDelinquency,
		#units.GainToLeaseDelinquency
	FROM #units 
		LEFT JOIN #Residents ON #Residents.UnitLeaseGroupID = #units.UnitLeaseGroupID
	ORDER BY PaddedNumber
END




GO
