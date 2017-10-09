SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Rick Bertelsen
-- Create date: April 21, 2015
-- Description:	Gets the CIG Resident Data Dump
-- =============================================
CREATE PROCEDURE [dbo].[RPT_CST_CIG_ResidentDataDump] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = 0, 
	@propertyIDs GuidCollection READONLY,
	@leaseStatuses StringCollection READONLY
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	CREATE TABLE #MyReturnValues (
		LeaseID uniqueidentifier null,
		StreetAddress nvarchar(100) null,
		City nvarchar(50) null,
		[State] nvarchar(50) null,
		Zip nvarchar(12) null,
		PhoneNumber nvarchar(50) null,
		EmailAddress nvarchar(200) null,
		ReasonMoved nvarchar(200) null,
		LeasingAgent nvarchar(100) null,
		UnitShown bit null,							--10
		UnitShownDate [Date] null,
		ApplicationDate [Date] null,
		ProspectUnitTypeDesired nvarchar(50) null,
		MarketingSource nvarchar(50) null,
		UnitNumber nvarchar(50) null,
		[Floor] nvarchar(3) null,
		Floorplan nvarchar(100) null,
		RentCharges money null,
		StartDate [Date] null,
		EndDate [Date] null,						--20
		NumberOfOccupants int null,
		AgeOfOldOccupant int null,
		AgeOfOtherOccupant int null,
		CurrentEmployer nvarchar(100) null,
		EmploymentStatus nvarchar(50) null,
		EmploymentStreetAddress nvarchar(100) null,
		EmploymentCity nvarchar(50) null,
		EmploymentState nvarchar(50) null,
		EmploymentZip nvarchar(15) null,
		MonthlyIncome money null,					--30
		OtherIncome money null,
		ApplicationDecision nvarchar(100) null,
		FidoYes bit null,							--33
		FluffyYes bit null,
		NumberOfCars int null,
		CarMake1 nvarchar(100) null,
		CarModel1 nvarchar(100) null,
		CarMake2 nvarchar(100) null,
		CarModel2 nvarchar(100) null,
		LeaseRenewal bit null,						--40
		NumberOfRenewals int null,
		PreviousUnitNumber nvarchar(50) null,
		PreviousFloor nvarchar(50) null,
		PreviousFloorPlan nvarchar(50) null,
		MonthsLateRent int null)					--45
		
	CREATE TABLE #MyLeases (
		LeaseID uniqueidentifier not null,
		UnitLeaseGroupID uniqueidentifier not null,
		PreviousULG uniqueidentifier null)
		
	CREATE TABLE #MyLeasesAndPeeps (
		LeaseID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		EmploymentID uniqueidentifier null,
		Salary money null,
		OtherIncome money null)
		
	CREATE TABLE #HowOldIs2Old4APonyTail (
		LeaseID uniqueidentifier not null,
		OldPersonID uniqueidentifier null,
		OldPersonBirthday date null,
		OldPerson2ID uniqueidentifier null,
		OldPerson2Birthday date null)
		
	CREATE TABLE #MyCars (
		LeaseID uniqueidentifier not null,
		Auto1ID uniqueidentifier null,
		Auto2ID uniqueidentifier null)
		
	CREATE TABLE #MyProperties (
		PropertyID uniqueidentifier not null)
		
	CREATE TABLE #MyStatuses (
		LeaseStatus nvarchar(50) not null)		
		
	INSERT #MyProperties
		SELECT Value FROM @propertyIDs
		
	INSERT #MyStatuses 
		SELECT Value FROM @leaseStatuses
		
	INSERT #MyLeases 
		SELECT	l.LeaseID, ulg.UnitLeaseGroupID, ulg.PreviousUnitLeaseGroupID
			FROM Lease l
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN #MyProperties #myP ON ut.PropertyID = #myP.PropertyID
				INNER JOIN #MyStatuses #myS ON l.LeaseStatus = #myS.LeaseStatus

	INSERT #MyLeasesAndPeeps 
		SELECT	pl.LeaseID, pl.PersonID, null, null, null
			FROM #MyLeases #myL
				INNER JOIN PersonLease pl ON #myL.LeaseID = pl.LeaseID	
	
	UPDATE #MyLeasesAndPeeps SET EmploymentID = (SELECT TOP 1 emp.EmploymentID
													FROM #MyLeasesAndPeeps #myLaP
														INNER JOIN Employment emp ON #myLaP.PersonID = emp.PersonID
														INNER JOIN Salary sal ON emp.EmploymentID = sal.EmploymentID
																			AND sal.SalaryID = (SELECT TOP 1 SalaryID
																									FROM Salary
																									WHERE EmploymentID = emp.EmploymentID
																									  AND Amount IS NOT NULL
																									ORDER BY EffectiveDate DESC, Amount DESC)
													WHERE #myLaP.PersonID = #MyLeasesAndPeeps.PersonID
													ORDER BY 
														CASE WHEN (sal.SalaryPeriod = 'Yearly' OR sal.SalaryPeriod = 'Annually') THEN -sal.Amount
															 WHEN (sal.SalaryPeriod = 'Monthly') THEN -sal.Amount * 12.0
															 WHEN (sal.SalaryPeriod = 'Biweekly') THEN -sal.Amount * 26.0
															 WHEN (sal.SalaryPeriod = 'Weekly') THEN -sal.Amount * 52.0
															 ELSE sal.Amount END)
															 
	UPDATE #MyLeasesAndPeeps SET Salary = (SELECT CASE WHEN (sal.SalaryPeriod = 'Yearly' OR sal.SalaryPeriod = 'Annually') THEN sal.Amount
													   WHEN (sal.SalaryPeriod = 'Monthly') THEN sal.Amount * 12.0
													   WHEN (sal.SalaryPeriod = 'Biweekly') THEN sal.Amount * 26.0
													   WHEN (sal.SalaryPeriod = 'Weekly') THEN sal.Amount * 52.0
													   ELSE sal.Amount END											
											   FROM Employment emp
												   INNER JOIN Salary sal ON emp.EmploymentID = sal.EmploymentID
											   WHERE EmploymentID = #MyLeasesAndPeeps.EmploymentID)
											   
	UPDATE #MyLeasesAndPeeps SET OtherIncome = (SELECT ISNULL(SUM(CASE WHEN (sal.SalaryPeriod = 'Yearly' OR sal.SalaryPeriod = 'Annually') THEN sal.Amount
																	   WHEN (sal.SalaryPeriod = 'Monthly') THEN sal.Amount * 12.0
													                   WHEN (sal.SalaryPeriod = 'Biweekly') THEN sal.Amount * 26.0
													                   WHEN (sal.SalaryPeriod = 'Weekly') THEN sal.Amount * 52.0
													                   ELSE sal.Amount END), 0)										
													FROM Employment emp
														INNER JOIN Salary sal ON emp.EmploymentID = sal.EmploymentID
													WHERE PersonID = #MyLeasesAndPeeps.PersonID
													  AND EmploymentID <> #MyLeasesAndPeeps.EmploymentID)
													  
--select * from #MyLeasesAndPeeps
													  
	INSERT #MyReturnValues
		SELECT  DISTINCT
				#myL.LeaseID,
				CASE
					WHEN (u.AddressIncludesUnitNumber = 1) THEN ad.StreetAddress
					ELSE ad.StreetAddress + ' Nu ' + u.Number END AS 'StreetAddress',
				ad.City,
				ad.[State],
				ad.Zip,
				null,		--PhoneNumber											CHECK!
				null,		--EmailAddress											CHECK!
				null,		--ReasonMoved,
				per.PreferredName + ' ' + per.LastName,		--LeasingAgent,
				0,			--UnitShown, will be set with Update if true.
				null,		--UnitShownDate
				null,		--ApplicationDate
				null,		--ProspectUnitTypeDesired
				null,		--MarketingSource
				u.Number,
				u.[Floor],
				ut.Name,	--Floorplan
				0.00,		--RentCharges
				l.LeaseStartDate,
				l.LeaseEndDate,
				0,			--NumberOfOccupants
				0,			--AgeOfOldOccupant
				0,			--AgeOfOtherOccupant
				null,		--CurrentEmployer										CHECK!
				null,		--EmploymentStatus										CHECK!
				null,		--EmploymentStreetAddress								CHECK!
				null,		--EmploymentCity										CHECK!
				null,		--EmploymentState										CHECK!
				null,		--EmploymentZip											CHECK!
				null,		--MonthlyIncome											CHECK!
				null,		--OtherIncome
				null,		--ApplicationDecision,
				0 as 'Fido',			--FidoYes,
				0,			--FluffyYes,
				0,			--NumberOfCars
				null,		--CarMake1
				null,		--CarModel1
				null,		--CarMake2
				null,		--CarModel2
				0,			--LeaseRenewal
				0,			--NumberOfRenewals
				null,		--PreviousUnitNumber
				null,		--PreviousFloor
				null,		--PreviousFloorPlan
				0			--MonthsLateRent				
			FROM #MyLeases #myL
				INNER JOIN UnitLeaseGroup ulg ON #myL.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN [Address] ad ON u.AddressID = ad.AddressID
				INNER JOIN Lease l ON #myL.LeaseID = l.LeaseID
				LEFT JOIN Person per ON l.LeasingAgentPersonID = per.PersonID
			  
	UPDATE #mrv	SET	PhoneNumber = per.Phone1, 
					EmailAddress = per.Email, 
					CurrentEmployer = emp.Employer,
					EmploymentStatus = CASE
											WHEN (emp.EndDate IS NULL OR emp.EndDate > GETDATE()) THEN 'Employed'
											WHEN (emp.EmploymentID IS NULL) THEN 'Unemployed'
											ELSE 'Unknown' END,
					EmploymentStreetAddress = empAdd.StreetAddress,
					EmploymentCity = empAdd.City,
					EmploymentState = empAdd.[State],
					EmploymentZip = empAdd.Zip/*,
					MonthlyIncome = #mlap.Salary / 12.0*/
		FROM #MyReturnValues #mrv
			INNER JOIN #MyLeasesAndPeeps #mlap ON #mrv.LeaseID = #mlap.LeaseID
			INNER JOIN Person per ON #mlap.PersonID = per.PersonID
			INNER JOIN Employment emp ON per.PersonID = emp.PersonID 
						AND emp.EmploymentID = (SELECT TOP 1 EmploymentID	
													FROM #MyLeasesAndPeeps 
													WHERE LeaseID = #mrv.LeaseID
													ORDER BY #mlap.Salary)
			INNER JOIN [Address] empAdd ON emp.AddressID = empAdd.AddressID
			
	UPDATE #MyReturnValues SET MonthlyIncome = (SELECT ISNULL(SUM(Salary), 0)
													FROM #MyLeasesAndPeeps 
													WHERE LeaseID = #MyReturnValues.LeaseID
													GROUP BY LeaseID)
													
	UPDATE #MyReturnValues SET OtherIncome = (SELECT ISNULL(SUM(OtherIncome), 0)
													FROM #MyLeasesAndPeeps 
													WHERE LeaseID = #MyReturnValues.LeaseID
													GROUP BY LeaseID)													
			
	UPDATE #mrv SET PhoneNumber = per.Phone1,
					EmailAddress = per.Email
		FROM #MyReturnValues #mrv 
			INNER JOIN #MyLeasesAndPeeps #mlap ON #mrv.LeaseID = #mlap.LeaseID
			INNER JOIN PersonLease pl ON pl.PersonID = #mlap.PersonID 
						AND pl.PersonID = (SELECT TOP 1 PersonID
												FROM PersonLease
												WHERE LeaseID = #mlap.LeaseID
												  AND HouseholdStatus IN ('Head of Household'))
			INNER JOIN Person per ON pl.PersonID = per.PersonID
		WHERE #mrv.PhoneNumber IS NULL
		
	UPDATE #MyReturnValues SET ApplicationDecision = (SELECT TOP 1 ass.ApplicationDecision
														FROM #MyReturnValues #mrv
															INNER JOIN #MyLeasesAndPeeps #mlap ON #mrv.LeaseID = #mlap.LeaseID
															INNER JOIN Prospect pros ON #mlap.PersonID = pros.PersonID
															INNER JOIN ApplicantScreeningPerson asp ON pros.PersonID = asp.PersonID
															INNER JOIN ApplicantScreening ass ON asp.ApplicantScreeningID = ass.ApplicantScreeningID
														WHERE #mrv.LeaseID = #MyReturnValues.LeaseID
														ORDER BY ass.DateRequested)

	UPDATE #MyReturnValues SET NumberOfOccupants = (SELECT COUNT(*)
														FROM PersonLease 
														WHERE LeaseID = #MyReturnValues.LeaseID
														  AND ResidencyStatus NOT IN ('Former', 'Evicted'))	
														  
	UPDATE #MyReturnValues SET ApplicationDate = (SELECT MIN(ApplicationDate)
													  FROM PersonLease
													  WHERE LeaseID = #MyReturnValues.LeaseID
													    AND ResidencyStatus NOT IN ('Former', 'Evicted'))
													    
	UPDATE #mrv SET FidoYes = 1
		FROM #MyReturnValues #mrv
			INNER JOIN #MyLeasesAndPeeps #mlap ON #mrv.LeaseID = #mlap.LeaseID
			INNER JOIN Pet pt ON #mlap.PersonID = pt.PersonID
		WHERE pt.[Type] = 'Dog'
		
													    
	UPDATE #mrv SET FluffyYes = 1
		FROM #MyReturnValues #mrv
			INNER JOIN #MyLeasesAndPeeps #mlap ON #mrv.LeaseID = #mlap.LeaseID
			INNER JOIN Pet pt ON #mlap.PersonID = pt.PersonID
		WHERE pt.[Type] = 'Cat'		
		
	UPDATE #MyReturnValues SET NumberOfCars = (SELECT COUNT(*)
												   FROM Automobile aut
													   INNER JOIN #MyLeasesAndPeeps #mlap ON aut.PersonID = #mlap.PersonID
													   INNER JOIN #MyReturnValues #mrv ON #mlap.LeaseID = #mrv.LeaseID
												   WHERE #mrv.LeaseID = #MyReturnValues.LeaseID
												   GROUP BY #mlap.LeaseID)

	INSERT #MyCars	
		SELECT LeaseID, null, null
			FROM #MyLeases
															   
	UPDATE #MyCars SET Auto1ID = (SELECT TOP 1 car.AutomobileID
									  FROM Automobile car
										  INNER JOIN PersonLease pl ON car.PersonID = pl.PersonID
										  INNER JOIN #MyLeasesAndPeeps #mlap ON pl.LeaseID = #mlap.LeaseID
									  WHERE #mlap.LeaseID = #MyCars.LeaseID)
									  
	UPDATE #MyCars SET Auto2ID = (SELECT TOP 1 car.AutomobileID
									  FROM Automobile car
										  INNER JOIN PersonLease pl ON car.PersonID = pl.PersonID
										  INNER JOIN #MyLeasesAndPeeps #mlap ON pl.LeaseID = #mlap.LeaseID
									  WHERE #mlap.LeaseID = #MyCars.LeaseID
									    AND car.AutomobileID <> #MyCars.Auto1ID)
									    
	UPDATE #mrv SET CarMake1 = autoCars.Make, CarModel1 = autoCars.MOdel, CarMake2 = autoCars2.Make, CarModel2 = autoCars2.Model
		FROM #MyReturnValues #mrv 
			INNER JOIN #MyCars cars ON #mrv.LeaseID = cars.LeaseID
			INNER JOIN Automobile autoCars ON cars.Auto1ID = autoCars.AutomobileID 
			LEFT JOIN Automobile autoCars2 ON cars.Auto2ID = autoCars2.AutomobileID
												   
	INSERT #HowOldIs2Old4APonyTail
		SELECT LeaseID, null, null, null, null
			FROM #MyLeases 
			
	UPDATE #HowOldIs2Old4APonyTail SET OldPersonID = (SELECT TOP 1 per.PersonID
														  FROM #MyLeasesAndPeeps #mlap
															  INNER JOIN Person per ON #mlap.PersonID = per.PersonID
														  WHERE #mlap.LeaseID = #HowOldIs2Old4APonyTail.LeaseID
														  ORDER BY per.Birthdate)
														  
	UPDATE #HowOldIs2Old4APonyTail SET OldPersonBirthday = (SELECT Birthdate
																FROM Person
																WHERE PersonID = #HowOldIs2Old4APonyTail.OldPersonID)
																
	UPDATE #HowOldIs2Old4APonyTail SET OldPerson2ID = (SELECT TOP 1 per.PersonID
														  FROM #MyLeasesAndPeeps #mlap
															  INNER JOIN Person per ON #mlap.PersonID = per.PersonID
														  WHERE #mlap.LeaseID = #HowOldIs2Old4APonyTail.LeaseID
														    AND per.PersonID <> #HowOldIs2Old4APonyTail.OldPersonID
														  ORDER BY per.Birthdate)	
														  
	UPDATE #HowOldIs2Old4APonyTail SET OldPerson2Birthday = (SELECT Birthdate
																FROM Person
																WHERE PersonID = #HowOldIs2Old4APonyTail.OldPerson2ID)														  															
												   
	UPDATE #mrv SET AgeOfOldOccupant = DATEDIFF(year, #hoi2o4apt.OldPersonBirthday, getdate()), AgeOfOtherOccupant = DATEDIFF(year, #hoi2o4apt.OldPerson2Birthday, getdate())	
		FROM #MyReturnValues #mrv 
			INNER JOIN #HowOldIs2Old4APonyTail #hoi2o4apt ON #mrv.LeaseID = #hoi2o4apt.LeaseID	
			
	UPDATE #MyReturnValues SET ReasonMoved = (SELECT TOP 1 pli.Name
												  FROM #MyLeasesAndPeeps #mlap
													  INNER JOIN Prospect pros ON #mlap.PersonID = pros.PersonID
													  INNER JOIN PickListItem pli ON pros.ReasonForMovingPickListItemID = pli.PickListItemID
												  WHERE #mlap.LeaseID = #MyReturnValues.LeaseID)
												  
	UPDATE #MyReturnValues SET LeasingAgent = (SELECT TOP 1 Rper.PreferredName + '' + Rper.LastName
												   FROM #MyLeasesAndPeeps #mlap
													   INNER JOIN Prospect pros ON #mlap.PersonID = pros.PersonID
													   INNER JOIN PersonTypeProperty ptp ON pros.ResponsiblePersonTypePropertyID = ptp.PersonTypePropertyID
													   INNER JOIN PersonType pt ON ptp.PersonTypeID = pt.PersonTypeID
													   INNER JOIN Person Rper ON pt.PersonID = Rper.PersonID
													WHERE #mlap.LeaseID = #MyReturnValues.LeaseID
													  AND #MyReturnValues.LeasingAgent IS NULL)		
													  
	UPDATE #mrv SET UnitShown = 1
		FROM #MyReturnValues #mrv
			INNER JOIN #MyLeasesAndPeeps #mlap ON #mrv.LeaseID = #mlap.LeaseID
			INNER JOIN PersonNote pn ON #mlap.PersonID = pn.PersonID AND pn.InteractionType = 'Unit Shown'
			
	UPDATE #MyReturnValues SET UnitShownDate = (SELECT TOP 1 pn.[Date]
													FROM PersonNote pn 
														INNER JOIN #MyLeasesAndPeeps #mlap ON pn.PersonID = #mlap.PersonID AND pn.InteractionType = 'Unit Shown'
													WHERE #mlap.LeaseID = #MyReturnValues.LeaseID	
													ORDER BY [Date], DateCreated)		
													
	UPDATE #MyReturnValues SET ProspectUnitTypeDesired = (SELECT TOP 1 ut.Name
															  FROM #MyLeasesAndPeeps #mlap
																  INNER JOIN Prospect pros ON #mlap.PersonID = pros.PersonID
																  INNER JOIN ProspectUnitType prosUT ON pros.ProspectID = prosUT.ProspectID
																  INNER JOIN UnitType ut ON prosUT.UnitTypeID = ut.UnitTypeID
															  WHERE #mlap.LeaseID = #MyReturnValues.LeaseID)   
															  
	UPDATE #mrv SET MarketingSource = ps.Name
		FROM #MyReturnValues #mrv
			INNER JOIN #MyLeasesAndPeeps #mlap ON #mrv.LeaseID = #mlap.LeaseID
			INNER JOIN Prospect pros ON #mlap.PersonID = pros.PersonID
			INNER JOIN PropertyProspectSource pps ON pros.PropertyProspectSourceID = pps.PropertyProspectSourceID
			INNER JOIN ProspectSource ps ON pps.ProspectSourceID = ps.ProspectSourceID
			
	UPDATE #MyReturnValues SET RentCharges = (SELECT ISNULL(SUM(lli.Amount), 0)
												  FROM LeaseLedgerItem lli 
												  WHERE lli.LeaseID = #MyReturnValues.LeaseID
												    AND lli.StartDate <= #MyReturnValues.StartDate
												    AND lli.EndDate >= #MyReturnValues.EndDate)
												    
	UPDATE #MyReturnValues SET NumberOfRenewals = (SELECT COUNT(l.LeaseID)
													   FROM Lease l
														   INNER JOIN #MyLeases #myL ON l.UnitLeaseGroupID = #myL.UnitLeaseGroupID
													   WHERE #myL.LeaseID = #MyReturnValues.LeaseID
													     AND l.LeaseStatus IN ('Renewed'))
													     
	UPDATE #MyReturnValues SET LeaseRenewal = 1
		WHERE NumberOfRenewals > 0
		
	UPDATE #MyReturnValues SET MonthsLateRent = (SELECT COUNT(ulgapInfo.Late)
													FROM ULGAPInformation ulgapInfo
														INNER JOIN #MyLeases #myL ON ulgapInfo.ULGAPInformationID = #myL.UnitLeaseGroupID
													WHERE #myL.LeaseID = #MyReturnValues.LeaseID)
													
	UPDATE #mrv SET PreviousUnitNumber = u.Number, PreviousFloor = u.[Floor], PreviousFloorPlan = ut.Name
		FROM #MyReturnValues #mrv
			INNER JOIN #MyLeases #myL ON #mrv.LeaseID = #myL.LeaseID
			INNER JOIN UnitLeaseGroup prevULG ON #myL.PreviousULG = prevULG.UnitLeaseGroupID
			INNER JOIN Unit u ON prevULG.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
		

	SELECT * 
		FROM #MyReturnValues
		ORDER BY UnitNumber
	
	
END
GO
