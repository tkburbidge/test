SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Sept. 20, 2013
-- Description:	Gets the charges and distributions for a given charge to be distributed
-- =============================================
CREATE PROCEDURE [dbo].[GetChargeDistributions] 
	-- Add the parameters for the stored procedure here
	@chargeDistributionDetailIDs GuidCollection READONLY,
	@date date = null,
	@runToPost bit = null,
	@buildingIDs GuidCollection READONLY
AS
DECLARE @propertyID uniqueidentifier
DECLARE @minBillingStartDate date
DECLARE @maxBillingEndDate date
DECLARE @totalDays int
DECLARE @maxOccupiedDays int
DECLARE @excludeVacantUnits bit = 0
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #ChargeDistributions (
		ChargeDistributionDetailID uniqueidentifier NOT NULL,
		ChargeFormulaID uniqueidentifier NULL,
		ChargeName nvarchar(1000) NOT NULL,
		BillingStartDate date NULL,
		BillingEndDate date NULL,
		TotalOccupants int NULL,
		TotalFeetage int NULL,
		TotalAmount money NULL,
		ExcludeVacantUnits bit NULL)
		
	CREATE TABLE #Chargees (
		UnitID uniqueidentifier NOT NULL,
		UnitLeaseGroupID uniqueidentifier NULL,
		PersonID uniqueidentifier NULL,
		MoveInDate date NULL,
		MoveOutDate date NULL,
		TotalDays int NULL,
		MyPortionOfTheBill money NULL)

	CREATE TABLE #UnitData (
		UnitID uniqueidentifier NOT NULL,
		--UnitLeaseGroupID uniqueidentifier NULL,
		--MoveInDate date NULL,
		--MoveOutDate date NULL,
		UnitArea int NULL)
		
	CREATE TABLE #Charges (
		UnitID uniqueidentifier NOT NULL,
		Number nvarchar(100),
		UnitLeaseGroupID uniqueidentifier NULL,
		ChargeDistributionDetailID uniqueidentifier NOT NULL,
		OccupancyCount int NULL,
		DaysOccupied int NULL,
		SquareFootageDaysOccupied int NULL, -- This will not count how many days per person its occupied but just the number of days any person occupied the unit
		DailySquareFootageDaysOccupied int NULL,
		Amount money NULL)

	CREATE TABLE #SummerUpper (
		ChargeDistributionDetailID uniqueidentifier NOT NULL,
		Amount money NULL,
		Deviant money NULL,
		UnitLeaseGroupID uniqueidentifier NULL)
		
	CREATE TABLE #MyTwoFeet (
		UnitID uniqueidentifier,
		Feets int NOT NULL)

	CREATE TABLE #UnitDays (
		UnitID uniqueidentifier NOT NULL,
		DaysOccupied int NULL)
		
	SET @propertyID = (SELECT DISTINCT cd.PropertyID
							FROM ChargeDistributionDetail cdd
								INNER JOIN ChargeDistribution cd ON cdd.ChargeDistributionID = cd.ChargeDistributionID
							WHERE cdd.ChargeDistributionDetailID IN (SELECT Value FROM @chargeDistributionDetailIDs))
							
	INSERT #ChargeDistributions
		SELECT	cdd.ChargeDistributionDetailID, cdd.ChargeDistributionFormulaID, cd.Name, 
				cdd.BillingStartDate, cdd.BillingEndDate, null, null, cdd.Amount, cd.ExcludeVacantUnits
			FROM ChargeDistributionDetail cdd
				INNER JOIN ChargeDistribution cd ON cdd.ChargeDistributionID = cd.ChargeDistributionID
				INNER JOIN ChargeDistributionFormula cdf ON cdf.ChargeDistributionFormulaID = cdd.ChargeDistributionFormulaID
			WHERE cdd.ChargeDistributionDetailID IN (SELECT Value FROM @chargeDistributionDetailIDs)

	SET @excludeVacantUnits = (SELECT TOP 1 ExcludeVacantUnits FROM #ChargeDistributions)			
	SET @minBillingStartDate = (SELECT MIN(BillingStartDate) FROM #ChargeDistributions)
	SET @maxBillingEndDate = (SELECT MAX(BillingEndDate) FROM #ChargeDistributions)
	
	-- if max billing date is this, then we are only posting flat fees, use date posting
	IF (@maxBillingEndDate = '0001-01-01') SET @maxBillingEndDate = @date
	
	INSERT #Chargees
		SELECT	u.UnitID,
				ulg.UnitLeaseGroupID,
				pl.PersonID,
				CASE 
					WHEN (pl.MoveInDate < @minBillingStartDate) THEN @minBillingStartDate
					ELSE pl.MoveInDate
					END,
				CASE 
					WHEN (pl.MoveOutDate > @minBillingStartDate AND pl.MoveOutDate < @maxBillingEndDate) THEN pl.MoveOutDate
					ELSE @maxBillingEndDate
					END,
				null,
				0.00
			FROM Unit u 
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN UnitLeaseGroup ulg ON u.UnitID = ulg.UnitID
				-- Bills prorated at move out so only charge current residents
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID AND l.LeaseStatus IN ('Current', 'Under Eviction')
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.ResidencyStatus  NOT IN ('Cancelled', 'Pending', 'Pending Transfer', 'Pending Renewal', 'Approved')
															AND pl.HouseholdStatus IN (SELECT Name
																						   FROM PickListItem
																						   WHERE [Type] = 'HouseholdStatus'
																							 AND PickListItem.AccountID = pl.AccountID
																							 AND (IsNotOccupant = 0
																								 OR IsNotOccupant IS NULL))
			WHERE ut.PropertyID = @propertyID
			  AND u.ExcludedFromOccupancy = 0
			  AND (u.DateRemoved IS NULL OR u.DateRemoved < @date)
			  AND b.BuildingID IN (SELECT Value FROM @buildingIDs)
			  AND (pl.MoveOutDate IS NULL OR pl.MoveOutDate >= @minBillingStartDate)
			  AND pl.MoveInDate <= @maxBillingEndDate

	INSERT #UnitData
		SELECT u.UnitID, u.SquareFootage
			FROM Unit u 
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
			WHERE ut.PropertyID = @propertyID
				AND u.ExcludedFromOccupancy = 0	
				AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
				AND b.BuildingID IN (SELECT Value FROM @buildingIDs)	

	SET @maxOccupiedDays = DATEDIFF(DAY, @minBillingStartDate, @maxBillingEndDate) + 1
	UPDATE #Chargees SET TotalDays = DATEDIFF(DAY, MoveInDate, MoveOutDate) + 1

	IF (@excludeVacantUnits = 0)
	BEGIN
		
		-- Need to get the number of days a given unit was occupied during the month
		-- In the event that 
		INSERT #UnitDays
			SELECT UnitID, SUM(TotalDays)
				FROM	(SELECT UnitID, DATEDIFF(DAY, MoveInDate, MoveOutDate) + 1 AS TotalDays
						 FROM (SELECT UnitID, MIN(MoveInDate) MoveInDate, MAX(MoveOutDate) AS MoveOutDate
								FROM #Chargees
								GROUP BY UnitID, UnitLeaseGroupID) ByUnit
						) Totals
				GROUP BY UnitID

		INSERT #Chargees
			SELECT	UnitID,
					null,
					NEWID(),						-- Random PersonID so they get picked up a little later on in this wonderful piece of sproc!
					null,
					null,
					@maxOccupiedDays-DaysOccupied,
					0.00
				FROM #UnitDays
				WHERE DaysOccupied <> @maxOccupiedDays
					AND (@maxOccupiedDays-DaysOccupied) > 0
					
		--Insert a row for each vacant unit for the whole period.
		INSERT #Chargees
			SELECT	#uc.UnitID,
					null,
					NEWID(),						-- Random PersonID so they get picked up a little later on in this glorious piece of sproc!
					@minBillingStartDate,
					@maxBillingEndDate,
					@maxOccupiedDays,
					0.00
				FROM #UnitData #uc
				WHERE #uc.UnitID NOT IN (SELECT UnitID FROM #Chargees)
	END
						 
						 

	SET @totalDays = (SELECT SUM(TotalDays) FROM #Chargees)
		
	INSERT INTO #Charges
		SELECT #cees.UnitID, u.Number, #cees.UnitLeaseGroupID, cdd.ChargeDistributionDetailID, 0, 0, 0, null, null
		FROM #Chargees #cees
			INNER JOIN Unit u ON u.UnitID = #cees.UnitID
			INNER JOIN ChargeDistribution cd ON cd.PropertyID = @propertyID
			INNER JOIN ChargeDistributionDetail cdd ON cd.ChargeDistributionID = cdd.ChargeDistributionID
		WHERE cdd.ChargeDistributionDetailID IN (SELECT Value FROM @chargeDistributionDetailIDs)
		GROUP BY u.Number, #cees.UnitID, #cees.UnitLeaseGroupID, cdd.ChargeDistributionDetailID



	INSERT INTO #MyTwoFeet			
		SELECT u.UnitID, u.SquareFootage
			FROM UnitType ut 
				INNER JOIN Unit u ON ut.UnitTypeID = u.UnitTypeID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
			WHERE ut.PropertyID = @propertyID
				AND u.ExcludedFromOccupancy = 0
				AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
				AND b.BuildingID IN (SELECT Value FROM @buildingIDs)

	DELETE FROM #MyTwoFeet
		WHERE UnitID NOT IN (SELECT DISTINCT UnitID FROM #Charges)
	
	UPDATE #ChargeDistributions SET TotalFeetage = (SELECT SUM(Feets) FROM #MyTwoFeet)
	
	UPDATE #Charges SET OccupancyCount = (SELECT COUNT(DISTINCT #cees.PersonID)
											  FROM #Chargees #cees
											  WHERE #cees.UnitID = #Charges.UnitID
												AND ((#Charges.UnitLeaseGroupID IS NOT NULL AND #cees.UnitLeaseGroupID = #Charges.UnitLeaseGroupID) OR (#Charges.UnitLeaseGroupID IS NULL AND #cees.UnitLeaseGroupID IS NULL)))

	UPDATE #Charges SET DaysOccupied = (SELECT SUM(TotalDays)
											FROM #Chargees #cees
											WHERE #cees.UnitID = #Charges.UnitID
												AND ((#Charges.UnitLeaseGroupID IS NOT NULL AND #cees.UnitLeaseGroupID = #Charges.UnitLeaseGroupID) OR (#Charges.UnitLeaseGroupID IS NULL AND #cees.UnitLeaseGroupID IS NULL)))

	UPDATE #Charges SET SquareFootageDaysOccupied = (SELECT DATEDIFF(DAY, MoveInDate, MoveOutDate) + 1
												     FROM (SELECT UnitLeaseGroupID, MIN(MoveInDate) MoveInDate, MAX(MoveOutDate) MoveOutDate
															FROM #Chargees #cees
															WHERE #cees.UnitID = #Charges.UnitID
																AND #cees.UnitLeaseGroupID = #Charges.UnitLeaseGroupID
															GROUP BY #cees.UnitLeaseGroupID) Occupancy)
		WHERE UnitLeaseGroupID IS NOT NULL

	-- Vacant units, if there are any, count as one occupant so SQDO = DO
	UPDATE #Charges SET SquareFootageDaysOccupied = DaysOccupied WHERE UnitLeaseGroupID IS NULL
	
	UPDATE #c SET DailySquareFootageDaysOccupied = SquareFootageDaysOccupied * #mtf.Feets
													FROM #Charges #c
														INNER JOIN #MyTwoFeet #mtf ON #mtf.UnitID = #c.UnitID 		

	--UPDATE #Charges SET DailySquareFootageDaysOccupied = (SELECT SUM(#c.SquareFootageDaysOccupied * #mtf.Feets)
	--													   FROM #Charges #c
	--														INNER JOIN #MyTwoFeet #mtf ON #mtf.UnitID = #c.UnitID
	--													   WHERE #c.UnitID = #Charges.UnitID)										

	UPDATE #ChargeDistributions SET TotalOccupants = (SELECT SUM(#c.OccupancyCount)
															FROM #ChargeDistributions #cd
																INNER JOIN #Charges #c ON #cd.ChargeDistributionDetailID = #c.ChargeDistributionDetailID
															WHERE #cd.ChargeDistributionDetailID = #ChargeDistributions.ChargeDistributionDetailID
															GROUP BY #cd.ChargeDistributionDetailID)



	DECLARE @totalSquareFeets int = (SELECT SUM(DailySquareFootageDaysOccupied) FROM #Charges)


	UPDATE #c SET Amount = ((TotalAmount * (CAST(cdf.NumberOfOccupantsWeight AS float) / 100.0) * (CAST(#c.DaysOccupied AS float)/CAST(@totalDays AS float)))
							+ (TotalAmount * (CAST(cdf.SquareFootageWeight AS float) / 100.0) * ((CAST(#c.DailySquareFootageDaysOccupied AS float)/(CAST(@totalSquareFeets AS float)))))
							+ cdf.AdditionalFee)
		FROM #Charges #c
			INNER JOIN #UnitData #ucees ON #c.UnitID = #ucees.UnitID
			INNER JOIN #ChargeDistributions #cd ON #c.ChargeDistributionDetailID = #cd.ChargeDistributionDetailID
			INNER JOIN ChargeDistributionFormula cdf ON #cd.ChargeFormulaID = cdf.ChargeDistributionFormulaID
		WHERE #c.OccupancyCount > 0

	UPDATE #c SET Amount = #cd.TotalAmount
		FROM #Charges #c
			INNER JOIN #ChargeDistributions #cd ON #c.ChargeDistributionDetailID = #cd.ChargeDistributionDetailID
		WHERE #cd.ChargeFormulaID IS NULL

							   
		 
	UPDATE #Charges SET Amount = ISNULL(ROUND(Amount, 2), 0)

	INSERT #SummerUpper
		SELECT ChargeDistributionDetailID, ISNULL(SUM(Amount), 0), null, null
			FROM #Charges
			GROUP BY ChargeDistributionDetailID

	UPDATE #SummerUpper SET Deviant = Amount - ISNULL((SELECT TotalAmount
															FROM #ChargeDistributions
															WHERE ChargeDistributionDetailID = #SummerUpper.ChargeDistributionDetailID), 0)
			
	UPDATE #SummerUpper SET UnitLeaseGroupID = (SELECT TOP 1 UnitLeaseGroupID
													FROM #Charges
													WHERE ChargeDistributionDetailID = #SummerUpper.ChargeDistributionDetailID
													AND UnitLeaseGroupID IS NOT NULL
													ORDER BY Amount DESC)
		WHERE Deviant <> 0.00


	UPDATE #c SET Amount = #c.Amount - #su.Deviant
		FROM #Charges #c
			INNER JOIN #SummerUpper #su ON #c.UnitLeaseGroupID = #su.UnitLeaseGroupID
	  

	IF (@runToPost = 0)
	BEGIN
		SELECT	DISTINCT
				#c.UnitLeaseGroupID AS 'UnitLeaseGroupID',
				u.Number AS 'UnitNumber',
				u.PaddedNumber AS 'PaddedNumber',
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
					 FROM Person 
						 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
						 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
						 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
					 WHERE PersonLease.LeaseID = l.LeaseID
						   AND PersonType.[Type] = 'Resident'				   
						   AND PersonLease.MainContact = 1				   
					 FOR XML PATH ('')), 1, 2, '') AS 'Residents'			
			FROM #Charges #c
				INNER JOIN Unit u ON #c.UnitID = u.UnitID
				INNER JOIN Lease l ON #c.UnitLeaseGroupID = l.UnitLeaseGroupID
			WHERE #c.UnitLeaseGroupID IS NOT NULL
			  AND l.LeaseID = ((SELECT TOP 1 LeaseID
									 FROM Lease
										INNER JOIN Ordering o ON o.Value = l.LeaseStatus AND o.[Type] = 'Lease'
									 WHERE UnitLeaseGroupID = #C.UnitLeaseGroupID									   
									 ORDER BY o.OrderBy))
			ORDER BY #c.UnitLeaseGroupID
	END
								 
	SELECT	#cd.ChargeDistributionDetailID,
			#c.UnitLeaseGroupID,
			ISNULL(ROUND(#c.Amount, 2), 0) AS 'Amount',
			lit.Name AS 'ChargeName',
			lit.LedgerItemTypeID AS 'LedgerItemTypeID',
			#cd.ChargeName AS 'DistributionChargeName',
			ISNULL(#cd.TotalFeetage, 0) AS 'TotalFootage',
			ISNULL(#cd.TotalOccupants, 0) AS 'TotalOccupants',
			ISNULL(#cd.TotalAmount, 0) AS 'TotalAmount',
			ISNULL(cdf.NumberOfOccupantsWeight, 0) AS 'OccupancyWeight',
			ISNULL(cdf.SquareFootageWeight, 0) AS 'SquareFootageWeight',
			ISNULL(cdf.BillingPercentage, 0) AS 'BillingPercentage',
			ISNULL(cdf.AdditionalFee, 0) AS 'AdditionalFee',
			ISNULL(#c.OccupancyCount, 0) AS 'OccupancyCount',
			ISNULL(#ucees.UnitArea, 0) AS 'UnitArea',
			ISNULL((SELECT MIN(MoveInDate) FROM #Chargees #cees WHERE #c.UnitLeaseGroupID = #cees.UnitLeaseGroupID AND #c.UnitID = #cees.UnitID), '1900-1-1') AS MoveInDate
		FROM #Charges #c
			INNER JOIN #ChargeDistributions #cd ON #c.ChargeDistributionDetailID = #cd.ChargeDistributionDetailID
			INNER JOIN ChargeDistributionDetail cdd ON #cd.ChargeDistributionDetailID = cdd.ChargeDistributionDetailID
			LEFT JOIN ChargeDistributionFormula cdf ON cdd.ChargeDistributionFormulaID = cdf.ChargeDistributionFormulaID
			INNER JOIN LedgerItemType lit ON cdd.LedgerItemTypeID = lit.LedgerItemTypeID
			INNER JOIN #UnitData #ucees ON #c.UnitID = #ucees.UnitID
		WHERE #c.UnitLeaseGroupID IS NOT NULL
		ORDER BY #c.UnitLeaseGroupID

END



IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PostLateFees]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[PostLateFees] AS' 
END
GO
