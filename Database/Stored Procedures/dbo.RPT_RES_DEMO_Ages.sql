SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 26, 2015
-- Description:	Generates the data for the Resident Demographic report, age section
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_DEMO_Ages] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @accountID bigint = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID in (SELECT Value FROM @propertyIDs))

	CREATE TABLE #OccupantsForAges
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null
	)

	CREATE TABLE #OccupantsForAgesWithLeaseID
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null,
		LeaseID uniqueidentifier null
	)
	
	CREATE TABLE #AgeRanges
	(
		PropertyID uniqueidentifier NULL,
		AR0017 int NULL,
		AR1825 int NULL,
		AR2635 int NULL,
		AR3645 int NULL,
		AR4655 int NULL,
		AR56Up int NULL,
		Unknown int NULL
	)
	
	INSERT INTO #OccupantsForAges
		EXEC GetOccupantsByDate @accountID, @date, @propertyIDs

	INSERT INTO #OccupantsForAgesWithLeaseID
		SELECT *, null
			FROM #OccupantsForAges

	 --Get the last lease where the date is in the lease date range
		UPDATE eap
			 SET LeaseID = l.LeaseID				 
		FROM #OccupantsForAgesWithLeaseID eap
			INNER JOIN Lease l ON l.UnitLeaseGroupID = eap.UnitLeaseGroupID
		WHERE eap.UnitLeaseGroupID IS NOT NULL
			AND (l.LeaseID = (SELECT TOP 1 LeaseID			
								FROM Lease 								
								WHERE UnitLeaseGroupID = l.UnitLeaseGroupID
								  AND LeaseStartDate <= @date
								  AND LeaseEndDate >= @date
								  AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
								ORDER BY DateCreated DESC))
		
		-- Get the last lease where the EndDate <= @date (Month-to-Month Leases) 
		UPDATE eap
			 SET LeaseID = l.LeaseID				 
		FROM #OccupantsForAgesWithLeaseID eap
			INNER JOIN Lease l ON l.UnitLeaseGroupID = eap.UnitLeaseGroupID
		WHERE eap.UnitLeaseGroupID IS NOT NULL
			AND eap.LeaseID IS NULL
			AND (l.LeaseID = (SELECT TOP 1 LeaseID			
								FROM Lease 								
								WHERE UnitLeaseGroupID = l.UnitLeaseGroupID								  
								  AND LeaseEndDate <= @date
								  AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
								ORDER BY LeaseEndDate DESC))
		 

		-- For the messed up lease entries, grab the first lease
		-- associated with the UnitLeaseGroup
		UPDATE eap
			 SET LeaseID = l.LeaseID				 				 
		FROM #OccupantsForAgesWithLeaseID eap
			INNER JOIN Lease l ON l.UnitLeaseGroupID = eap.UnitLeaseGroupID
		WHERE eap.UnitLeaseGroupID IS NOT NULL
			AND eap.LeaseID IS NULL
			AND (l.LeaseID = (SELECT TOP 1 LeaseID			
								FROM Lease 
								WHERE UnitLeaseGroupID = l.UnitLeaseGroupID							 
								AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
								ORDER BY LeaseStartDate))		

	INSERT INTO #AgeRanges
		SELECT Value, 0, 0, 0, 0, 0, 0, 0
			FROM @propertyIDs
	
	UPDATE #AgeRanges SET AR0017 = ISNULL((SELECT COUNT(DISTINCT per.PersonID)
											FROM Person per
												INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID
												INNER JOIN #OccupantsForAgesWithLeaseID #ofa ON #ofa.LeaseID = pl.LeaseID
												LEFT JOIN PickListItem pli ON pl.HouseholdStatus = pli.Name AND pli.AccountID = @accountID																					
											WHERE pl.MoveInDate <= @date
											  AND (pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Pending', 'Pending Transfer') AND (pl.MoveOutDate IS NULL OR pl.ResidencyStatus NOT IN ('Former', 'Evicted') OR pl.MoveOutDate >= @date))
											  AND @date >= DATEADD(YEAR, 0, per.BirthDate)
											  AND @date < DATEADD(YEAR, 18, per.BirthDate)
											  AND #ofa.PropertyID = #AgeRanges.PropertyID
											  AND (pli.IsNotOccupant IS NULL OR pli.IsNotOccupant = 0)
											GROUP BY #ofa.PropertyID), 0)
														
	UPDATE #AgeRanges SET AR1825 = ISNULL((SELECT COUNT(DISTINCT per.PersonID)
												FROM Person per
													INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID
													INNER JOIN #OccupantsForAgesWithLeaseID #ofa ON #ofa.LeaseID = pl.LeaseID
													LEFT JOIN PickListItem pli ON pl.HouseholdStatus = pli.Name AND pli.AccountID = @accountID 
												WHERE pl.MoveInDate <= @date
												  AND (pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Pending', 'Pending Transfer') AND (pl.MoveOutDate IS NULL OR pl.ResidencyStatus NOT IN ('Former', 'Evicted') OR pl.MoveOutDate >= @date))
												  AND @date >= DATEADD(YEAR, 18, per.BirthDate)
												  AND @date < DATEADD(YEAR, 26, per.BirthDate)
												  AND #ofa.PropertyID = #AgeRanges.PropertyID
												  AND (pli.IsNotOccupant IS NULL OR pli.IsNotOccupant = 0)
												GROUP BY #ofa.PropertyID), 0)
										
	UPDATE #AgeRanges SET AR2635 = ISNULL((SELECT COUNT(DISTINCT per.PersonID)
												FROM Person per
													INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID
													INNER JOIN #OccupantsForAgesWithLeaseID #ofa ON #ofa.LeaseID = pl.LeaseID
													LEFT JOIN PickListItem pli ON pl.HouseholdStatus = pli.Name AND  pli.AccountID = @accountID 																						
												WHERE pl.MoveInDate <= @date
											      AND (pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Pending', 'Pending Transfer') AND (pl.MoveOutDate IS NULL OR pl.ResidencyStatus NOT IN ('Former', 'Evicted') OR pl.MoveOutDate >= @date))
												  AND @date >= DATEADD(YEAR, 26, per.Birthdate)
												  AND @date < DATEADD(YEAR, 36, per.Birthdate)
												  AND #ofa.PropertyID = #AgeRanges.PropertyID
												  AND (pli.IsNotOccupant IS NULL OR pli.IsNotOccupant = 0)
												GROUP BY #ofa.PropertyID), 0)
										
	UPDATE #AgeRanges SET AR3645 = ISNULL((SELECT COUNT(DISTINCT per.PersonID)
												FROM Person per
													INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID
													INNER JOIN #OccupantsForAgesWithLeaseID #ofa ON #ofa.LeaseID = pl.LeaseID
													LEFT JOIN PickListItem pli ON pl.HouseholdStatus = pli.Name AND  pli.AccountID = @accountID 
												WHERE pl.MoveInDate <= @date
											      AND (pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Pending', 'Pending Transfer') AND (pl.MoveOutDate IS NULL OR pl.ResidencyStatus NOT IN ('Former', 'Evicted') OR pl.MoveOutDate >= @date))
												  AND @date >= DATEADD(YEAR, 36, per.Birthdate)
												  AND @date < DATEADD(YEAR, 46, per.Birthdate)
												  AND #ofa.PropertyID = #AgeRanges.PropertyID
												  AND (pli.IsNotOccupant IS NULL OR pli.IsNotOccupant = 0)
												GROUP BY #ofa.PropertyID), 0)
																				
	UPDATE #AgeRanges SET AR4655 = ISNULL((SELECT COUNT(DISTINCT per.PersonID)
												FROM Person per
													INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID
													INNER JOIN #OccupantsForAgesWithLeaseID #ofa ON #ofa.LeaseID = pl.LeaseID
													LEFT JOIN PickListItem pli ON pl.HouseholdStatus = pli.Name AND  pli.AccountID = @accountID 																						
												WHERE pl.MoveInDate <= @date
												  AND (pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Pending', 'Pending Transfer') AND (pl.MoveOutDate IS NULL OR pl.ResidencyStatus NOT IN ('Former', 'Evicted') OR pl.MoveOutDate >= @date))
												  AND @date >= DATEADD(YEAR, 46, per.BirthDate)
												  AND @date < DATEADD(YEAR, 56, per.BirthDate)
												  AND #ofa.PropertyID = #AgeRanges.PropertyID
												  AND (pli.IsNotOccupant IS NULL OR pli.IsNotOccupant = 0)
												GROUP BY #ofa.PropertyID), 0)
										
	UPDATE #AgeRanges SET AR56Up = ISNULL((SELECT COUNT(DISTINCT per.PersonID)
												FROM Person per
													INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID
													INNER JOIN #OccupantsForAgesWithLeaseID #ofa ON #ofa.LeaseID = pl.LeaseID
													LEFT JOIN PickListItem pli ON pl.HouseholdStatus = pli.Name AND  pli.AccountID = @accountID																						
												WHERE pl.MoveInDate <= @date
											      AND (pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Pending', 'Pending Transfer') AND (pl.MoveOutDate IS NULL OR pl.ResidencyStatus NOT IN ('Former', 'Evicted') OR pl.MoveOutDate >= @date))
												  AND @date >= DATEADD(YEAR, 56, per.BirthDate)
												  AND #ofa.PropertyID = #AgeRanges.PropertyID
												  AND (pli.IsNotOccupant IS NULL OR pli.IsNotOccupant = 0)
												GROUP BY #ofa.PropertyID), 0)
										
	UPDATE #AgeRanges SET Unknown = ISNULL((SELECT COUNT(DISTINCT per.PersonID)
												FROM Person per
													INNER JOIN PersonLease pl ON per.PersonID = pl.PersonID
													INNER JOIN #OccupantsForAgesWithLeaseID #ofa ON #ofa.LeaseID = pl.LeaseID
													LEFT JOIN PickListItem pli ON pl.HouseholdStatus = pli.Name AND  pli.AccountID = @accountID 																						
												WHERE pl.MoveInDate <= @date
												  AND (pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Pending', 'Pending Transfer') AND (pl.MoveOutDate IS NULL OR pl.ResidencyStatus NOT IN ('Former', 'Evicted') OR pl.MoveOutDate >= @date))
												  AND per.Birthdate IS NULL
												  AND #ofa.PropertyID = #AgeRanges.PropertyID
												  AND (pli.IsNotOccupant IS NULL OR pli.IsNotOccupant = 0)
												GROUP BY #ofa.PropertyID), 0)										
								
								
	SELECT	prop.PropertyID,
			prop.Name AS 'PropertyName',
			#ag.AR0017,
			#ag.AR1825,
			#ag.AR2635,
			#ag.AR3645,
			#ag.AR4655,
			#ag.AR56Up,
			#ag.Unknown
		FROM #AgeRanges #ag
			INNER JOIN Property prop ON #ag.PropertyID = prop.PropertyID

END
GO
