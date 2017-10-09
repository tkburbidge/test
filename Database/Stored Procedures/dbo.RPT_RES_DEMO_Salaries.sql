SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: Jan. 26, 2015
-- Description:	Gets the data for the Resident Demographic salary or income report
-- =============================================
CREATE PROCEDURE [dbo].[RPT_RES_DEMO_Salaries] 
	-- Add the parameters for the stored procedure here
	@propertyIDs GuidCollection READONLY, 
	@date date = null,
	@residentDemographicsGroupingID uniqueidentifier
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @accountID bigint = (SELECT TOP 1 AccountID FROM Property WHERE PropertyID in (SELECT Value FROM @propertyIDs))

	CREATE TABLE #Properties (
		PropertyID uniqueidentifier NOT NULL)

	CREATE TABLE #OccupantsForAges
	(
		PropertyID uniqueidentifier,
		UnitID uniqueidentifier,
		UnitNumber nvarchar(50) null,
		UnitLeaseGroupID uniqueidentifier null,
		MoveInDate date null,
		MoveOutDate date null
	)
	
	CREATE TABLE #EmploymentAndPeeps (
		PropertyID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		UnitLeaseGroupID uniqueidentifier not null,
		LeaseID uniqueidentifier null,
		UnitNumber nvarchar(50) not null,
		PaddedNumber nvarchar(50) not null,
		EmploymentID uniqueidentifier null,
		Salary int null,
		SalaryPeriod nvarchar(50) null)
		
	CREATE TABLE #EmploymentTotals (
		PropertyID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		UnitLeaseGroupID uniqueidentifier not null,
		LeaseID uniqueidentifier null,
		UnitNumber nvarchar(50) not null,
		PaddedNumber nvarchar(50) not null,
		TotalSalary int null)
		
	CREATE TABLE #FinalNumbersReturnSet (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		UnitNumber nvarchar(50) not null,
		PaddedUnitNumber nvarchar(100) not null,
		UnitLeaseGroupID uniqueidentifier not null,
		Residents nvarchar(500)  null,
		AnnualIncome int not null)

	CREATE TABLE #EmploymentAndPets (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(500) null,
		PersonID uniqueidentifier null,
		UnitNumber nvarchar(50) null,
		PaddedUnitNumber nvarchar(50) null,
		UnitType nvarchar(250) null,
		LeaseID uniqueidentifier null,
		UnitLeaseGroupID uniqueidentifier null,
		ResidentName nvarchar(2000) null,
		Birthdate date null,
		Pets nvarchar(500),					-- Comma separated list of pets tied to this Person
		Rent money null,					-- Sum of rent LeaseLedgerItems tied to the lease in effect on the date of the report
		AnnualIncome int null,
		Industry nvarchar(500) null,			-- Industry of the employment record
		EmployerName nvarchar(500) null,
		EmployerCity nvarchar(500) null,
		EmployerZip nvarchar(200) null,
		PreviousCity nvarchar(500) null,		-- This will be the City of the Address record tied to the person with an address type of Prospect (if there is one)
		PreviousState nvarchar(500) null,
		MoveInDate date null,
		TrafficSource nvarchar(100)			-- Pull the first ProspectSource.Name associated with that person where PersonID = Prospect.PersonID OR PersonID = ProspectRoommate.PersonID
		)

	INSERT INTO #Properties
		SELECT Value 
			FROM @propertyIDs
	
	INSERT INTO #OccupantsForAges
		EXEC GetOccupantsByDate @accountID, @date, @propertyIDs
		
	INSERT INTO #EmploymentAndPeeps
		SELECT	DISTINCT
				prop.PropertyID,
				per.PersonID,
				#ofa.UnitLeaseGroupID,
				null,--l.LeaseID,
				#ofa.UnitNumber,
				u.PaddedNumber,
				emp.EmploymentID,
				sal.Amount,
				sal.SalaryPeriod
			FROM #Properties pIDs
				INNER JOIN Property prop ON pIds.PropertyID = prop.PropertyID
				INNER JOIN #OccupantsForAges #ofa ON pIDs.PropertyID = #ofa.PropertyID
				INNER JOIN Lease l ON #ofa.UnitLeaseGroupID = l.UnitLeaseGroupID
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID
				INNER JOIN Person per ON pl.PersonID = per.PersonID
				LEFT JOIN PickListItem pli ON pl.HouseholdStatus = pli.Name AND  pli.AccountID = @accountID 																						
				INNER JOIN Unit u ON #ofa.UnitID = u.UnitID
				LEFT JOIN Employment emp ON per.PersonID = emp.PersonID	
				LEFT JOIN Salary sal ON emp.EmploymentID = sal.EmploymentID
								AND sal.SalaryID = (SELECT TOP 1 SalaryID 
														FROM Salary
														WHERE EmploymentID = emp.EmploymentID
														  AND Amount IS NOT NULL
														  AND EffectiveDate <= @date
														ORDER BY EffectiveDate DESC, Amount DESC)
				-- Either they are a current resident or their move out date is in the future
			WHERE (pl.ResidencyStatus NOT IN ('Cancelled', 'Denied', 'Pending', 'Pending Transfer') AND (pl.MoveOutDate IS NULL OR pl.ResidencyStatus NOT IN ('Former', 'Evicted') OR pl.MoveOutDate >= @date))
			  AND (pli.IsNotOccupant IS NULL OR pli.IsNotOccupant = 0) -- Need to allow for HUD household statuses
			  -- They moved in before the date
			  AND pl.MoveInDate <= @date
			  -- There is no employment record or the employment record was in effect on the date
			  AND ((emp.EmploymentID IS NULL) OR ((emp.StartDate IS NULL OR emp.StartDate <= @date) AND (emp.EndDate IS NULL OR emp.EndDate >= @date)))
PRINT '1'
	-- Delete records that don't have a salary when there is another entry that has a salary for that same unit lease group
	DELETE #ep
		FROM #EmploymentAndPeeps #ep
			INNER JOIN #EmploymentAndPeeps #ep2 ON #ep.UnitLeaseGroupID = #ep2.UnitLeaseGroupID AND #ep2.Salary IS NOT NULL
		WHERE #ep.Salary IS NULL

	UPDATE #EmploymentAndPeeps SET EmploymentID = NULL WHERE EmploymentID IS NOT NULL AND Salary IS NULL

	-- Get the last lease where the date is in the lease date range
		UPDATE eap
			 SET LeaseID = l.LeaseID				 
		FROM #EmploymentAndPeeps eap
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
		FROM #EmploymentAndPeeps eap
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
		FROM #EmploymentAndPeeps eap
			INNER JOIN Lease l ON l.UnitLeaseGroupID = eap.UnitLeaseGroupID
		WHERE eap.UnitLeaseGroupID IS NOT NULL
			AND eap.LeaseID IS NULL
			AND (l.LeaseID = (SELECT TOP 1 LeaseID			
								FROM Lease 
								WHERE UnitLeaseGroupID = l.UnitLeaseGroupID							 
								AND LeaseStatus IN ('Current', 'Under Eviction', 'Former', 'Evicted', 'Renewed')
								ORDER BY LeaseStartDate))			 
PRINT '2'
	INSERT #EmploymentAndPets
		SELECT	DISTINCT
				prop.PropertyID,
				prop.Name,
				per.PersonID,
				u.Number,
				u.PaddedNumber,
				ut.Name AS 'UnitType',
				l.LeaseID,
				l.UnitLeaseGroupID,
				per.PreferredName + ' ' + per.LastName AS 'ResidentName',
				per.Birthdate,
				STUFF((SELECT ', ' + Name
							  FROM Pet
							  WHERE PersonID = per.PersonID
							  FOR XML PATH ('')), 1, 2, '') AS 'Pets',
				null AS 'Rent',
				(CASE
						WHEN (#eap.SalaryPeriod = 'Annually') THEN #eap.Salary
						WHEN (#eap.SalaryPeriod = 'Monthly') THEN (#eap.Salary * 12.0)
						WHEN (#eap.SalaryPeriod = 'Biweekly') THEN (#eap.Salary * 26.0)
						WHEN (#eap.SalaryPeriod = 'Weekly') THEN (#eap.Salary * 52.0)
						ELSE -1
						END) AS 'AnnualIncome',
				(CASE WHEN emp.[Type] = 'Other' AND Industry = 'Other Income' THEN 'Other'
					  ELSE emp.Industry
				 END) AS 'Industry',				
				emp.Employer,
				addr.City,
				addr.Zip,
				null AS 'PreviousCity',
				null AS 'PreviousState',
				pl.MoveInDate,
				null AS 'TrafficSource'
			FROM #EmploymentAndPeeps #eap
				INNER JOIN Property prop ON #eap.PropertyID = prop.PropertyID				
				INNER JOIN UnitLeaseGroup ulg ON ulg.UnitLeaseGroupID = #eap.UnitLeaseGroupID
				INNER JOIN Lease l ON #eap.LeaseID = l.LeaseID				
				INNER JOIN PersonLease pl ON l.LeaseID = pl.LeaseID AND #eap.PersonID = pl.PersonID
				INNER JOIN Person per ON pl.PersonID = per.PersonID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				LEFT JOIN Employment emp ON #eap.EmploymentID = emp.EmploymentID
				LEFT JOIN [Address] addr ON emp.AddressID = addr.AddressID				
PRINT '3'			
	UPDATE #EmploymentAndPets SET Rent = (SELECT SUM(lli.Amount)
											  FROM LeaseLedgerItem lli
												  INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
												  INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
											  WHERE lli.StartDate <= @date
											    AND lli.EndDate >= @date
												AND lit.IsRent = 1
												AND lli.LeaseID = #EmploymentAndPets.LeaseID)

	UPDATE #EmploymentAndPets SET TrafficSource = (SELECT TOP 1 ps.Name
													   FROM ProspectSource ps
														   INNER JOIN PropertyProspectSource pps ON ps.ProspectSourceID = pps.ProspectSourceID
														   INNER JOIN Prospect pros ON pps.PropertyProspectSourceID = pros.PropertyProspectSourceID
													   WHERE pros.PersonID = #EmploymentAndPets.PersonID)

	UPDATE #EmploymentAndPets SET TrafficSource = (SELECT TOP 1 ps.Name
													   FROM ProspectSource ps
														   INNER JOIN PropertyProspectSource pps ON ps.ProspectSourceID = pps.ProspectSourceID
														   INNER JOIN Prospect pros ON pps.PropertyProspectSourceID = pros.PropertyProspectSourceID
														   INNER JOIN ProspectRoommate pRoom ON pros.ProspectID = pRoom.ProspectID
													   WHERE pRoom.PersonID = #EmploymentAndPets.PersonID)
		WHERE TrafficSource IS NULL

	UPDATE #EAPets SET PreviousCity = addr.City, PreviousState = addr.[State]
		FROM #EmploymentAndPets #EAPets
			INNER JOIN [Address] addr ON #EAPets.PersonID = addr.ObjectID AND addr.AddressType = 'Prospect'

	INSERT #EmploymentTotals
		SELECT	PropertyID,
				PersonID, 
				UnitLeaseGroupID,
				LeaseID,
				UnitNumber,
				PaddedNumber,
				SUM(CASE
						WHEN (SalaryPeriod = 'Annually') THEN Salary
						WHEN (SalaryPeriod = 'Monthly') THEN (Salary * 12.0)
						WHEN (SalaryPeriod = 'Biweekly') THEN (Salary * 26.0)
						WHEN (SalaryPeriod = 'Weekly') THEN (Salary * 52.0)
						ELSE -1
						END)
			FROM #EmploymentAndPeeps
			GROUP BY PropertyID, PersonID, UnitLeaseGroupID, PaddedNumber, UnitNumber, LeaseID
PRINT '4'
	INSERT #FinalNumbersReturnSet
		SELECT	#et.PropertyID,
				prop.Name AS 'PropertyName',
				#et.UnitNumber,
				#et.PaddedNumber AS 'PaddedUnitNumber',
				#et.UnitLeaseGroupID,
				STUFF((SELECT ', ' + (PreferredName + ' ' + LastName)
						 FROM Person 
							 INNER JOIN PersonLease ON Person.PersonID = PersonLease.PersonID		
							 INNER JOIN Lease l ON l.LeaseID = PersonLease.LeaseID
							 INNER JOIN PersonType ON Person.PersonID = PersonType.PersonID
							 INNER JOIN PersonTypeProperty ON PersonType.PersonTypeID = PersonTypeProperty.PersonTypeID
						 WHERE PersonLease.LeaseID = l.LeaseID
							   AND PersonType.[Type] = 'Resident'				   
							   AND PersonLease.MainContact = 1
							   AND l.LeaseID = ((SELECT TOP 1 LeaseID
												FROM Lease 
												INNER JOIN Ordering o ON o.Value = Lease.LeaseStatus AND o.[Type] = 'Lease'
												WHERE UnitLeaseGroupID = #et.UnitLeaseGroupID
												ORDER BY o.OrderBy))
						 ORDER BY PersonLease.OrderBy, PersonLease.PersonLeaseID							   				   
						 FOR XML PATH ('')), 1, 2, '') AS 'Residents',			
				ISNULL(SUM(#et.TotalSalary), 0) AS 'AnnualIncome'		
			FROM #EmploymentTotals #et
				INNER JOIN Property prop ON #et.PropertyID = prop.PropertyID
			GROUP BY #et.PropertyID, prop.Name, #et.PaddedNumber, #et.UnitNumber, #et.UnitLeaseGroupID, #et.LeaseID
			
	SELECT	#et.PropertyID,
			prop.Name AS 'PropertyName',
			rdgd.Low AS 'GroupLow',
			rdgd.High AS 'GroupHigh',
			--COUNT(*) AS 'Count'
			SUM(CASE
					WHEN (#et.AnnualIncome < 0) THEN 0
					WHEN (rdgd.Low IS NULL AND rdgd.High IS NULL AND #et.AnnualIncome IS NULL) THEN 1
					WHEN (rdgd.Low IS NULL AND #et.AnnualIncome <= rdgd.High) THEN 1
					WHEN (rdgd.High IS NULL AND #et.AnnualIncome >= rdgd.Low) THEN 1
					WHEN (#et.AnnualIncome >= rdgd.Low AND #et.AnnualIncome <= rdgd.High) THEN 1
					ELSE 0
					END) AS 'Count'
		--FROM #EmploymentTotals #et
		FROM #FinalNumbersReturnSet #et
			INNER JOIN ResidentDemographicsGroupingDetail rdgd ON rdgd.ResidentDemographicsGroupingID = @residentDemographicsGroupingID
			INNER JOIN Property prop ON #et.PropertyID = prop.PropertyID
		GROUP BY #et.PropertyID, prop.Name, rdgd.Low, rdgd.High
		ORDER BY #et.PropertyID, 
			CASE WHEN (rdgd.High IS NULL) THEN 1111111111
				 ELSE rdgd.High
				 END,
			CASE WHEN (rdgd.Low IS NULL) THEN 1111111111
				 ELSE rdgd.Low
				 END	
				 
	SELECT *
		FROM #FinalNumbersReturnSet

	SELECT * 
		FROM #EmploymentAndPets
					 

END
GO
