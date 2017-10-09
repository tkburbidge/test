SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[ProcessFormCRPInformation] 
	-- Add the parameters for the stored procedure here
	@formID int = 0, 
	@propertyID uniqueidentifier = null,
	@year int = 0,
	@objectIDs GuidCollection READONLY,
	@mainContactsOnly bit = 1
AS

DECLARE @yearStartDate date
DECLARE @yearEndDate date
DECLARE @yearPercent decimal(8, 6)

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #CRPInfo (
		UnitLeaseGroupID				uniqueidentifier not null,
		LeaseID							uniqueidentifier not null,
		PersonID						uniqueidentifier null,
		SpousePersonID					uniqueidentifier null,
		Name							nvarchar(200) null,
		Unit							nvarchar(20) null,
		PaddedUnit						nvarchar(50) null,
		UnitStreetAddress				nvarchar(200) null,
		UnitCity						nvarchar(200) null,
		UnitState						nvarchar(20) null,
		UnitZip							nvarchar(20) null,
		OccupiedStartDate				date null,
		OccupiedEndDate					date null,
		Amount							money null,
		GAMCAmount						money null,
		GRHAmount						money null,
		HadGovernmentAssistance			bit null,
		Caretaker						bit null,
		CaretakerAmount					money null,
		TaxID							nvarchar(100) null)
		
	CREATE TABLE #CRPOccupiedDays (
		UnitLeaseGroupID				uniqueidentifier not null,
		NumberOfDays					int not null,
		AmountPerDay					decimal(18, 10) null)
		
	CREATE TABLE #LITPCs (			-- The LedgerItemTypeIDs for the given property that are Payment/Credits allowed in CRP
		LedgerItemTypeID		uniqueidentifier not null)
		
	CREATE TABLE #LITCharges (		-- The LedgerItemTypeIDs for the given property that are allowed charges to be paid off
		LedgerItemTypeID		uniqueidentifier not null)
		
	CREATE TABLE #LITOther (		-- The LedgerItemTypeIDs for the given property that are other things, like subsidies or caretaker credits
		LedgerItemTypeID		uniqueidentifier not null,
		Flavor					nvarchar(10) not null)
		

	SET @yearStartDate = CAST((CAST(@year AS nvarchar(10)) + '-01-01') AS date)
	SET @yearEndDate = CAST((CAST(@year AS nvarchar(10)) + '-12-31') AS date)
	
	INSERT #CRPInfo
		SELECT  DISTINCT
				ulg.UnitLeaseGroupID,
				--l.LeaseID,
				'00000000-0000-0000-0000-000000000000',
				per.PersonID,					-- PersonID
				per.SpousePersonID,				-- SpousePersonID
				per.PreferredName + ' ' + per.LastName AS 'Name',		-- Name
				u.Number AS 'Unit',
				u.PaddedNumber AS 'PaddedUnit',
				addre.StreetAddress + ' ' + u.Number AS 'UnitStreetAddress',
				addre.City AS 'UnitCity',
				addre.[State] AS 'UnitState',
				addre.Zip AS 'UnitZip',
				CASE
					WHEN (@yearStartDate > pl.MoveInDate) THEN @yearStartDate
					ELSE pl.MoveInDate END AS 'OccupiedStartDate',
				CASE
					WHEN ((pl.MoveOutDate IS NULL) OR (@yearEndDate < pl.MoveOutDate)) THEN @yearEndDate
					ELSE pl.MoveOutDate END AS 'OccupiedEndDate',
				null,
				null,
				null,
				null,
				null,
				null,
				COALESCE(b.TaxID, prop.TaxID) AS 'TaxID'
			FROM [Transaction] t
				INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID
											AND tt.[Name] IN ('Payment', 'Credit') AND tt.[Group] = 'Lease'
				INNER JOIN LedgerItemTypeProperty litp ON t.LedgerItemTypeID = litp.LedgerItemTypeID AND t.PropertyID = litp.PropertyID
				INNER JOIN FormLedgerItemTypeProperty crplit ON litp.LedgerItemTypePropertyID = crplit.LedgerItemTypePropertyID
				INNER JOIN FormInformation fi ON crplit.FormInformationID = fi.FormInformationID AND fi.FormID = @formID
				INNER JOIN UnitLeaseGroup ulg ON t.ObjectID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON b.BuildingID = u.BuildingID
				INNER JOIN Property prop ON prop.PropertyID = b.PropertyID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID AND ut.PropertyID = litp.PropertyID AND ut.PropertyID = @propertyID
				INNER JOIN [Address] addre ON u.AddressID = addre.AddressID
				INNER JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
				  --AND l.LeaseID = (SELECT TOP 1 Lease.LeaseID 
						--			FROM Lease  
						--			INNER JOIN Ordering ON Lease.LeaseStatus = Ordering.[Value] AND Ordering.[Type] = 'Lease'
						--			WHERE Lease.UnitLeaseGroupID = ulg.UnitLeaseGroupID			     		 
						--			ORDER BY Ordering.OrderBy)
				-- Get the last PersonLease record for this person on the UnitLeaseGroup
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND pl.PersonLeaseID = (SELECT TOP 1 pl2.PersonLeaseID
																							FROM PersonLease pl2
																							INNER JOIN Lease l2 ON l2.LeaseID = pl2.LeaseID AND l2.UnitLeaseGroupID = ulg.UnitLeaseGroupID
																							WHERE pl2.PersonID = pl.PersonID
																								AND (pl2.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Approved', 'Pending'))	
																							ORDER BY l2.DateCreated DESC)			
				INNER JOIN Person per ON pl.PersonID = per.PersonID AND (@mainContactsOnly = 1 OR  per.Birthdate <= (DATEADD(YEAR, -17, @yearStartDate)))
			WHERE t.TransactionDate >= @yearStartDate AND t.TransactionDate <= @yearEndDate
			  AND (((SELECT COUNT(*) FROM @objectIDs) = 0) OR (t.ObjectID IN (SELECT Value FROM @objectIDs)))
			  AND ((@mainContactsOnly = 0) OR ((@mainContactsOnly = 1) AND pl.MainContact = 1))
			  AND (pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Approved', 'Pending'))	
			  AND (pl.MoveOutDate IS NULL OR pl.MoveOutDate >= @yearStartDate)
			  --AND pl.MoveInDate >= @yearStartDate 
			  AND pl.MoveInDate <= @yearEndDate		 			   	
 
	INSERT #CRPOccupiedDays
		SELECT UnitLeaseGroupID, SUM(ISNULL(1 + DATEDIFF(day, OccupiedStartDate, OccupiedEndDate), 0)), null
			FROM #CRPInfo
			GROUP BY UnitLeaseGroupID
			
	INSERT #LITPCs 
		SELECT DISTINCT litp.LedgerItemTypeID
			FROM LedgerItemTypeProperty litp
				INNER JOIN FormLedgerItemTypeProperty crplitp ON litp.LedgerItemTypePropertyID = crplitp.LedgerItemTypePropertyID
				INNER JOIN FormInformation fi ON crplitp.FormInformationID = fi.FormInformationID AND [Key] = 'Rent Payment'
			WHERE litp.PropertyID = @propertyID
			  AND fi.FormID = @formID
			  
	INSERT #LITCharges
		SELECT DISTINCT litp.LedgerItemTypeID
			FROM LedgerItemTypeProperty litp
				INNER JOIN FormLedgerItemTypeProperty crplitp ON litp.LedgerItemTypePropertyID = crplitp.LedgerItemTypePropertyID
				INNER JOIN FormInformation fi ON crplitp.FormInformationID = fi.FormInformationID AND [Key] = 'Charge'
			WHERE litp.PropertyID = @propertyID
			  AND fi.FormID = @formID				 
			  
	INSERT #LITOther
		SELECT DISTINCT litp.LedgerItemTypeID, fi.[Key]
			FROM LedgerItemTypeProperty litp
				INNER JOIN FormLedgerItemTypeProperty crplitp ON litp.LedgerItemTypePropertyID = crplitp.LedgerItemTypePropertyID
				INNER JOIN FormInformation fi ON crplitp.FormInformationID = fi.FormInformationID AND [Key] NOT IN ('Charge', 'Rent Payment', 'Year')
			WHERE litp.PropertyID = @propertyID
			  AND fi.FormID = @formID				
				  
	--SET @yearPercent = (SELECT CAST(Value1 AS decimal(8,6))/100.0
	--						FROM FormInformation 
	--						WHERE [Key] = 'YEAR'
	--						  AND CAST(Value AS int) = @year
	--						  AND FormID = @formID)	
	
	-- Get the amount of payments or credits that apply to charges of indicated "rent" transactions
	-- during the year
	UPDATE #CRPInfo SET Amount = ISNULL((SELECT SUM(ta.Amount)
		FROM #CRPInfo #crpi
			INNER JOIN [Transaction] ta ON #crpi.UnitLeaseGroupID = ta.ObjectID AND ta.PropertyID = @propertyID 
							AND ((ta.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITPCs)) OR (ta.LedgerItemTypeID IS NULL)) /* Second condition is for Deposits applied to balance */
			INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name IN ('Payment', 'Credit')
			INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID AND t.PropertyID = @propertyID
							AND t.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITCharges)
			LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID							
		WHERE ta.TransactionDate >= @yearStartDate
		  AND ta.TransactionDate <= @yearEndDate
		  AND #CRPInfo.UnitLeaseGroupID = #crpi.UnitLeaseGroupID
		  AND #CRPInfo.PersonID = #crpi.PersonID
		  AND tar.TransactionID IS NULL
		  AND ta.ReversesTransactionID IS NULL
		GROUP BY ta.ObjectID), 0)

	-- Add in the payments made based on the Caretaker credit.  The legislation states:
	-- "If the renter received reduced rent for being a caretaker or for providing other services,
	--  enter the rent the renter would have paid if he or she had not provided the services."
	
	-- ??Why does care taker take into account the OccupiedStartDate while everthing else uses year start date and end date??
	UPDATE #CRPInfo SET Amount = ISNULL(Amount, 0) + ISNULL((SELECT SUM(ta.Amount)
		FROM #CRPInfo #crpi
			INNER JOIN [Transaction] ta ON #crpi.UnitLeaseGroupID = ta.ObjectID AND ta.PropertyID = @propertyID
								AND ta.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITOther WHERE Flavor = 'Caretaker')
			INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name IN ('Credit', 'Payment')
			INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
								AND t.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITCharges)
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Charge'
			LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
		WHERE #CRPInfo.UnitLeaseGroupID = #crpi.UnitLeaseGroupID
		  AND ta.TransactionDate >= #crpi.OccupiedStartDate 
		  AND #CRPInfo.PersonID = #crpi.PersonID		  
		  AND ta.TransactionDate <= #crpi.OccupiedEndDate
		  AND tar.TransactionID IS NULL
		  AND ta.ReversesTransactionID IS NULL), 0)	


	UPDATE #CRPOccupiedDays SET AmountPerDay = (SELECT TOP 1 #crpi.Amount/CAST(#crpo.NumberOfDays AS decimal(18, 10))
		FROM #CRPOccupiedDays #crpo
			INNER JOIN #CRPInfo #crpi ON #crpi.UnitLeaseGroupID = #crpo.UnitLeaseGroupID
		WHERE #CRPOccupiedDays.UnitLeaseGroupID = #crpo.UnitLeaseGroupID
		  AND #crpo.NumberOfDays <> 0)
		
	UPDATE #CRPInfo SET Amount = (SELECT AmountPerDay * CAST(1 + DATEDIFF(DAY, #crpi.OccupiedStartDate, #crpi.OccupiedEndDate) AS DECIMAL(18,9))
		FROM #CRPInfo #crpi
			INNER JOIN #CRPOccupiedDays #crpo ON #crpi.UnitLeaseGroupID = #crpo.UnitLeaseGroupID
		WHERE #crpi.UnitLeaseGroupID = #CRPInfo.UnitLeaseGroupID
		  AND #crpi.PersonID = #CRPInfo.PersonID
		  --AND #crpi.OccupiedEndDate <> #crpi.OccupiedStartDate
		GROUP BY #crpi.PersonID, #crpi.OccupiedEndDate, #crpi.OccupiedStartDate, #crpo.AmountPerDay)

	UPDATE #CRPInfo SET Caretaker = ISNULL((SELECT TOP 1 1
		FROM #CRPInfo #crpi
			INNER JOIN [Transaction] ta ON #crpi.UnitLeaseGroupID = ta.ObjectID AND ta.PropertyID = @propertyID
								AND ta.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITOther WHERE Flavor = 'Caretaker')
			INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name IN ('Credit', 'Payment')
			INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
								AND t.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITCharges)
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Charge'
			LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
		WHERE #CRPInfo.UnitLeaseGroupID = #crpi.UnitLeaseGroupID
		  AND ta.TransactionDate >= #crpi.OccupiedStartDate 
		  AND ta.TransactionDate <= #crpi.OccupiedEndDate
		  AND tar.TransactionID IS NULL
		  AND ta.ReversesTransactionID IS NULL), CAST(0 AS BIT))

	UPDATE #CRPInfo SET CaretakerAmount = (SELECT SUM(ta.Amount)
		FROM #CRPInfo #crpi
			INNER JOIN [Transaction] ta ON #crpi.UnitLeaseGroupID = ta.ObjectID AND ta.PropertyID = @propertyID
								AND ta.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITOther WHERE Flavor = 'Caretaker')
			INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name IN ('Payment', 'Credit')
			INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
								AND t.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITCharges)
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Charge'
			LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
		WHERE #CRPInfo.UnitLeaseGroupID = #crpi.UnitLeaseGroupID
		  AND #CRPInfo.PersonID = #crpi.PersonID
		  AND ta.TransactionDate >= @yearStartDate
		  AND ta.TransactionDate <= @yearEndDate
		  AND tar.TransactionID IS NULL
		  AND ta.ReversesTransactionID IS NULL
		GROUP BY #crpi.PersonID)

	UPDATE #CRPInfo SET CaretakerAmount = ISNULL((SELECT (#crpi.CaretakerAmount/CAST(#crpo.NumberOfDays AS DECIMAL(18,9))) * CAST(1 + DATEDIFF(DAY, #crpi.OccupiedStartDate, #crpi.OccupiedEndDate) AS DECIMAL(18,9))
		FROM #CRPInfo #crpi
			INNER JOIN #CRPOccupiedDays #crpo ON #crpi.UnitLeaseGroupID = #crpo.UnitLeaseGroupID
		WHERE #crpi.UnitLeaseGroupID = #CRPInfo.UnitLeaseGroupID
		  AND #crpi.PersonID = #CRPInfo.PersonID
		  --AND #crpi.OccupiedEndDate <> #crpi.OccupiedStartDate
		GROUP BY #crpi.PersonID, #crpi.OccupiedEndDate, #crpi.OccupiedStartDate, #crpo.NumberOfDays, #crpi.CaretakerAmount), 0)
	
	UPDATE #CRPInfo SET GRHAmount = (SELECT SUM(ta.Amount)
		FROM #CRPInfo #crpi
			INNER JOIN [Transaction] ta ON #crpi.UnitLeaseGroupID = ta.ObjectID AND ta.PropertyID = @propertyID
								AND ta.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITOther WHERE Flavor = 'GRH')
			INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name IN ('Payment')
			INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
								AND t.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITCharges)
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Charge'
			LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
		WHERE #CRPInfo.UnitLeaseGroupID = #crpi.UnitLeaseGroupID
		  AND #CRPInfo.PersonID = #crpi.PersonID
		  AND ta.TransactionDate >= @yearStartDate
		  AND ta.TransactionDate <= @yearEndDate
		  AND tar.TransactionID IS NULL
		  AND ta.ReversesTransactionID IS NULL
		GROUP BY #crpi.PersonID)
		
	UPDATE #CRPInfo SET GRHAmount = ISNULL((SELECT (#crpi.GRHAmount/CAST(#crpo.NumberOfDays AS DECIMAL(18,9))) * CAST(1 + DATEDIFF(DAY, #crpi.OccupiedStartDate, #crpi.OccupiedEndDate) AS DECIMAL(18,9))
		FROM #CRPInfo #crpi
			INNER JOIN #CRPOccupiedDays #crpo ON #crpi.UnitLeaseGroupID = #crpo.UnitLeaseGroupID
		WHERE #crpi.UnitLeaseGroupID = #CRPInfo.UnitLeaseGroupID
		  AND #crpi.PersonID = #CRPInfo.PersonID
		  --AND #crpi.OccupiedEndDate <> #crpi.OccupiedStartDate
		GROUP BY #crpi.PersonID, #crpi.OccupiedEndDate, #crpi.OccupiedStartDate, #crpo.NumberOfDays, #crpi.GRHAmount), 0)
				
	UPDATE #CRPInfo SET GAMCAmount = (SELECT SUM(ta.Amount)
		FROM #CRPInfo #crpi
			INNER JOIN [Transaction] ta ON #crpi.UnitLeaseGroupID = ta.ObjectID AND ta.PropertyID = @propertyID
								AND ta.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITOther WHERE Flavor = 'GAMC')
			INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name IN ('Payment', 'Credit')
			INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
								AND t.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITCharges)
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Charge'
			LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
		WHERE #CRPInfo.UnitLeaseGroupID = #crpi.UnitLeaseGroupID
		  AND #CRPInfo.PersonID = #crpi.PersonID
		  AND ta.TransactionDate >= @yearStartDate
		  AND ta.TransactionDate <= @yearEndDate
		  AND tar.TransactionID IS NULL
		  AND ta.ReversesTransactionID IS NULL
		GROUP BY #crpi.PersonID)
		
	UPDATE #CRPInfo SET GAMCAmount = ISNULL((SELECT (#crpi.GAMCAmount/CAST(#crpo.NumberOfDays AS DECIMAL(18,9))) * CAST(1 + DATEDIFF(DAY, #crpi.OccupiedStartDate, #crpi.OccupiedEndDate) AS DECIMAL(18,9))
		FROM #CRPInfo #crpi
			INNER JOIN #CRPOccupiedDays #crpo ON #crpi.UnitLeaseGroupID = #crpo.UnitLeaseGroupID
		WHERE #crpi.UnitLeaseGroupID = #CRPInfo.UnitLeaseGroupID
		  AND #crpi.PersonID = #CRPInfo.PersonID
		  --AND #crpi.OccupiedEndDate <> #crpi.OccupiedStartDate
		GROUP BY #crpi.PersonID, #crpi.OccupiedEndDate, #crpi.OccupiedStartDate, #crpo.NumberOfDays, #crpi.GAMCAmount), 0)
								
	UPDATE #CRPInfo SET HadGovernmentAssistance = ISNULL((SELECT TOP 1 1
		FROM #CRPInfo #crpi
			INNER JOIN [Transaction] ta ON #crpi.UnitLeaseGroupID = ta.ObjectID AND ta.PropertyID = @propertyID
								AND ta.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITOther WHERE Flavor IN ('GRH', 'GAMC'))
			INNER JOIN TransactionType tta ON ta.TransactionTypeID = tta.TransactionTypeID AND tta.Name IN ('Payment', 'Credit')
			INNER JOIN [Transaction] t ON ta.AppliesToTransactionID = t.TransactionID
								AND t.LedgerItemTypeID IN (SELECT LedgerItemTypeID FROM #LITCharges)
			INNER JOIN TransactionType tt ON t.TransactionTypeID = tt.TransactionTypeID AND tt.Name = 'Charge'
			LEFT JOIN [Transaction] tar ON tar.ReversesTransactionID = ta.TransactionID
		WHERE #CRPInfo.UnitLeaseGroupID = #crpi.UnitLeaseGroupID
		  AND ta.TransactionDate >= #crpi.OccupiedStartDate 
		  AND ta.TransactionDate <= #crpi.OccupiedEndDate
		  AND tar.TransactionID IS NULL
		  AND ta.ReversesTransactionID IS NULL), CAST(0 AS BIT))

	SELECT * FROM #CRPInfo
		INNER JOIN #CRPOccupiedDays ON #CRPInfo.UnitLeaseGroupID = #CRPOccupiedDays.UnitLeaseGroupID
	WHERE
		Amount <> 0
		OR GAMCAmount <> 0
		OR GRHAmount <> 0
		OR CaretakerAmount <> 0
	ORDER BY UnitStreetAddress
	
END
GO
