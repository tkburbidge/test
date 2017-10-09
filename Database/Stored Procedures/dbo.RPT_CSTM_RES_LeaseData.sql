SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[RPT_CSTM_RES_LeaseData]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@startDate date,
	@endDate date,
	@accountingPeriodID uniqueidentifier = null,
	@statuses StringCollection READONLY,
	@filters StringCollection READONLY,
	@fields StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    
	CREATE TABLE #PropertiesAndDates (	
		PropertyID uniqueidentifier not null,
		StartDate date null,
		EndDate date null)

	INSERT #PropertiesAndDates 
		SELECT pIDs.Value, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM @propertyIDs pIDs
				LEFT JOIN PropertyAccountingPeriod pap ON pIDs.Value = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID


	CREATE TABLE #AllLeases (
		PropertyID uniqueidentifier,
		UnitLeaseGroupID uniqueidentifier,	
		UnitID uniqueidentifier,	
		ApplicationDate date,
		MoveInDate date,
		NoticeToVacateDate date,
		MoveOutDate date,	
		IsMovedOut bit,
		FirstLeaseID uniqueidentifier,
		LastLeaseID uniqueidentifier,
		DidLiveAtProperty bit
	)


	CREATE TABLE #FilteredLeases (
		PropertyID uniqueidentifier,	
		UnitLeaseGroupID uniqueidentifier,
		UnitID uniqueidentifier,
		ApplicationDate date,
		MoveInDate date,
		NoticeToVacateDate date,
		MoveOutDate date,	
		IsMovedOut bit,
		FirsLeaseID uniqueidentifier,
		LastLeaseID uniqueidentifier,
		DidLiveAtProperty bit,
		RecordType nvarchar(100)
	)

	INSERT INTO #AllLeases
		-- Add everyone who actually lived at the property
		SELECT DISTINCT
					b.PropertyID,
					ulg.UnitLeaseGroupID,
					u.UnitID,				
					MIN(pl.ApplicationDate) AS 'ApplicationDate',
					-- Get the minimum move in date for all people
					-- tied to the UnitLeaseGroup. We don't care what status, just
					-- that they lived there
					MIN(pl.MoveInDate) AS 'MoveInDate',
					-- If everyone on the last lease has a move out date then set
					-- the NTV Date to the max NoticeGivenDate for all the people tied to that lease
					CASE WHEN plmo.PersonLeaseID IS NULL THEN MAX(lastPersonLease.NoticeGivenDate) ELSE NULL END AS 'NoticeToVacateDate',
					-- If everyone on the last lease has a move out date then set
					-- the move out date tot he max move out date for all the people tied to that lease
					CASE WHEN plmo.PersonLeaseID IS NULL THEN MAX(lastPersonLease.MoveOutDate) ELSE NULL END AS 'MoveOutDate',
					-- If there exists a Former or Evicted lease then the residents actually moved out
					-- and we then know that the MoveOutDate is a legitmate hard move out date. Othewise,
					-- the move out date is just an intended move out date.
					CASE WHEN fl.LeaseID IS NULL THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS 'IsMovedOut',
					firstLease.LeaseID AS 'FirstLeaseID',
					lastLease.LeaseID AS 'LastLeaseID',
					CAST(1 AS BIT) AS 'DidLiveAtProperty'							
				FROM UnitLeaseGroup ulg
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = b.PropertyID
				INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				LEFT JOIN Lease fl ON fl.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND fl.LeaseStatus IN ('Former', 'Evicted')
				-- Get the last lease, oldest end date
				INNER JOIN Lease lastLease ON lastLease.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND lastLease.LeaseID = (SELECT TOP 1 LeaseID 
																														 FROM Lease 
																														 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
																															AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed', 'Pending Renewal') 
																														 ORDER BY LeaseEndDate DESC, DateCreated DESC)
				-- Get the first lease, earliest start date
				INNER JOIN Lease firstLease ON lastLease.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND firstLease.LeaseID = (SELECT TOP 1 LeaseID 
																														 FROM Lease 
																														 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
																															AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed', 'Pending Renewal') 
																														 ORDER BY LeaseStartDate DESC, DateCreated DESC)
				-- Get everyone on the last lease																													 
				INNER JOIN PersonLease lastPersonLease ON lastPersonLease.LeaseID = lastLease.LeaseID
				-- Someone on the last lease that hasn't given a move out date
				LEFT JOIN PersonLease plmo ON plmo.LeaseID = lastLease.LeaseID AND plmo.MoveOutDate IS NULL
				WHERE l.LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed') -- Only deal with actually occupying lease statuses
					AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed') -- Don't get move in date from Pending, Denied, or Cancelled
					AND u.AccountID = @accountID
					AND u.ExcludedFromOccupancy = 0
					AND (u.DateRemoved IS NULL OR u.DateRemoved > #pads.EndDate)
					AND u.IsHoldingUnit = 0
				GROUP BY b.PropertyID, ulg.UnitLeaseGroupID, lastLease.LeaseID, firstLease.LeaseID, u.UnitID, u.Number, u.PaddedNumber, fl.LeaseID, plmo.PersonLeaseID

	--INSERT INTO #AllLeases
	--	-- Add everyone who actually lived at the property
	--	SELECT DISTINCT
	--				b.PropertyID,
	--				ulg.UnitLeaseGroupID,
	--				u.UnitID,				
	--				MIN(pl.ApplicationDate) AS 'ApplicationDate',
	--				-- Get the minimum move in date for all people
	--				-- tied to the UnitLeaseGroup. We don't care what status, just
	--				-- that they lived there
	--				MIN(pl.MoveInDate) AS 'MoveInDate',
	--				-- If everyone on the last lease has a move out date then set
	--				-- the NTV Date to the max NoticeGivenDate for all the people tied to that lease
	--				CASE WHEN plmo.PersonLeaseID IS NULL THEN MAX(lastPersonLease.NoticeGivenDate) ELSE NULL END AS 'NoticeToVacateDate',
	--				-- If everyone on the last lease has a move out date then set
	--				-- the move out date tot he max move out date for all the people tied to that lease
	--				CASE WHEN plmo.PersonLeaseID IS NULL THEN MAX(lastPersonLease.MoveOutDate) ELSE NULL END AS 'MoveOutDate',
	--				-- If there exists a Former or Evicted lease then the residents actually moved out
	--				-- and we then know that the MoveOutDate is a legitmate hard move out date. Othewise,
	--				-- the move out date is just an intended move out date.
	--				CASE WHEN fl.LeaseID IS NULL THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS 'IsMovedOut',
	--				firstLease.LeaseID AS 'FirstLeaseID',
	--				lastLease.LeaseID AS 'LastLeaseID',
	--				CAST(0 AS BIT) AS 'DidLiveAtProperty'							
	--			FROM UnitLeaseGroup ulg
	--			INNER JOIN Unit u ON u.UnitID = ulg.UnitID
	--			INNER JOIN Building b ON b.BuildingID = u.BuildingID
	--			INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = b.PropertyID
	--			INNER JOIN Lease l ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--			INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
	--			LEFT JOIN Lease fl ON fl.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND fl.LeaseStatus IN ('Cancelled', 'Denied')
	--			-- Get the last lease, oldest end date
	--			INNER JOIN Lease lastLease ON lastLease.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND lastLease.LeaseID = (SELECT TOP 1 LeaseID 
	--																													 FROM Lease 
	--																													 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 																														
	--																													 ORDER BY LeaseEndDate DESC, DateCreated DESC)
	--			-- Get the first lease, earliest start date
	--			INNER JOIN Lease firstLease ON lastLease.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND firstLease.LeaseID = (SELECT TOP 1 LeaseID 
	--																													 FROM Lease 
	--																													 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
	--																														AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed', 'Pending Renewal') 
	--																													 ORDER BY LeaseStartDate DESC, DateCreated DESC)
	--			-- Get everyone on the last lease																													 
	--			INNER JOIN PersonLease lastPersonLease ON lastPersonLease.LeaseID = lastLease.LeaseID
	--			-- Someone on the last lease that hasn't given a move out date
	--			LEFT JOIN PersonLease plmo ON plmo.LeaseID = lastLease.LeaseID AND plmo.MoveOutDate IS NULL
	--			LEFT JOIN #AllLeases #al ON #al.UnitLeaseGroupID = ulg.UnitLeaseGroupID
	--			WHERE
	--				-- Get all lease statuses but this will only return UnitLeaseGroups where there wasn't one
	--				-- of the below lease statuses which means there was only a Pending, Cancelled, Denied lease
	--				-- on the UnitLeaseGroup 
	--				--l.LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed') -- Only deal with actually occupying lease statuses
	--				--AND pl.ResidencyStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed') -- Don't get move in date from Pending, Denied, or Cancelled
	--				 u.AccountID = @accountID
	--				AND u.ExcludedFromOccupancy = 0
	--				AND u.IsHoldingUnit = 0
	--				AND #al.UnitLeaseGroupID IS NULL
	--			GROUP BY b.PropertyID, ulg.UnitLeaseGroupID, lastLease.LeaseID, firstLease.LeaseID, u.UnitID, u.Number, u.PaddedNumber, fl.LeaseID, plmo.PersonLeaseID


	IF (EXISTS(SELECT * FROM @filters WHERE Value = 'MoveInDate'))
	BEGIN
		INSERT INTO #FilteredLeases
			SELECT #al.*, 'MoveIn'
			FROM #AllLeases #al
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #al.PropertyID
			WHERE  #al.DidLiveAtProperty = 1 
				AND #al.MoveInDate >= #pad.StartDate 
				AND #al.MoveInDate <= #pad.EndDate
			
	END

	IF (EXISTS(SELECT * FROM @filters WHERE Value = 'MoveOutDate'))
	BEGIN
		INSERT INTO #FilteredLeases
			SELECT #al.*, 'MoveOut'
			FROM #AllLeases #al
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #al.PropertyID
			WHERE  #al.DidLiveAtProperty = 1 
				AND #al.IsMovedOut = 1
				AND #al.MoveOutDate >= #pad.StartDate 
				AND #al.MoveOutDate <= #pad.EndDate
			
	END

	IF (EXISTS(SELECT * FROM @filters WHERE Value = 'NoticeToVacateDate'))
	BEGIN
		INSERT INTO #FilteredLeases
			SELECT #al.*, 'NoticeToVacate'
			FROM #AllLeases #al
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #al.PropertyID
			WHERE  #al.DidLiveAtProperty = 1 
				AND #al.NoticeToVacateDate >= #pad.StartDate 
				AND #al.NoticeToVacateDate <= #pad.EndDate
			
	END

	

	DELETE FROM #AllLeases

	INSERT INTO #AllLeases
		-- Add everyone who actually lived at the property
		SELECT DISTINCT
					b.PropertyID,
					ulg.UnitLeaseGroupID,
					u.UnitID,				
					MIN(pl.ApplicationDate) AS 'ApplicationDate',
					-- Get the minimum move in date for all people
					-- tied to the UnitLeaseGroup. We don't care what status, just
					-- that they lived there
					MIN(pl.MoveInDate) AS 'MoveInDate',
					-- If everyone on the last lease has a move out date then set
					-- the NTV Date to the max NoticeGivenDate for all the people tied to that lease
					CASE WHEN plmo.PersonLeaseID IS NULL THEN MAX(pl.NoticeGivenDate) ELSE NULL END AS 'NoticeToVacateDate',
					-- If everyone on the last lease has a move out date then set
					-- the move out date tot he max move out date for all the people tied to that lease
					CASE WHEN plmo.PersonLeaseID IS NULL THEN MAX(pl.MoveOutDate) ELSE NULL END AS 'MoveOutDate',
					-- If there exists a Former or Evicted lease then the residents actually moved out
					-- and we then know that the MoveOutDate is a legitmate hard move out date. Othewise,
					-- the move out date is just an intended move out date.
					CASE WHEN l.LeaseID IS NULL THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS 'IsMovedOut',					
					l.LeaseID AS 'FirstLeaseID',
					l.LeaseID AS 'LastLeaseID',
					CAST(0 AS BIT) AS 'DidLiveAtProperty'							
				FROM Lease l 
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN Unit u ON u.UnitID = ulg.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN #PropertiesAndDates #pads ON #pads.PropertyID = b.PropertyID
				
				INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID
				--LEFT JOIN Lease fl ON fl.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND fl.LeaseStatus IN ('Cancelled', 'Denied')
				---- Get the last lease, oldest end date
				--INNER JOIN Lease lastLease ON lastLease.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND lastLease.LeaseID = (SELECT TOP 1 LeaseID 
				--																										 FROM Lease 
				--																										 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 																														
				--																										 ORDER BY LeaseEndDate DESC, DateCreated DESC)
				---- Get the first lease, earliest start date
				--INNER JOIN Lease firstLease ON lastLease.UnitLeaseGroupID = ulg.UnitLeaseGroupID AND firstLease.LeaseID = (SELECT TOP 1 LeaseID 
				--																										 FROM Lease 
				--																										 WHERE UnitLeaseGroupID = ulg.UnitLeaseGroupID 
				--																											AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed', 'Pending Renewal') 
				--																										 ORDER BY LeaseStartDate DESC, DateCreated DESC)
				---- Get everyone on the last lease																													 
				--INNER JOIN PersonLease lastPersonLease ON lastPersonLease.LeaseID = lastLease.LeaseID
				-- Someone on the last lease that hasn't given a move out date
				LEFT JOIN PersonLease plmo ON plmo.LeaseID = l.LeaseID AND plmo.MoveOutDate IS NULL
				WHERE
					u.AccountID = @accountID
					AND u.ExcludedFromOccupancy = 0
					AND (u.DateRemoved IS NULL OR u.DateRemoved > #pads.EndDate)
					AND u.IsHoldingUnit = 0					
				GROUP BY b.PropertyID, ulg.UnitLeaseGroupID, l.LeaseID, u.UnitID, u.Number, u.PaddedNumber, plmo.PersonLeaseID


	IF (EXISTS(SELECT * FROM @filters WHERE Value = 'ApplicationDate'))
	BEGIN
		INSERT INTO #FilteredLeases
			SELECT #al.*, 'ApplicationDate'
			FROM #AllLeases #al
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #al.PropertyID
			WHERE  #al.ApplicationDate >= #pad.StartDate 
				AND #al.ApplicationDate <= #pad.EndDate
			
	END

	IF (EXISTS(SELECT * FROM @filters WHERE Value = 'LeaseStartDate'))
	BEGIN
		INSERT INTO #FilteredLeases
			SELECT #al.*, 'LeaseStart'
			FROM #AllLeases #al
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #al.PropertyID
				INNER JOIN Lease l ON l.LeaseID = #al.FirstLeaseID
			WHERE  l.LeaseStartDate >= #pad.StartDate 
				AND l.LeaseStartDate <= #pad.EndDate
			
	END

	IF (EXISTS(SELECT * FROM @filters WHERE Value = 'LeaseEndDate'))
	BEGIN
		INSERT INTO #FilteredLeases
			SELECT #al.*, 'LeaseEnd'
			FROM #AllLeases #al
				INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #al.PropertyID
				INNER JOIN Lease l ON l.LeaseID = #al.FirstLeaseID
			WHERE  l.LeaseEndDate >= #pad.StartDate 
				AND l.LeaseEndDate <= #pad.EndDate			
	END

		
	CREATE TABLE #LeaseData (
		PropertyID uniqueidentifier,
		StartDate date,
		EndDate date,
		UnitLeaseGroupID uniqueidentifier,
		LeaseID uniqueidentifier,	
		RecordType nvarchar(100),
		UnitID uniqueidentifier,
		UnitNumber nvarchar(100),
		PaddedUnitNumber nvarchar(100),
		ResidentNames nvarchar(500),
		ApplicationDate date,
		LeaseStartDate date,
		LeaseEndDate date,
		MoveInDate date,
		NoticeToVacateDate date,
		MoveOutDate date,
		LeaseStatus nvarchar(100),
		Balance money,
		LeaseRequiredDeposit money,
		DepositPaidIn money,
		MarketRentAtMoveIn money,
		MarketRentAtReportEnd money,
		MarketRentAtToday money,
		ActualRent money,	
		PhoneNumber nvarchar(100),
		Email nvarchar(256),
		MainContactName nvarchar(256),
		MoveOutReason nvarchar(256),
		AppliedOnline bit,
		LeaseExpirationLimit smallint,
		ProspectID uniqueidentifier null,
		LeasingAgent nvarchar(100) null
	)

	INSERT INTO #LeaseData
		SELECT
			#fl.PropertyID,
			#pad.StartDate,
			#pad.EndDate,
			#fl.UnitLeaseGroupID,
			(CASE WHEN #fl.RecordType IN ( 'MoveIn', 'ApplicationDate', 'LeaseStart', 'LeaseEnd' ) THEN #fl.FirsLeaseID
				  WHEN #fl.RecordType IN ( 'MoveOut', 'NoticeToVacate' ) THEN #fl.LastLeaseID
			 END) AS 'LeaseID',
			#fl.RecordType AS 'RecordType',
			u.UnitID,
			u.Number,
			u.PaddedNumber,
			null,
			#fl.ApplicationDate,
			l.LeaseStartDate,
			l.LeaseEndDate,
			#fl.MoveInDate,
			#fl.NoticeToVacateDate,
			#fl.MoveOutDate,
			l.LeaseStatus,
			0 AS 'Balance',
			0 AS 'LeaseRequiredDeposit',
			0 AS 'DepositPaidIn',
			0 As 'MarketRentAtMoveIn',
			0 AS 'MarketRentAtReportEnd',
			0 AS 'MarketRentAtToday',
			0 AS 'ActualRent',			
			p.Phone1,
			p.Email,
			p.PreferredName + ' ' + p.LastName,
			pl.ReasonForLeaving,
			null,
			pap.LeaseExpirationLimit,
			null,
			null
		FROM #FilteredLeases #fl
			INNER JOIN Unit u ON u.UnitID = #fl.UnitID
			INNER JOIN Lease l ON ((#fl.RecordType IN ( 'MoveIn', 'ApplicationDate', 'LeaseStart', 'LeaseEnd' ) AND l.LeaseID = #fl.FirsLeaseID) OR (#fl.RecordType IN ( 'MoveOut', 'NoticeToVacate') AND l.LeaseID = #fl.LastLeaseID))
			INNER JOIN PersonLease pl ON pl.LeaseID = l.LeaseID AND pl.PersonID = (SELECT TOP 1 pl2.PersonID 
																				   FROM PersonLease pl2
																				   WHERE pl2.LeaseID = l.LeaseID
																				   ORDER BY pl2.OrderBy)
			INNER JOIN Person p ON p.PersonID = pl.PersonID
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = #fl.PropertyID
			LEFT JOIN PropertyAccountingPeriod pap ON pap.PropertyID = #fl.PropertyID AND pap.StartDate <= l.LeaseEndDate AND pap.EndDate >= l.LeaseEndDate


	-- Get rid of statuses that aren't needed
	DELETE FROM #LeaseData
		WHERE LeaseStatus NOT IN (SELECT Value FROM @statuses)

	UPDATE #LeaseData SET ResidentNames = (STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
											 FROM Person 
												 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
												 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID												
											 WHERE PersonLease.LeaseID = #LeaseData.LeaseID
												   AND PersonType.[Type] = 'Resident'				   
												   AND PersonLease.MainContact = 1				   
											 FOR XML PATH ('')), 1, 2, ''))

	UPDATE #LeaseData SET LeasingAgent = (SELECT per.PreferredName + ' ' + per.LastName
											  FROM Lease l
												  INNER JOIN Person per ON l.LeasingAgentPersonID = per.PersonID
											  WHERE l.LeaseID = #LeaseData.LeaseID)

	IF (EXISTS(SELECT * FROM @fields WHERE Value = 'Leases.DepositPaidIn'))
	BEGIN

		UPDATE #LeaseData SET DepositPaidIn = (SELECT ISNULL(SUM(t.Amount), 0)
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID 			
			WHERE t.ObjectID = #LeaseData.UnitLeaseGroupID
			  AND t.TransactionDate <= #LeaseData.EndDate
			  AND tt.Name IN ('Deposit', 'Balance Transfer Deposit', 'Deposit Interest Payment'))		  
		  
		UPDATE #LeaseData SET DepositPaidIn = DepositPaidIn - (SELECT ISNULL(SUM(t.Amount), 0)
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID		
			WHERE t.ObjectID = #LeaseData.UnitLeaseGroupID
			  AND t.TransactionDate <= #LeaseData.EndDate
			  AND tt.Name IN ('Deposit Refund', 'Deposit Applied to Balance'))		  
	END

	IF (EXISTS(SELECT * FROM @fields WHERE Value = 'Leases.LeaseRequiredDeposit'))
	BEGIN			  
		UPDATE #LeaseData SET LeaseRequiredDeposit = (SELECT ISNULL(SUM(lli.Amount), 0)
			FROM UnitLeaseGroup ulg 
				INNER JOIN Lease l on l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN LeaseLedgerItem lli ON l.LeaseID = lli.LeaseID
				INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
				INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
			WHERE ulg.UnitLeaseGroupID = #LeaseData.UnitLeaseGroupID
			  AND lit.IsDeposit = 1)

	END

	IF (EXISTS(SELECT * FROM @fields WHERE Value = 'Leases.Balance'))
	BEGIN			
		UPDATE #LeaseData SET Balance = CurBal.Balance
			FROM #LeaseData
				CROSS APPLY GetObjectBalance2(null, #LeaseData.EndDate, #LeaseData.UnitLeaseGroupID, 0, #LeaseData.PropertyID) AS [CurBal]				 		
	END


	IF (EXISTS(SELECT * FROM @fields WHERE Value = 'Leases.ActualRent'))
	BEGIN
		UPDATE #LeaseData SET ActualRent =  (SELECT ISNULL(Sum(lli.Amount), 0) 
												FROM LeaseLedgerItem lli
												INNER JOIN LedgerItem li on li.LedgerItemID = lli.LedgerItemID
												INNER JOIN LedgerItemType lit on lit.LedgerItemTypeID = li.LedgerItemTypeID
												WHERE lli.LeaseID = #LeaseData.LeaseID 
													  AND lit.IsRent = 1
													  AND lli.StartDate <= #LeaseData.LeaseStartDate
													  AND lli.EndDate >= #LeaseData.LeaseEndDate)
	END

	UPDATE #LeaseData SET AppliedOnline = (SELECT ISNULL((SELECT TOP 1
																ai.OriginatedOnline
															FROM ApplicantInformation ai
															WHERE ai.LeaseID = #LeaseData.LeaseID), 0))

	IF (EXISTS(SELECT * FROM @fields WHERE Value = 'Leases.MarketRentAtMoveIn'))
	BEGIN			
		UPDATE #LeaseData SET MarketRentAtMoveIn = mr.Amount
			FROM #LeaseData #ld
				CROSS APPLY GetMarketRentByDate(#ld.UnitID, #ld.MoveInDate, 1) mr					 		
	END

	IF (EXISTS(SELECT * FROM @fields WHERE Value = 'Leases.MarketRentAtReportEnd'))
	BEGIN			
		UPDATE #LeaseData SET MarketRentAtReportEnd = mr.Amount
			FROM #LeaseData #ld
				CROSS APPLY GetMarketRentByDate(#ld.UnitID, #ld.EndDate, 1) mr					 		
	END

	IF (EXISTS(SELECT * FROM @fields WHERE Value = 'Leases.MarketRentAtToday'))
	BEGIN			
		UPDATE #LeaseData SET MarketRentAtToday = mr.Amount
			FROM #LeaseData #ld
				CROSS APPLY GetMarketRentByDate(#ld.UnitID, GETDATE(), 1) mr					 		
	END

-- Update prospect id for main prospects
	UPDATE #LeaseData SET ProspectID = (SELECT TOP 1 pr.ProspectID 
												FROM Prospect pr													  
													INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
													INNER JOIN PersonLease pl ON pl.LeaseID = #LeaseData.LeaseID AND pr.PersonID = pl.PersonID
												WHERE pps.PropertyID = #LeaseData.PropertyID)
													   	
													 
	-- Update prospect id for roommates											 
	UPDATE #LeaseData SET ProspectID = (SELECT TOP 1 pr.ProspectID 
											FROM Prospect pr	
												INNER JOIN ProspectRoommate proroom ON pr.ProspectID = proroom.ProspectID												 
												INNER JOIN PropertyProspectSource pps ON pps.PropertyProspectSourceID = pr.PropertyProspectSourceID
												INNER JOIN PersonLease pl ON pl.LeaseID = #LeaseData.LeaseID AND proroom.PersonID = pl.PersonID
											WHERE pps.PropertyID = #LeaseData.PropertyID)
		WHERE #LeaseData.ProspectID IS NULL

	CREATE TABLE #ProspectData (
        PropertyID uniqueidentifier,
        ProspectID uniqueidentifier,
        MainPersonID uniqueidentifier,
        RecordType nvarchar(100),
        FirstName nvarchar(30),
        LastName nvarchar(50),
        PhoneNumber nvarchar(100),
        Email nvarchar(256),
        StreetAddress nvarchar(500),
        City nvarchar(50),
        [State] nvarchar(50),
        Zip nvarchar(20),
        ProspectSource nvarchar(50),
        MovingFrom nvarchar(50),
        ReasonForMoving nvarchar(50),
        DateNeeded datetime,
        Occupants int,
        DesiredMinBedrooms int,
        DesiredMaxBedrooms int,
        DesiredMinBathrooms int,
        DesiredMaxBathrooms int,
        UnitTypePreference nvarchar(max),
        UnitPreference nvarchar(max),
        DesiredAmenities nvarchar(max),
        BuildingPreference nvarchar(20),
        FloorPreference nvarchar(20),
        DesiredRent int,
        OtherPreferences nvarchar(4000),
        FirstContactDate datetime,
        LastContactDate datetime,
        LeasingAgent nvarchar(210),
        UnitShown bit,
        LostDate datetime,
        LostReason nvarchar(50),
        LostReasonNotes nvarchar(1000),
        OnlineApplicationSent bit)

	INSERT #ProspectData
		SELECT	DISTINCT
				#ld.PropertyID,
				#ld.ProspectID,
				#ld.ProspectID,
				'Prospect',				-- Record Type
				per.PreferredName,
				per.LastName,
				per.Phone1,
				per.Email,
				adr.StreetAddress,
				adr.City,
				adr.[State],
				adr.Zip,
				ps.Name,
				pros.MovingFrom,
				pliMoving.Name,
				pros.DateNeeded,
				pros.Occupants,
				pros.DesiredBedroomsMin,
				pros.DesiredBedroomsMax,
				pros.DesiredBathroomsMin,
				pros.DesiredBathroomsMax,
				STUFF((SELECT ', ' + ut.Name
					FROM UnitType ut
						INNER JOIN ProspectUnitType put ON ut.UnitTypeID = put.UnitTypeID
					WHERE put.ProspectID = pros.ProspectID
					FOR XML PATH ('')), 1, 2, ''),
				STUFF((SELECT ', ' + u.Number
					FROM Unit u
						INNER JOIN ProspectUnit pu ON u.UnitID = pu.UnitID
					WHERE pu.ProspectID = pros.ProspectID
					FOR XML PATH ('')), 1, 2, ''),
				STUFF((SELECT ', ' + amen.Name
					FROM Amenity amen
						INNER JOIN ProspectAmenity prosAmen ON amen.AmenityID = prosAmen.AmenityID
					WHERE prosAmen.ProspectID = pros.ProspectID
					FOR XML PATH ('')), 1, 2, ''),
				pros.Building,
				pros.[Floor],
				pros.MaxRent,
				pros.OtherPreferences,
				pnFirst.[Date],
				pnLast.[Date],
				#ld.LeasingAgent,
				CASE WHEN (SELECT COUNT(pnUnitShown.PersonNoteID) 						
							FROM PersonNote pnUnitShown
							WHERE pnUnitShown.PersonID = pros.PersonID
							  AND pnUnitShown.InteractionType = 'Unit Shown'
							  AND pnUnitShown.PropertyID = #ld.PropertyID) > 0 THEN CAST(1 AS BIT)
					  ELSE CAST(0 AS BIT)
					  END,
				pros.LostDate,
				pliLost.Name,
				pros.LostReasonNotes,
				pros.OnlineApplicationSent			-- OnlineApplicationSent
			FROM #LeaseData #ld
				INNER JOIN Prospect pros ON #ld.ProspectID = pros.ProspectID
				INNER JOIN Person per ON pros.PersonID = per.PersonID
				LEFT JOIN [Address] adr ON per.PersonID = adr.ObjectID AND adr.AddressType = 'Prospect'
				LEFT JOIN PersonNote pnFirst ON pros.PersonID = pnFirst.PersonID
				LEFT JOIN PersonNote pnLast ON pros.PersonID = pnLast.PersonID
				LEFT JOIN PropertyProspectSource pps ON pros.PropertyProspectSourceID = pps.PropertyProspectSourceID
				LEFT JOIN ProspectSource ps ON pps.ProspectSourceID = ps.ProspectSourceID
				LEFT JOIN PickListItem pliMoving ON pros.ReasonForMovingPickListItemID = pliMoving.PickListItemID
				LEFT JOIN PickListItem pliLost ON pros.LostReasonPickListItemID = pliLost.PickListItemID
				LEFT JOIN PersonNote pnFirstChecker ON pros.PersonID = pnFirstChecker.PersonID AND pnFirstChecker.[Date] < pnFirst.[Date]
				LEFT JOIN PersonNote pnLastChecker ON pros.PersonID = pnLastChecker.PersonID AND pnLastChecker.[Date] > pnLast.[Date]
			WHERE pnFirstChecker.PersonNoteID IS NULL
			  AND pnLastChecker.PersonNoteID IS NULL

	INSERT #ProspectData
		SELECT	DISTINCT
				#pd.PropertyID,
				per.PersonID,
				#pd.ProspectID,
				'Roommate',				-- Record Type
				per.PreferredName,
				per.LastName,
				per.Phone1,
				per.Email,
				#pd.StreetAddress,
				#pd.City,
				#pd.[State],
				#pd.Zip,
				#pd.ProspectSource,
				#pd.MovingFrom,
				#pd.ReasonForMoving,
				#pd.DateNeeded,
				#pd.Occupants,
				#pd.DesiredMinBedrooms,
				#pd.DesiredMaxBedrooms,
				#pd.DesiredMinBathrooms,
				#pd.DesiredMaxBedrooms,
				#pd.UnitTypePreference,
				#pd.UnitPreference,
				#pd.DesiredAmenities,
				#pd.BuildingPreference,
				#pd.FloorPreference,
				#pd.DesiredRent,
				#pd.OtherPreferences,
				#pd.FirstContactDate,
				#pd.LastContactDate,
				#pd.LeasingAgent,
				#pd.UnitShown,
				#pd.LostDate,
				#pd.LostReason,
				#pd.LostReasonNotes,
				#pd.OnlineApplicationSent			-- OnlineApplicationSent
			FROM #ProspectData #pd
				INNER JOIN ProspectRoommate pr ON #pd.ProspectID = pr.ProspectID
				INNER JOIN Person per ON pr.PersonID = per.PersonID


	-- return Lease data
	SELECT distinct *		  
	FROM #LeaseData	#ld		
	ORDER BY PropertyID, UnitLeaseGroupID, LeaseID
	
	-- return Property data
	SELECT
		p.PropertyID AS 'PropertyID',
		p.Name AS 'Name',
		p.Abbreviation AS 'Abbreviation',
		ad.StreetAddress AS 'StreetAddress',
		ad.City AS 'City',
		ad.[State] AS 'State',
		ad.Zip AS 'Zip',
		manp.PreferredName + ' ' + manp.LastName AS 'ManagerName',
		regp.PreferredName + ' ' + regp.LastName AS 'RegionalName',
		v.CompanyName AS 'CompanyName'
	FROM Property p
		LEFT JOIN [Address] ad ON p.AddressID = ad.AddressID
		LEFT JOIN Person manp ON p.ManagerPersonID = manp.PersonID
		LEFT JOIN Person regp ON p.RegionalManagerPersonID = regp.PersonID
		LEFT JOIN Vendor v on p.ManagementCompanyVendorID = v.VendorID
		INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
	WHERE p.AccountID = @accountID
	  


	-- return Building data
	SELECT
		b.PropertyID AS 'PropertyID',
		b.BuildingID AS 'BuildingID',
		b.Name AS 'Name',
		b.Floors AS 'Floors',
		b.[Description] AS 'Description',
		ad.StreetAddress AS 'StreetAddress',
		ad.City AS 'City',
		ad.[State] AS 'State',
		ad.Zip AS 'Zip'
	FROM Building b
		LEFT JOIN [Address] ad ON b.AddressID = ad.AddressID
		INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = b.PropertyID
	WHERE b.AccountID = @accountID
	  


	-- return Unit data
	SELECT
		u.UnitID AS 'UnitID',
		b.BuildingID AS 'BuildingID',
		u.UnitTypeID AS 'UnitTypeID',
		u.Number AS 'Number',
		u.PaddedNumber AS 'PaddedNumber',
		ad.StreetAddress AS 'StreetAddress',
		ad.City AS 'City',
		ad.[State] AS 'State',
		ad.Zip AS 'Zip',
		u.SquareFootage AS 'SquareFootage',
		u.[Floor] AS 'Floor'
	FROM Unit u
		INNER JOIN Building b ON u.BuildingID = b.BuildingID
		LEFT JOIN [Address] ad ON u.AddressID = ad.AddressID
		INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = b.PropertyID
	WHERE u.AccountID = @accountID
	  


	-- return UnitType data
	SELECT
		ut.UnitTypeID AS 'UnitTypeID',
		ut.PropertyID AS 'PropertyID',
		ut.Name AS 'Name',
		ut.Bedrooms AS 'Bedrooms',
		ut.Bathrooms AS 'Bathrooms',
		ut.[Description] AS 'Description'
	FROM UnitType ut
		INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = ut.PropertyID
	WHERE ut.AccountID = @accountID


	-- return Prospect data
	SELECT *
		FROM #ProspectData
		ORDER BY PropertyID, MainPersonID, ProspectID
	  


END
GO
