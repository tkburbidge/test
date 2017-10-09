SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: July 30, 2015
-- Description:	Gets the data for the Wehner custom daily report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_WNR_DailyReport] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@date date = null,
	@propertyIDs GuidCollection READONLY
AS

declare @lastMTD date = DATEADD(MONTH, -1, @date)

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #Properties (
		PropertyID uniqueidentifier not null,
		Name nvarchar(MAX) null,
		Abbreviation nvarchar(MAX) null,
		DefaultAPBankAccountID uniqueidentifier null,
		MonthStartDate date null,
		MonthEndDate date null,
		PreviousMonthStartDate date null)
		
	CREATE TABLE #WehnersAndPonyTails (
		PropertyID uniqueidentifier not null,
		Name nvarchar(MAX) null,
		Abbreviation nvarchar(MAX) null,
		TotalUnitCount int null,
		TotalOccupied int null,
		MonthRentRoll money null,
		LastMTDCollected money null,
		MonthCollected money null,
		MonthBadDebt money null,
		BadDebtUnits nvarchar(MAX),
		MonthDeliquent money null,
		MoveIns int null,
		MoveInUnits nvarchar(MAX),
		MoveOuts int null,
		MoveOutUnits nvarchar(MAX),
		Evictions int null,
		EvictionUnits nvarchar(MAX),
		PreLeased int null,
		PreLeasedUnits nvarchar(MAX),
		Vacant int null,
		VacantUnits nvarchar(MAX),
		MadeReady int null,
		MadeReadyUnits nvarchar(MAX),
		NotMadeReady int null,
		NotMadeReadyUnits nvarchar(MAX),
		NumberIncompleteWorkOrders int null
		)
		
	CREATE TABLE #NoPonyTailsInUnit (
		UnitID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		Number nvarchar(50) null,
		UnitStatus nvarchar(50) null
		)


    -- Insert statements for procedure here

	INSERT #Properties 
		SELECT pIDs.Value, prop.Name, prop.Abbreviation, prop.DefaultAPBankAccountID, pap.StartDate, pap.EndDate, papPrev.StartDate
			FROM @propertyIDs pIDs
				INNER JOIN Property prop ON pIDs.Value = prop.PropertyID
				INNER JOIN PropertyAccountingPeriod pap ON prop.PropertyID = pap.PropertyID
				INNER JOIN PropertyAccountingPeriod papPrev ON prop.PropertyID = papPrev.PropertyID
			WHERE pap.StartDate <= @date
			  AND pap.EndDate >= @date
			  AND papPrev.StartDate <= @lastMTD
			  AND papPrev.EndDate >= @lastMTD
				
	INSERT #WehnersAndPonyTails
		SELECT	PropertyID,
				Name,
				Abbreviation,
				null,				-- TotalUnitCount
				null,				-- TotalOccupied
				null,				-- MonthRentRoll
				null,				-- LastMTDCollected
				null,				-- MonthCollected
				null,				-- MonthBadDebt
				null,				-- BadDebtUnits
				null,				-- MonthDeliquent
				null,				-- MoveIns
				null,				-- MoveInUnits
				null,				-- MoveOuts
				null,				-- MoveOutUnits
				null,				-- Evictions
				null,				-- EvictionUnits
				null,				-- PreLeased
				null,				-- PreLeasedUnits
				null,				-- Vacant
				null,				-- VacantUnits
				null,				-- MadeReady
				null,				-- MadeReadyUnits
				null,				-- NotMadeReady
				null,				-- NotMadeReadyUnits
				null				-- NumberIncompleteWorkOrders
			FROM #Properties

	UPDATE #WehnersAndPonyTails SET TotalUnitCount = (SELECT COUNT(*)
														FROM #WehnersAndPonyTails #wpt
															INNER JOIN UnitType ut ON #wpt.PropertyID = ut.PropertyID
															INNER JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID
														WHERE u.IsHoldingUnit = 0
														  AND u.ExcludedFromOccupancy = 0
														  AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
														  AND ut.PropertyID = #WehnersAndPonyTails.PropertyID
														)
	
	UPDATE #WehnersAndPonyTails SET TotalOccupied = (SELECT COUNT(*)
														FROM #WehnersAndPonyTails #wpt
															INNER JOIN UnitType ut ON #wpt.PropertyID = ut.PropertyID
															INNER JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID
															INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
															INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')
														WHERE ut.PropertyID = #WehnersAndPonyTails.PropertyID
														GROUP BY ut.PropertyID)
														
	
	UPDATE #WehnersAndPonyTails SET MonthRentRoll = ISNULL((SELECT SUM(t.Amount)
																FROM [Transaction] t
																	INNER JOIN #Properties #p ON t.PropertyID = #p.PropertyID																																		
																	INNER JOIN TransactionType tt on tt.TransactionTypeID = t.TransactionTypeID
																WHERE t.TransactionDate >= #p.MonthStartDate
																  AND t.TransactionDate <= #p.MonthEndDate																  
																  AND t.PropertyID = #WehnersAndPonyTails.PropertyID
																  AND tt.[Group] = 'Lease'
																  AND tt.Name IN ('Charge')
																GROUP BY t.PropertyID), 0)

    UPDATE #WehnersAndPonyTails SET LastMTDCollected = ISNULL((SELECT SUM(t.Amount)
																FROM [Transaction] t
																	INNER JOIN #Properties #prop ON t.PropertyID = #prop.PropertyID
																	INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Deposit' AND tt.[Group] = 'Bank'
																	INNER JOIN BankTransactionTransaction btt ON t.TransactionID = btt.TransactionID
																	INNER JOIN BankTransaction bt ON btt.BankTransactionID = bt.BankTransactionID
																	INNER JOIN Batch bat ON bt.BankTransactionID = bat.BankTransactionID
																	INNER JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID AND ba.BankAccountID = #prop.DefaultAPBankAccountID
																	LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
																WHERE bat.[Date] >= #prop.PreviousMonthStartDate
																  AND bat.[Date] <= @lastMTD
																  AND tr.TransactionID IS NULL
																  AND t.PropertyID = #WehnersAndPonyTails.PropertyID
																GROUP BY t.PropertyID), 0)	
	
	UPDATE #WehnersAndPonyTails SET MonthCollected = ISNULL((SELECT SUM(t.Amount)
																FROM [Transaction] t
																	INNER JOIN #Properties #prop ON t.PropertyID = #prop.PropertyID
																	INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Deposit' AND tt.[Group] = 'Bank'
																	INNER JOIN BankTransactionTransaction btt ON t.TransactionID = btt.TransactionID
																	INNER JOIN BankTransaction bt ON btt.BankTransactionID = bt.BankTransactionID
																	INNER JOIN Batch bat ON bt.BankTransactionID = bat.BankTransactionID
																	INNER JOIN BankAccount ba ON t.ObjectID = ba.BankAccountID AND ba.BankAccountID = #prop.DefaultAPBankAccountID
																	LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
																WHERE bat.[Date] >= #prop.MonthStartDate
																  AND bat.[Date] <= #prop.MonthEndDate
																  AND tr.TransactionID IS NULL
																  AND t.PropertyID = #WehnersAndPonyTails.PropertyID
																GROUP BY t.PropertyID), 0)	

	CREATE TABLE #Accounts (		
		PropertyID uniqueidentifier,
		UnitLeaseGroupID uniqueidentifier,		
		UnitNumber nvarchar(100),
		LeaseStatus nvarchar(100),
		MonthEndDate date
	)

	CREATE TABLE #Balances (
		PropertyID uniqueidentifier,
		UnitLeaseGroupID uniqueidentifier,
		UnitNumber nvarchar(100),
		LeaseStatus nvarchar(100),
		Balance money		
	)

	INSERT INTO #Accounts
		SELECT 
		    b.PropertyID,
			ulg.UnitLeaseGroupID,
			u.Number,
			l.LeaseStatus,
			#p.MonthEndDate
		FROM UnitLeaseGroup ulg
			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
			INNER JOIN Building b ON b.BuildingID = u.BuildingID
			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN #Properties #p ON #p.PropertyID = b.PropertyID
		WHERE l.LeaseID = (SELECT TOP 1 l2.LeaseID
						   FROM Lease l2
							INNER JOIN Ordering o ON o.[Type] = 'Lease' AND o.Value = l2.LeaseStatus
						   WHERE l2.UnitLeaseGroupID = l.UnitLeaseGroupID
						   ORDER BY o.OrderBy)


	INSERT INTO #Balances
		SELECT #a.PropertyID, #a.UnitLeaseGroupID, #a.UnitNumber, #a.LeaseStatus, bal.Balance
		FROM #Accounts #a
		CROSS APPLY dbo.GetObjectBalance(null, #a.MonthEndDate, #a.UnitLeaseGroupID, 0, @propertyIDs) AS [Bal]

	UPDATE #WehnersAndPonyTails SET MonthBadDebt = ISNULL((SELECT SUM(Balance)
																FROM #Balances
																WHERE Balance > 0
																  AND #Balances.PropertyID = #WehnersAndPonyTails.PropertyID
																  AND #Balances.LeaseStatus = 'Under Eviction'
																GROUP BY #Balances.PropertyID), 0)

	UPDATE #WehnersAndPonyTails SET BadDebtUnits = (SELECT STUFF((SELECT ', ' + UnitNumber
																	  FROM #Balances
																	WHERE Balance > 0
																		AND #Balances.PropertyID = #WehnersAndPonyTails.PropertyID
																		AND #Balances.LeaseStatus = 'Under Eviction'
																	  FOR XML PATH ('')), 1, 2, ''))
														  
	UPDATE #WehnersAndPonyTails SET MonthDeliquent = ISNULL((SELECT SUM(Balance)
																FROM #Balances
																WHERE Balance > 0
																  AND #Balances.PropertyID = #WehnersAndPonyTails.PropertyID
																  AND #Balances.LeaseStatus <> 'Under Eviction'
																GROUP BY #Balances.PropertyID), 0)
													

	CREATE TABLE #ResidentActivity (
		[Type] nvarchar(100),
		PropertyID uniqueidentifier,			
		UnitID uniqueidentifier,
		Unit nvarchar(50),
		PaddedUnitNumber nvarchar(50),
		UnitLeaseGroupID uniqueidentifier,
		LeaseID uniqueidentifier,
		LeaseStatus nvarchar(100)
	)
	INSERT INTO #ResidentActivity
	SELECT DISTINCT 
				'MoveOut',
				p.PropertyID,					
				u.UnitID,
				u.Number,
				u.PaddedNumber,
				l.UnitLeaseGroupID,
				l.LeaseID,
				l.LeaseStatus
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON p.PropertyID = b.PropertyID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID		
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID										
				INNER JOIN #Properties #pad ON p.PropertyID = #pad.PropertyID				
			WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
									  FROM PersonLease pl2
									  WHERE pl2.LeaseID = l.LeaseID
										AND pl2.ResidencyStatus IN ('Former', 'Evicted')
									  ORDER BY pl2.MoveOutDate DESC, pl2.OrderBy, pl2.PersonID)		
			  AND pl.MoveOutDate >= #pad.MonthStartDate
			  AND pl.MoveOutDate <= #pad.MonthEndDate
			  AND pl.ResidencyStatus IN ('Former', 'Evicted')
			  AND l.LeaseStatus IN ('Former', 'Evicted')

	INSERT INTO #ResidentActivity
		SELECT DISTINCT 	
				'MoveIn' AS 'Type',					
				p.PropertyID,					
				u.UnitID,
				u.Number,
				u.PaddedNumber,			
				l.UnitLeaseGroupID,
				l.LeaseID,
				l.LeaseStatus				
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID		
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Property p ON p.PropertyID = b.PropertyID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID		
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID																		
				INNER JOIN #Properties #pad ON p.PropertyID = #pad.PropertyID				
			WHERE pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
									  FROM PersonLease pl2
									  WHERE pl2.LeaseID = l.LeaseID
										AND pl2.ResidencyStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
									  ORDER BY pl2.MoveInDate, pl2.OrderBy, pl2.PersonID)		
			  AND pl.MoveInDate >= #pad.MonthStartDate
			  AND pl.MoveInDate <= #pad.MonthEndDate
			  AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
			  AND l.LeaseStatus IN ('Current', 'Under Eviction', 'Renewed', 'Former', 'Evicted')
			  AND l.LeaseID = (SELECT TOP 1 LeaseID 
							   FROM Lease
							   WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID
									 AND LeaseStatus IN ('Current', 'Renewed', 'Former', 'Under Eviction', 'Evicted')
							   ORDER BY LeaseStartDate, DateCreated)	
							   																
	UPDATE #WehnersAndPonyTails SET MoveInUnits = (SELECT STUFF((SELECT ', ' + #r.Unit
																	FROM #ResidentActivity #r																		
																	WHERE #r.PropertyID = #WehnersAndPonyTails.PropertyID																	  
																		AND #r.[Type] = 'MoveIn'																		
																	ORDER BY #r.PaddedUnitNumber
																	FOR XML PATH ('')), 1, 2, ''))																	
														
	UPDATE #WehnersAndPonyTails SET MoveIns = (SELECT COUNT(*)
												FROM #ResidentActivity #r																		
												WHERE #r.PropertyID = #WehnersAndPonyTails.PropertyID																	  
													AND #r.[Type] = 'MoveIn')

	UPDATE #WehnersAndPonyTails SET MoveOutUnits = (SELECT STUFF((SELECT ', ' + #r.Unit
																	FROM #ResidentActivity #r																		
																	WHERE #r.PropertyID = #WehnersAndPonyTails.PropertyID																	  
																		AND #r.[Type] = 'MoveOut'
																		AND #r.LeaseStatus = 'Former'
																	ORDER BY #r.PaddedUnitNumber
																	FOR XML PATH ('')), 1, 2, ''))																	
														
	UPDATE #WehnersAndPonyTails SET MoveOuts = (SELECT COUNT(*)
												FROM #ResidentActivity #r																		
												WHERE #r.PropertyID = #WehnersAndPonyTails.PropertyID																	  
													AND #r.[Type] = 'MoveOut'
													AND #r.LeaseStatus = 'Former')
																	
														  
																
	UPDATE #WehnersAndPonyTails SET EvictionUnits = (SELECT STUFF((SELECT ', ' + #r.Unit
																	FROM #ResidentActivity #r																		
																	WHERE #r.PropertyID = #WehnersAndPonyTails.PropertyID																	  
																		AND #r.[Type] = 'MoveOut'
																		AND #r.LeaseStatus = 'Evicted'
																	ORDER BY #r.PaddedUnitNumber
																	FOR XML PATH ('')), 1, 2, ''))																	
														
	UPDATE #WehnersAndPonyTails SET Evictions = (SELECT COUNT(*)
												FROM #ResidentActivity #r																		
												WHERE #r.PropertyID = #WehnersAndPonyTails.PropertyID																	  
													AND #r.[Type] = 'MoveOut'
													AND #r.LeaseStatus = 'Evicted')
													  
	UPDATE #WehnersAndPonyTails SET PreLeased = (SELECT COUNT(DISTINCT l.LeaseID)
													FROM #Properties #prop
														INNER JOIN UnitType ut ON #prop.PropertyID = ut.PropertyID
														INNER JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID
														INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
														INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Pending', 'Pending Transfer')
														INNER JOIN [Transaction] t ON ulg.UnitLeaseGroupID = t.ObjectID AND t.AppliesToTransactionID IS NOT NULL
													WHERE #prop.PropertyID = #WehnersAndPonyTails.PropertyID)
														  													  										
	UPDATE #WehnersAndPonyTails SET PreLeasedUnits = (SELECT STUFF((SELECT DISTINCT ', ' + u1.Number
																	FROM Unit u1
																		INNER JOIN UnitType ut1 ON u1.UnitTypeID = ut1.UnitTypeID
																		INNER JOIN #Properties #prop ON ut1.PropertyID = #prop.PropertyID
																		INNER JOIN UnitLeaseGroup ulg ON u1.UnitID = ulg.UnitID
																		INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Pending', 'Pending Transfer')
																		INNER JOIN [Transaction] t ON ulg.UnitLeaseGroupID = t.ObjectID AND t.AppliesToTransactionID IS NOT NULL
																	WHERE ut1.PropertyID = #WehnersAndPonyTails.PropertyID
																	FOR XML PATH ('')), 1, 2, ''))

															
	INSERT #NoPonyTailsInUnit	
		SELECT u.UnitID, #prop.PropertyID, u.Number, [PonyTailStatus].[Status]
			FROM #Properties #prop
				INNER JOIN UnitType ut ON #prop.PropertyID = ut.PropertyID
				INNER JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID AND u.ExcludedFromOccupancy = 0 AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
				CROSS APPLY dbo.GetUnitStatusByUnitID(u.UnitID, @date) AS [PonyTailStatus]
				LEFT JOIN (SELECT NEWID() AS 'MyVacantUnitsID', u1.UnitID, u1.Number
								FROM Unit u1
									INNER JOIN UnitLeaseGroup ulg1 ON u1.UnitID = ulg1.UnitID
									INNER JOIN Lease l1 ON ulg1.UnitLeaseGroupID = l1.UnitLeaseGroupID AND l1.LeaseStatus IN ('Current', 'Under Eviction')) [VacUnits] ON u.UnitID = [VacUnits].UnitID
			WHERE [vacUnits].MyVacantUnitsID IS NULL
			
	UPDATE #WehnersAndPonyTails SET Vacant = (SELECT COUNT(*)
												  FROM #NoPonyTailsInUnit
												  WHERE PropertyID = #WehnersAndPonyTails.PropertyID
												  GROUP BY PropertyID)
												  
	UPDATE #WehnersAndPonyTails SET VacantUnits = (SELECT STUFF((SELECT ', ' + Number
																	FROM #NoPonyTailsInUnit
																	WHERE PropertyID = #WehnersAndPonyTails.PropertyID
																	ORDER BY Number
																	FOR XML PATH ('')), 1, 2, ''))

	
	UPDATE #WehnersAndPonyTails SET MadeReady = (SELECT COUNT(*)
													FROM #NoPonyTailsInUnit
													WHERE [UnitStatus] IN ('Ready')
													  AND PropertyID = #WehnersAndPonyTails.PropertyID
													GROUP BY PropertyID)
													
	UPDATE #WehnersAndPonyTails SET MadeReadyUnits = (SELECT STUFF((SELECT ', ' + Number
														FROM #NoPonyTailsInUnit
														WHERE [UnitStatus] IN ('Ready')
														  AND PropertyID = #WehnersAndPonyTails.PropertyID
														ORDER BY Number
														FOR XML PATH ('')), 1, 2, ''))														  
													
	UPDATE #WehnersAndPonyTails SET NotMadeReady = (SELECT COUNT(*)
													FROM #NoPonyTailsInUnit
													WHERE [UnitStatus] NOT IN ('Ready')
													  AND PropertyID = #WehnersAndPonyTails.PropertyID
													GROUP BY PropertyID)	
													
	UPDATE #WehnersAndPonyTails SET NotMadeReadyUnits = (SELECT STUFF((SELECT ', ' + Number
															FROM #NoPonyTailsInUnit
															WHERE [UnitStatus] NOT IN ('Ready')
															  AND PropertyID = #WehnersAndPonyTails.PropertyID															
															ORDER BY Number
															FOR XML PATH ('')), 1, 2, ''))	
															
	UPDATE #WehnersAndPonyTails SET NumberIncompleteWorkOrders = (SELECT COUNT(DISTINCT wo.WorkOrderID)
																	  FROM WorkOrder wo
																	  WHERE wo.PropertyID = #WehnersAndPonyTails.PropertyID
																	    AND wo.ReportedDate <= @date
																		AND ((wo.CompletedDate IS NULL OR wo.CompletedDate > @date) OR (wo.[Status] = 'Cancelled' AND wo.CancellationDate > @date))
																		AND wo.[Status] NOT IN ('On Hold'))																																							  																				  
														  													  		
	SELECT 
		PropertyID,
		Name,
		Abbreviation,
		ISNULL(TotalUnitCount, 0) AS TotalUnitCount,
		ISNULL(TotalOccupied, 0) AS TotalOccupied,
		ISNULL(MonthRentRoll, 0) AS MonthRentRoll,
		ISNULL(LastMTDCollected, 0) AS LastMTDCollected,
		ISNULL(MonthCollected, 0) AS MonthCollected,
		ISNULL(MonthBadDebt, 0) AS MonthBadDebt,
		BadDebtUnits,
		ISNULL(MonthDeliquent, 0) AS MonthDeliquent,
		ISNULL(MoveIns , 0) AS MoveIns,
		MoveInUnits,
		ISNULL(MoveOuts , 0) AS MoveOuts,
		MoveOutUnits,
		ISNULL(Evictions , 0) AS Evictions,
		EvictionUnits,
		ISNULL(PreLeased , 0) AS PreLeased,
		PreLeasedUnits,
		ISNULL(Vacant , 0) AS Vacant,
		VacantUnits,
		ISNULL(MadeReady , 0) AS MadeReady,
		MadeReadyUnits,
		ISNULL(NotMadeReady , 0) AS NotMadeReady,
		NotMadeReadyUnits,
		NumberIncompleteWorkOrders
	 FROM #WehnersAndPonyTails
	 ORDER BY Name


END

GO
