SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[RPT_AFF_CertificationInformation]
	-- Add the parameters for the stored procedure here
	@accountID bigint,
	@propertyIDs GuidCollection READONLY, 
	@effectiveDate date = null,
	@passbookRate DECIMAL,
	@assetImputationLimit INT
AS

DECLARE @accountingPeriodID uniqueidentifier = null
DECLARE @certificationIDs GuidCollection

BEGIN
	CREATE TABLE #LeasesAndUnits (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(50) null,
		OccupiedUnitLeaseGroupID uniqueidentifier null,
		OccupiedLastLeaseID uniqueidentifier null,
		OccupiedMoveInDate date null,
		OccupiedNTVDate date null,
		OccupiedMoveOutDate date null,
		OccupiedIsMovedOut bit null,
		PendingUnitLeaseGroupID uniqueidentifier null,
		PendingLeaseID uniqueidentifier null,
		PendingApplicationDate date null,
		PendingMoveInDate date null)

	CREATE TABLE #UnitInfo (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		UnitID uniqueidentifier null,
		Number nvarchar(50) null,
		PaddedNumber nvarchar(50) null,
		LeaseID uniqueidentifier null,
		SquareFeet int null,
		UnitType nvarchar(50) null,
		UtilityAllowance int null,
		ContractRent int null,
		MarketRent money null,
		MoveInDate date null,
		MoveOutDate date null, 
		Bedrooms int null,
		IsHudEnabled bit not null
		)

	CREATE TABLE #TICInfo (
		PropertyID uniqueidentifier not null,
		LeaseID uniqueidentifier null,
		UnitID uniqueidentifier null,
		Number nvarchar(50) null,
		CertificationID uniqueidentifier null,
		CertType nvarchar(50) null,
		ProgSetAside nvarchar(500) null,
		IncomeLimit money null,
		OverIncomeLimit money null,
		TenantRent money null,
		GrossRent money null,
		MaxRent money null,
		RentalAssistance money null,
		IncomeAtMoveIn money null,
		ReCertDate date null)

	CREATE TABLE #50059Info (
		PropertyID uniqueidentifier not null,
		LeaseID uniqueidentifier null,
		UnitID uniqueidentifier not null,
		CertificationID uniqueidentifier null,
		Number nvarchar(50) null,
		CertType nvarchar(50) null,
		Subsidy nvarchar(500) null,
		IncomeCategory nvarchar(500) null,
		AdjustedIncome nvarchar(500) null,
		TenantRent money null,
		TotalTenantPayment money null,
		AssistancePayment money null,
		AnnualRecertDate date null,
		CertificationEffectiveDate date not null)

	CREATE TABLE #Income (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier null,
		Number nvarchar(50) null,
		Name nvarchar(100) null,
		Employer nvarchar(100) null,
		IncomeType nvarchar(100) null,
		AnnualIncome money null,
		Verified bit null)

	CREATE TABLE #Assets (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier null,
		Name nvarchar(100) null,
		AssetStatus nvarchar(100) null,
		[Description] nvarchar(100) null,
		[Type] nvarchar(50) null,
		Interest money null,
		CurrentValue money null,
		Income money null,
		Verified bit null)

	CREATE TABLE #Expenses (
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier null,
		Name nvarchar(100) null,
		[Description] nvarchar(500) null,
		[Type] nvarchar(100) null,
		Amount money null,
		Verified bit null)

	CREATE TABLE #TenantRentInfo (
		CertificationID uniqueidentifier not null,
		LeaseID uniqueidentifier null,
		SubsidyType nvarchar(50) null,
		AdjustedIncome money null,
		GrossIncome money null,
		UtilityAllowance int null,
		EffectiveDate date null,
		TotalTenantPayment money null)				-- TotalTenantPayment is as defined by the government, TTP!  TenantRent is TTP-UtilityAllowance

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @effectiveDate, @accountingPeriodID, @propertyIDs	
	
	INSERT #UnitInfo
		SELECT	#lau.PropertyID,
				p.Name AS 'PropertyName',
				#lau.UnitID,
				u.Number,
				u.PaddedNumber,
				(ISNULL(#lau.OccupiedLastLeaseID, #lau.PendingLeaseID)) AS 'LeaseID',
				COALESCE(u.SquareFootage, ut.SquareFootage) as 'SquareFeet',
				ut.Name as 'UnitType',
				null, null,
				[MarketRent].Amount as 'MarketRent',
				OccupiedMoveInDate as 'MoveInDate',
				OccupiedMoveOutDate as 'MoveOutDate',
				ut.Bedrooms,
				p.EnableHUDFeatures
			FROM #LeasesAndUnits #lau
				INNER JOIN Unit u ON #lau.UnitID = u.UnitID
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				INNER JOIN Property p ON ut.PropertyID = p.PropertyID
				CROSS APPLY GetMarketRentByDate(#lau.UnitID, @effectiveDate, 0) AS [MarketRent]
	UPDATE #ui SET UtilityAllowance = ua.Amount
		FROM #UnitInfo #ui
			INNER JOIN UtilityAllowance ua ON #ui.UnitID = ua.ObjectID AND ua.ObjectType = 'Unit'
		WHERE ua.UtilityAllowanceID = (SELECT TOP 1 UtilityAllowanceID
										   FROM UtilityAllowance 
										   WHERE ObjectID = #ui.UnitID
										     AND DateChanged <= @effectiveDate
										   ORDER BY DateChanged DESC)

	UPDATE #ui SET UtilityAllowance = ua.Amount
		FROM #UnitInfo #ui
			INNER JOIN Unit u ON #ui.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN UtilityAllowance ua ON ut.UnitTypeID = ua.ObjectID AND ua.ObjectType = 'UnitType'
		WHERE #ui.UtilityAllowance IS NULL
		  AND ua.UtilityAllowanceID = (SELECT TOP 1 UtilityAllowanceID 
										   FROM UtilityAllowance
										   WHERE ObjectID = ut.UnitTypeID
										     AND DateChanged <= @effectiveDate
										   ORDER BY DateChanged DESC)

	UPDATE #ui SET ContractRent = cr.Amount
		FROM #UnitInfo #ui
			INNER JOIN ContractRent cr ON #ui.UnitID = cr.ObjectID AND cr.ObjectType = 'Unit'
		WHERE cr.ContractRentID = (SELECT TOP 1 ContractRentID
										   FROM ContractRent 
										   WHERE ObjectID = #ui.UnitID
										     AND DateChanged <= @effectiveDate
										   ORDER BY DateChanged DESC)

	UPDATE #ui SET ContractRent = cr.Amount
		FROM #UnitInfo #ui
			INNER JOIN Unit u ON #ui.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN ContractRent cr ON ut.UnitTypeID = cr.ObjectID AND cr.ObjectType = 'UnitType'
		WHERE #ui.ContractRent IS NULL
		  AND cr.ContractRentID = (SELECT TOP 1 ContractRentID 
										   FROM ContractRent
										   WHERE ObjectID = ut.UnitTypeID
										     AND DateChanged <= @effectiveDate
										   ORDER BY DateChanged DESC)

	INSERT INTO #TICInfo
		SELECT DISTINCT
				#lau.PropertyID,
				#ui.LeaseID,
				#lau.UnitID,
				#lau.UnitNumber,
				certif.CertificationID,
				null, null, null, null, null, null, null, null, null, null				-- 10 nulls here!
			FROM #LeasesAndUnits #lau
				INNER JOIN #UnitInfo #ui ON #lau.UnitID = #ui.UnitID
				INNER JOIN UnitLeaseGroup ulg ON #lau.UnitID = ulg.UnitID
				INNER JOIN Certification certif ON ulg.UnitLeaseGroupID = certif.UnitLeaseGroupID
				INNER JOIN CertificationAffordableProgramAllocation capa ON certif.CertificationID = capa.CertificationID
				INNER JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
				INNER JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
			WHERE certif.EffectiveDate <= @effectiveDate
				AND ap.IsHUD = 0

	UPDATE #TICi
		SET
			CertType = certif.[Type],
			ProgSetAside = [NameMyTail].ProgramName,
			IncomeLimit = certif.TaxCreditIncomeLimit,
			OverIncomeLimit = certif.TaxCreditOverIncomeLimit,
			TenantRent = certif.TaxCreditTenantRent,
			GrossRent =	certif.TaxCreditGrossRent,
			MaxRent = certif.TaxCreditMaxRent,
			RentalAssistance = certif.TaxCreditRentalAssistance,
			IncomeAtMoveIn = cg.InitialIncome,
			ReCertDate = certif.RecertificationDate
		FROM #TICInfo #TICi
			INNER JOIN Certification certif ON #TICi.CertificationID = certif.CertificationID
			INNER JOIN CertificationGroup cg ON certif.CertificationGroupID = cg.CertificationGroupID
			OUTER APPLY GetAffordableProgramName(certif.CertificationID, 1, 1, null, @accountID, @passbookRate, @assetImputationLimit) [NameMyTail]


-- We need to learn more about #50059 crap!!!!, and then throw it in here.
	INSERT #50059Info
		SELECT	DISTINCT
				b.PropertyID, 
				[Certification].LeaseID,
				u.UnitID,
				[Certification].CertificationID,
				u.Number,
				null,								-- CertType
				null,								-- Subsidy
				null,								-- IncomeCategory
				null,								-- AdjustedIncome
				null,								-- TenantRent
				null,								-- TotalTenantPayment
				null,								-- AssistancePayment
				null,								-- AnnualRecertDate
				[Certification].EffectiveDate
			FROM Unit u
				INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
				CROSS APPLY GetCertificationIDByUnitID(u.UnitID, @effectiveDate, 0) [Certification]
				INNER JOIN Certification c ON [Certification].CertificationID = c.CertificationID
				INNER JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
				INNER JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
				INNER JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
			WHERE [Certification].EffectiveDate <= @effectiveDate
				AND ap.IsHUD = 1

	UPDATE #50Sucks
		SET		CertType = certif.[Type],
				Subsidy = [NameMyTail].ProgramName,
				IncomeCategory = CASE WHEN dbo.CalculateSection8AMI(certif.CertificationID, @accountID, @passbookRate, @assetImputationLimit) = 30 THEN 'ELI' 
									  WHEN dbo.CalculateSection8AMI(certif.CertificationID, @accountID, @passbookRate, @assetImputationLimit) = 50 THEN 'VLI' 
									  WHEN dbo.CalculateSection8AMI(certif.CertificationID, @accountID, @passbookRate, @assetImputationLimit) = 80 THEN 'LI' 
									  ELSE '' 
									  END,
				AdjustedIncome = certif.HUDAdjustedIncome,
				TenantRent = certif.HUDTenantRent,
				TotalTenantPayment = certif.HUDTotalTenantPayment,
				AssistancePayment = certif.HUDAssistancePayment,
				AnnualRecertDate = certif.RecertificationDate
		FROM #50059Info #50Sucks
			INNER JOIN Certification certif ON #50Sucks.CertificationID = certif.CertificationID
			OUTER APPLY GetAffordableProgramName(#50Sucks.CertificationID, 0, 1, null, @accountID, @passbookRate, @assetImputationLimit) [NameMyTail]

	INSERT @certificationIDs 
		SELECT DISTINCT CertificationID
			FROM #50059Info

	INSERT #TenantRentInfo
		EXEC CalculateHUDIncomeLevels @certificationIDs, @effectiveDate

	UPDATE #50Sucks
		SET		TotalTenantPayment = #tri.TotalTenantPayment,
				TenantRent = #tri.TotalTenantPayment - ISNULL(#tri.UtilityAllowance, 0)
		FROM #50059Info #50Sucks
			INNER JOIN #TenantRentInfo #tri ON #50Sucks.CertificationID = #tri.CertificationID

	INSERT #Income
		SELECT	#ui.PropertyID,
				#ui.UnitID,
				#ui.Number,
				per.LastName + ', ' + per.PreferredName AS 'Name',
				emp.Employer,
				emp.TaxCreditType,
				dbo.CalculateAnnual(sal.Amount, sal.SalaryPeriod) AS 'Amount',
				CASE WHEN (sal.DateVerified IS NOT NULL) THEN CAST(1 AS bit)
					 ELSE CAST(0 AS bit)
						END AS 'Verified'
			FROM #UnitInfo #ui
				INNER JOIN PersonLease pl ON #ui.LeaseID = pl.LeaseID
				INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
				INNER JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				INNER JOIN Unit u ON ulg.UnitID = u.UnitID
				INNER JOIN Building b ON u.BuildingID = b.BuildingID
				INNER JOIN Person per ON pl.PersonID = per.PersonID
				INNER JOIN Employment emp ON pl.PersonID = emp.PersonID
				INNER JOIN Salary sal ON emp.EmploymentID = sal.EmploymentID
			WHERE (emp.StartDate <= @effectiveDate OR emp.StartDate IS NULL)
			  AND ((emp.EndDate IS NULL) OR (emp.EndDate >= @effectiveDate))
				AND sal.EffectiveDate <= @effectiveDate
				AND (sal.SalaryID = (SELECT TOP 1 SalaryID
										FROM Salary 
										WHERE EmploymentID = emp.EmploymentID
										  AND EffectiveDate <= @effectiveDate
										ORDER BY EffectiveDate DESC))

	INSERT #Assets
		SELECT	#ui.PropertyID,
				#ui.UnitID,
				per.LastName + ', ' + per.PreferredName,
				ass.[Status],
				ass.[Description],
				ass.[Type],
				[AssVal].AnnualInterestRate,
				[AssVal].CurrentValue,
				[AssVal].AnnualIncome,
				CASE WHEN ([AssVal].DateVerified IS NOT NULL) THEN CAST(1 AS Bit)
				     ELSE CAST(0 AS Bit)
					 END
			FROM #UnitInfo #ui
				INNER JOIN PersonLease pl ON #ui.LeaseID = pl.LeaseID
				INNER JOIN Person per ON pl.PersonID = per.PersonID
				INNER JOIN Asset ass ON per.PersonID = ass.PersonID
				INNER JOIN 
						(SELECT *
							FROM 
								(SELECT *, ROW_NUMBER()
									OVER (PARTITION BY AssetID ORDER BY [Date] DESC) AS [LikeDave]
									FROM AssetValue
									WHERE [Date] <= @effectiveDate) AS [BigAss]
							WHERE [LikeDave] = 1) AS [AssVal] ON ass.AssetID = [AssVal].AssetID

	INSERT #Expenses
		SELECT	#ui.PropertyID,
				#ui.UnitID,
				per.LastName + ', ' + per.PreferredName,
				affExp.[Description],
				affExp.[Type],
				affExpAmt.Amount,
				CASE WHEN (affExpAmt.DateVerified IS NOT NULL) THEN CAST(1 AS bit)
					 ELSE CAST(0 AS bit)
					 END
			FROM #UnitInfo #ui
				INNER JOIN PersonLease pl ON #ui.LeaseID = pl.LeaseID
				INNER JOIN Person per ON pl.PersonID = per.PersonID
				INNER JOIN AffordableExpense affExp ON per.PersonID = affExp.PersonID
				INNER JOIN AffordableExpenseAmount affExpAmt ON affExp.AffordableExpenseID = affExpAmt.AffordableExpenseID
			WHERE affExpAmt.EffectiveDate <= @effectiveDate	

	SELECT	#ui.PropertyID,
			#ui.UnitID,
			#ui.Number,
			per.PersonID,
			per.LastName + ', ' + per.PreferredName AS 'Name',
			pl.HouseholdStatus AS 'Status',
			per.Birthdate,
			DATEDIFF(YEAR, per.Birthdate, @effectiveDate) AS 'Age',
			per.SSNDisplay AS 'SSN_AIN',
			affper.Race,
			affper.Ethnicity,
			affper.FullTimeStudent AS 'IsStudent',
			ah.ExpectedAdoptions + ah.ExpectedFosterChildren + ah.UnbornChildren AS 'NumberOfExtraPeople',
			(SELECT COUNT(*)
				FROM PersonLease pl2
				WHERE pl2.LeaseID = #ui.LeaseID
					AND pl2.ResidencyStatus IN ('Pending', 'Approved', 'Current', 'Pending Renewal', 'Pending Transfer', 'Renewed', 'Under Eviction')) AS 'NumberOfPeople'
		FROM #UnitInfo #ui
			INNER JOIN PersonLease pl ON #ui.LeaseID = pl.LeaseID AND pl.ResidencyStatus IN ('Pending', 'Approved', 'Current', 'Pending Renewal', 'Pending Transfer', 'Renewed', 'Under Eviction') AND pl.HouseholdStatus IN ('Head of Household', 'Spouse')
			INNER JOIN Person per ON pl.PersonID = per.PersonID
			INNER JOIN AffordablePerson affper ON per.PersonID = affper.PersonID
			INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
			INNER JOIN AffordableHousehold ah ON l.UnitLeaseGroupID = ah.ObjectID
		ORDER BY #ui.PropertyID, #ui.PaddedNumber

	SELECT	*
		FROM #UnitInfo
		ORDER BY PropertyID, PaddedNumber
	
	SELECT  *
		FROM #TICInfo
		ORDER BY PropertyID

	SELECT	*
		FROM #50059Info
		ORDER BY PropertyID

	SELECT	*
		FROM #Income
		ORDER BY PropertyID

	SELECT	*
		FROM #Assets
		ORDER BY PropertyID

	SELECT	*
		FROM #Expenses
		ORDER BY PropertyID

	SELECT aptr.*
		FROM AffordableProgramTableRow aptr
			INNER JOIN AffordableProgramTable apt ON aptr.AffordableProgramTableID = apt.AffordableProgramTableID
			INNER JOIN AffordableProgramTableGroup aptg ON apt.AffordableProgramTableGroupID = aptg.AffordableProgramTableGroupID
		WHERE aptg.IsHUD = 1

	SELECT apt.*
		FROM AffordableProgramTable apt
			INNER JOIN AffordableProgramTableGroup aptg ON apt.AffordableProgramTableGroupID = aptg.AffordableProgramTableGroupID
		WHERE aptg.IsHUD = 1
END
GO
