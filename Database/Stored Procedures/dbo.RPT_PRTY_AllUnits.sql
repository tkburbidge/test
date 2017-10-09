SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO







--Changed by Trevor, Added parameters for including waiting list or excludedFromOccupancy units
-- =============================================
-- Author:		Rick Bertelsen
-- Create date: March 27, 2010
-- Description:	Generates the data for the AllUnits Report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_PRTY_AllUnits] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
	--@includeHoldingUnits bit = 0,
	--@includeExcludedFromOccupancy bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #UnitAmenities (
		Number nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		UnitTypeID uniqueidentifier not null,
		UnitStatus nvarchar(200) not null,
		UnitStatusLedgerItemTypeID uniqueidentifier not null,
		RentLedgerItemTypeID uniqueidentifier not null,
		MarketRent decimal null,
		Amenities nvarchar(MAX) null)
		
	CREATE TABLE #Properties (
		Sequence int identity not null,
		PropertyID uniqueidentifier not null)

	DECLARE @propertyID uniqueidentifier, @ctr int = 1, @maxCtr int, @unitIDs GuidCollection
	DECLARE @accountID bigint

	INSERT #Properties SELECT Value FROM @propertyIDs
	SET @maxCtr = (SELECT MAX(Sequence) FROM #Properties)
	
	WHILE (@ctr <= @maxCtr)
	BEGIN
		SELECT @propertyID = PropertyID FROM #Properties WHERE Sequence = @ctr
		SELECT @accountID = AccountID FROM Property WHERE PropertyID = @propertyID
		INSERT @unitIDs SELECT u.UnitID
							FROM Unit u
								INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = @propertyID
		INSERT #UnitAmenities EXEC GetRecurringChargeUnitInfo @propertyID, @unitIDs, @date, 0
		SET @ctr = @ctr + 1
	END		

	CREATE TABLE #AllUnits (
		PropertyID uniqueidentifier,
		PropertyName nvarchar(100),
		UnitID uniqueidentifier,
		Unit nvarchar(100),
		UnitTypeName nvarchar(100),
		UnitTypeID uniqueidentifier,
		UnitTypeSquareFeet int,
		SquareFeet int,
		Residents nvarchar(1000),
		LeaseStatus nvarchar(100),
		UnitTypeMarketRent money,
		MarketRent money,
		ActualRent money,
		DepositPaidIn money,
		MoveInDate date,
		NTVDate date,
		MoveOutDate date,
		PreLeased bit,
		UnitStatus nvarchar(100),
		MadeReady bit,
		CurrentLeaseID uniqueidentifier,
		CurrentUnitLeaseGroupID uniqueidentifier,
		PendingLeaseID uniqueidentifier,
		ReportingLeaseID uniqueidentifier,
		ReportingUnitLeaseGroupID uniqueidentifier,
		LeaseStartDate date,
		LeaseEndDate date,
		Bedrooms int,
		Bathrooms decimal(6,1),
		[Description] nvarchar(1000),
		PaddedNumber nvarchar(1000)
	)


	CREATE TABLE #CurrentOccupants
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,		
		OccupiedUnitLeaseGroupID uniqueidentifier, 
		OccupiedLastLeaseID uniqueidentifier,
		OccupiedMoveInDate date,
		OccupiedNTVDate date,
		OccupiedMoveOutDate date,
		OccupiedIsMovedOut bit,
		PendingUnitLeaseGroupID uniqueidentifier,
		PendingLeaseID uniqueidentifier,
		PendingApplicationDate date,
		PendingMoveInDate date 
	)

	INSERT INTO #CurrentOccupants
		EXEC [GetConsolodatedOccupancyNumbers] @accountID, @date, null, @propertyIDs

	INSERT INTO #AllUnits
		SELECT
			p.PropertyID,
			p.Name,
			#co.UnitID,
			u.Number,
			ut.Name,
			ut.UnitTypeID,
			ut.SquareFootage,
			u.SquareFootage,
			null AS 'Residents',
			null AS 'LeaseStatus',
			ISNULL(utmr.Amount, 0) AS 'UnitTypeMarketRent',
			#ua.MarketRent AS 'MarketRent',
			0 AS 'ActualRent',		
			0 AS 'DepositPaidIn',			
			null AS 'MoveInDate',
			(CASE WHEN #co.OccupiedNTVDate IS NOT NULL AND #co.OccupiedNTVDate <= @date THEN #co.OccupiedNTVDate
				  ELSE NULL
			 END) AS 'NTVDate',			
			 (CASE WHEN #co.OccupiedNTVDate IS NOT NULL AND #co.OccupiedNTVDate <= @date THEN #co.OccupiedMoveOutDate
				  ELSE NULL
			 END) AS 'MoveOutDate',				
			CASE
				WHEN (#co.PendingLeaseID IS NOT NULL) THEN CAST(1 AS BIT)
				ELSE CAST(0 AS BIT)
				END AS 'PreLeased',	
			US.[Status] AS 'UnitStatus',				
			CAST(0 AS BIT) AS 'MadeReady',
			null AS 'CurrentLeaseID',
			#co.OccupiedUnitLeaseGroupID AS 'CurrentUnitLeaseGroupID',
			#co.PendingLeaseID AS 'PendingLeaseID',
			--COALESCE(l.LeaseID, pendl.LeaseID) AS 'ReportingLeaseID',
			NULL AS 'ReportingLeaseID',			
			COALESCE(#co.OccupiedUnitLeaseGroupID, pendl.UnitLeaseGroupID) AS 'ReportingUnitLeaseGroupID',
			NULL AS 'LeaseStartDate',
		    --COALESCE(l.LeaseStartDate, pendl.LeaseStartDate) AS 'LeaseStartDate',	
			NULL AS 'LeaseEndDate',
		    --COALESCE(l.LeaseEndDate, pendl.LeaseEndDate) AS 'LeaseEndDate',		         	         		   
			ut.Bedrooms AS 'Bedrooms',
			ut.Bathrooms AS 'Bathrooms',
			ut.[Description] AS 'Description',
			u.PaddedNumber
		FROM #CurrentOccupants #co
			INNER JOIN #UnitAmenities #ua ON #ua.UnitID = #co.UnitID
			INNER JOIN Property p on p.PropertyID = #co.PropertyID
			INNER JOIN Unit u ON u.UnitID = #co.UnitID
			INNER JOIN UnitType ut ON ut.UnitTypeID = u.UnitTypeID
			LEFT JOIN Lease l ON l.LeaseID = #co.OccupiedLastLeaseID
			LEFT JOIN Lease pendl ON pendl.LeaseID = #co.PendingLeaseID
			OUTER APPLY [GetLatestMarketRentByUnitTypeID](ut.UnitTypeID, @date) utmr
			OUTER APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS US
		ORDER BY p.Name, u.PaddedNumber		

		
	--INSERT INTO #AllUnits
	--SELECT  p.PropertyID,
	--		p.Name AS 'PropertyName',
	--		u.UnitID,
	--		u.Number AS 'Unit',
	--		ut.Name AS 'UnitTypeName',
	--		ut.UnitTypeID,
	--		ut.SquareFootage AS 'UnitTypeSquareFeet',	   
	--		u.SquareFootage AS 'SquareFeet',	   
			
	--		NULL AS 'Resident',
	--	   (CASE WHEN l.LeaseID IS NOT NULL THEN l.LeaseStatus
	--	         WHEN pendl.LeaseID IS NOT NULL THEN pendl.LeaseStatus
	--	         ELSE NULL
	--	    END) AS 'LeaseStatus',
	--		ISNULL(utmr.Amount, 0) AS 'UnitTypeMarketRent',
	--		#ua.MarketRent AS 'MarketRent',
	--		0 AS 'ActualRent',
		
	--		0 AS 'DepositPaidIn',
			
	--		null,
	--		null,
	--		CASE
	--			WHEN (pendl.LeaseID IS NOT NULL) THEN CAST(1 AS BIT)
	--			ELSE CAST(0 AS BIT)
	--			END AS 'PreLeased',	
	--		US.Status AS 'UnitStatus',		
		
	--		CAST(0 AS BIT) AS 'MadeReady',
	--		l.LeaseID AS 'CurrentLeaseID',
	--		pendl.LeaseID AS 'PendingLeaseID',
	--		COALESCE(l.LeaseID, pendl.LeaseID) AS 'ReportingLeaseID',
	--		COALESCE(l.UnitLeaseGroupID, pendl.UnitLeaseGroupID) AS 'ReportingUnitLeaseGroupID',
	--	    COALESCE(l.LeaseStartDate, pendl.LeaseStartDate) AS 'LeaseStartDate',	
	--	    COALESCE(l.LeaseEndDate, pendl.LeaseEndDate) AS 'LeaseEndDate',		         	         		   
	--		ut.Bedrooms AS 'Bedrooms',
	--		ut.Bathrooms AS 'Bathrooms',
	--		ut.[Description] AS 'Description'
	--	FROM Unit u
	--		INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
	--		INNER JOIN Property p ON ut.PropertyID = p.PropertyID
	--		INNER JOIN #UnitAmenities #ua ON u.UnitID = #ua.UnitID
	--		-- Current lease
	--		LEFT JOIN UnitLeaseGroup culg ON u.UnitID = culg.UnitID AND (SELECT COUNT(*) FROM Lease WHERE Lease.UnitLeaseGroupID = culg.UnitLeaseGroupID AND Lease.LeaseStatus IN ('Current', 'Under Eviction')) > 0
	--		LEFT JOIN Lease l ON culg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')			
	--		-- Pending Lease
	--		LEFT JOIN UnitLeaseGroup pulg ON u.UnitID = pulg.UnitID AND (SELECT COUNT(*) FROM Lease WHERE Lease.UnitLeaseGroupID = pulg.UnitLeaseGroupID AND Lease.LeaseStatus IN ('Pending', 'Pending Transfer')) > 0
	--		LEFT JOIN Lease pendl ON pulg.UnitLeaseGroupID = pendl.UnitLeaseGroupID AND pendl.LeaseStatus IN ('Pending', 'Pending Transfer')						
	--		OUTER APPLY GetUnitStatusByUnitID(u.UnitID, @date) AS US
	--		INNER JOIN #Properties #p ON #p.PropertyID = p.PropertyID
	--		OUTER APPLY [GetLatestMarketRentByUnitTypeID](ut.UnitTypeID, @date) utmr
	--	WHERE (@includeHoldingUnits = 1 OR u.IsHoldingUnit = 0)
	--	  AND (@includeExcludedFromOccupancy = 1 OR u.ExcludedFromOccupancy = 0)
	--	ORDER BY p.Name, u.PaddedNumber		


	UPDATE #AllUnits SET CurrentLeaseID = (SELECT TOP 1 l.LeaseID
												   FROM Lease l													   
												   WHERE l.UnitLeaseGroupID = #AllUnits.CurrentUnitLeaseGroupID
													 AND l.LeaseStartDate <= @date 
													 AND l.LeaseEndDate >= @date)



	UPDATE #AllUnits SET CurrentLeaseID = (SELECT TOP 1 l.LeaseID
												   FROM Lease l 													  
												   WHERE l.UnitLeaseGroupID = #AllUnits.CurrentUnitLeaseGroupID
													 AND l.LeaseStartDate < @date
												   ORDER BY l.LeaseStartDate DESC)
	WHERE #AllUnits.CurrentLeaseID IS NULL 

	UPDATE #AllUnits SET CurrentLeaseID = (SELECT l.LeaseID
											FROM #CurrentOccupants #co
												INNER JOIN Lease l ON #co.OccupiedLastLeaseID = l.LeaseID
											WHERE #AllUnits.CurrentUnitLeaseGroupID = #co.OccupiedUnitLeaseGroupID)
	WHERE #AllUnits.CurrentLeaseID IS NULL

	UPDATE #AllUnits SET ReportingLeaseID = COALESCE(CurrentLeaseID, PendingLeaseID)

	UPDATE #au
		SET #au.LeaseStatus = l.LeaseStatus,
			#au.LeaseStartDate = l.LeaseStartDate,
			#au.LeaseEndDate = l.LeaseEndDate 
		FROM #AllUnits #au
			INNER JOIN Lease l ON #au.ReportingLeaseID = l.LeaseID			

	UPDATE #AllUnits SET Residents = STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
										 FROM Person 
											 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
											 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
											 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
										 WHERE PersonLease.LeaseID = #AllUnits.ReportingLeaseID
											   AND PersonType.[Type] = 'Resident'				   
											   AND PersonLease.MainContact = 1				   
										 FOR XML PATH ('')), 1, 2, '')
			
			
	UPDATE #AllUnits SET MoveInDate =	(SELECT MIN(pl.MoveInDate) 
										FROM PersonLease pl
										WHERE pl.LeaseID = #AllUnits.ReportingLeaseID
											AND pl.ResidencyStatus NOT IN ('Cancelled'))

	--UPDATE #AllUnits SET MoveOutDate = (SELECT MAX(pl.MoveOutDate)
	--								FROM PersonLease pl
	--									LEFT JOIN PersonLease plmo ON pl.LeaseID = plmo.LeaseID AND plmo.MoveOutDate IS NULL
	--								WHERE pl.LeaseID = #AllUnits.ReportingLeaseID		  
	--								  AND plmo.PersonLeaseID IS NULL)

	UPDATE #AllUnits SET ActualRent = (SELECT ISNULL(SUM(lli.Amount), 0)
										FROM LeaseLedgerItem lli
											INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
											INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID	
										WHERE lli.LeaseID = #AllUnits.ReportingLeaseID
										  AND lit.IsRent = 1
										  AND lli.StartDate <= @date
										  AND lli.EndDate >= @date) 


	UPDATE #AllUnits SET DepositPaidIn =  (SELECT ISNULL(SUM(t.Amount), 0)
											FROM [Transaction] t
												INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID 
												--LEFT JOIN [Transaction] tr ON tr.ReversesTransactionID = t.TransactionID
											WHERE t.ObjectID = #AllUnits.ReportingUnitLeaseGroupID
											  AND t.TransactionDate <= @date
											  AND tt.Name IN ('Deposit', 'Balance Transfer Deposit')) 

	UPDATE #AllUnits SET MadeReady = (CASE 
											WHEN (0 = (SELECT COUNT(*) 
												FROM WorkOrder wo
													INNER JOIN UnitNote un ON un.UnitNoteID = wo.UnitNoteID AND un.UnitID = #AllUnits.UnitID
												WHERE ((wo.CompletedDate IS NULL) OR (wo.CompletedDate > @date))
												  AND wo.[Status] NOT IN ('Cancelled')
												  AND wo.WorkOrderCategoryID IN (SELECT WorkOrderCategoryID 
																					FROM AutoMakeReady 
																					WHERE PropertyID = #AllUnits.PropertyID))) THEN CAST(0 AS BIT)
											ELSE CAST(1 AS BIT)
											END)




	SELECT * FROM #AllUnits ORDER BY PropertyName, PaddedNumber
END
GO
