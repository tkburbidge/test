SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Rick Bertelsen
-- Create date: June 20, 2016
-- Description:	Computes the Gross and Adjusted Incomes for HUD housing
-- =============================================
CREATE PROCEDURE [dbo].[CalculateHUDIncomeLevels] 
	-- Add the parameters for the stored procedure here
	@certificationIDs GuidCollection READONLY, 
	@effectiveDate date = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #TempHUDWorksheetData (
		CertificationID uniqueidentifier null,
		EffectiveDate date null,
		LeaseID uniqueidentifier null,
		GrossRent money null,												-- Rent Charges
		TotalFamilyIncome money null,
		TotalFamilyIncomeLessStudent money null,							-- The TotalFamilyIncome figuring a max of $480 annual income for each Student
		TotalCashValueAssets money null,
		TotalAnnualInterest money null,
		NumberDependents int null,
		DependentHUDDeduction money default 480.00,							-- Magic number, change as HUD regulations change.
		FamilyGetsElderlyDeduction int default 0,
		ElderlyDisabledHUDDeduction money default 400.00,					-- Magic number, change as HUD regulations change.
		DisabilityPersonsCount int default 0,
		DisabilityDeduction money null,
		MedicalDeduction money null,
		MedicalDisabilityExclusionFactor money default 0.03,				-- Magic number, change as HUD regulations change.
		ChildCareDeduction money null,
		PassbookSavingsRate money default 0.06,								-- Magic number, change as HUD regulations change.
		AssetImputationLimit money default 5000.00,							-- Magic number, change as HUD regulations change.
		AdjustedIncome money null,
		GrossIncome money null,
		Calc30PercentAdjustedIncome money null default 0.30,				-- Magic number, but HUD should never change this 30% of AdjustedIncome
		Calc10PercentGrossIncome money null default 0.10,					-- Magic number, but HUD should never change this 10% of GrossIncome
		Calc30PercentGrossRent money null default 0.30,						-- Magic number, but HUD should never change this 30% of Gross Rent
		SubsidyType nvarchar(50) null,
		UtilityAllowance int null)

	CREATE TABLE #FamilyIncome (
		LeaseID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		HouseholdStatus nvarchar(50) null,
		AnnualIncome money null,
		AssetAnnualIncome money null,
		HUDAnnualIncome money null,
		HUDAssetAnnualIncome money null,
		CurrentValue money null,
		IsStudent bit null,
		IsHUD bit null)

	CREATE TABLE #CertificationIDs (
		CertificationID uniqueidentifier not null)

	INSERT #CertificationIDs
		SELECT Value 
			FROM @certificationIDs

	INSERT #TempHUDWorksheetData
		SELECT	#certIDs.CertificationID,
				certif.EffectiveDate,
				LeaseID,
				null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null,		-- 22 nulls total.
				UtilityAllowance
			FROM Certification certif
				INNER JOIN #CertificationIDs #certIDs ON certif.CertificationID = #certIDs.CertificationID

	INSERT #FamilyIncome
		SELECT	#data.LeaseID,
				pl.PersonID,
				pl.HouseholdStatus,
				[EmploymentIncome].Amount,
				[AssetIncome].AssetAmount,
				[EmploymentIncome].HUDAmount,
				[AssetIncome].HUDAssetAmount,
				[AssetCashValue].CurrentValue,
				affPer.FullTimeStudent,
				ap.IsHUD
			FROM #TempHUDWorksheetData #data
				INNER JOIN Certification c ON #data.CertificationID = c.CertificationID
				INNER JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
				INNER JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
				INNER JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
				INNER JOIN PersonLease pl ON #data.LeaseID = pl.LeaseID
								AND pl.HouseholdStatus IN ('Head of Household', 'Co-Head', 'Family Member - Adult', 'Spouse', 'Other')
				LEFT JOIN
						(SELECT emp.PersonID, ISNULL(SUM(dbo.CalculateAnnual(sal.Amount, sal.SalaryPeriod)), 0) AS 'Amount',
							ISNULL(SUM(dbo.CalculateAnnual(CASE WHEN sal.HUDAmount IS NULL THEN sal.Amount ELSE sal.HUDAmount END, sal.SalaryPeriod)), 0) AS 'HUDAmount'
							FROM Employment emp
								INNER JOIN Salary sal ON emp.EmploymentID = sal.EmploymentID
							WHERE emp.StartDate <= @effectiveDate
							  AND ((emp.EndDate >= @effectiveDate) OR (emp.EndDate IS NULL))
							GROUP BY emp.PersonID) [EmploymentIncome] ON pl.PersonID = [EmploymentIncome].PersonID
				LEFT JOIN
						(SELECT ass.PersonID, ISNULL(SUM(assV.AnnualIncome), 0) AS 'AssetAmount', 
							ISNULL(SUM(CASE WHEN assV.HUDAnnualIncome IS NULL THEN assV.AnnualIncome ELSE assV.HUDAnnualIncome END), 0) AS 'HUDAssetAmount'
							FROM Asset ass
								INNER JOIN AssetValue assV ON ass.AssetID = assV.AssetID
							WHERE assV.[Date] <= @effectiveDate
							  AND ((ass.DateDivested IS NULL) OR (ass.DateDivested <= @effectiveDate))
							GROUP BY ass.PersonID) [AssetIncome] ON pl.PersonID = [AssetIncome].PersonID
				LEFT JOIN
						(SELECT ass.PersonID, ISNULL(SUM(assV.CurrentValue), 0) AS 'CurrentValue'
							FROM Asset ass
								INNER JOIN AssetValue assV ON ass.AssetID = assV.AssetID
							WHERE assV.[Date] <= @effectiveDate
							  AND ((ass.DateDivested IS NULL) OR (ass.DateDivested <= @effectiveDate))
							GROUP BY ass.PersonID) [AssetCashValue] ON pl.PersonID = [AssetCashValue].PersonID
				LEFT JOIN AffordablePerson affPer ON pl.PersonID = affPer.PersonID
				WHERE C.DateCompleted = 0

				
	INSERT #FamilyIncome
		SELECT	#data.LeaseID,
				pl.PersonID,
				pl.HouseholdStatus,
				[EmploymentIncome].Amount,
				[AssetIncome].AssetAmount,
				[EmploymentIncome].HUDAmount,
				[AssetIncome].HUDAssetAmount,
				[AssetCashValue].CurrentValue,
				affPer.FullTimeStudent,
				ap.IsHUD
			FROM #TempHUDWorksheetData #data
				INNER JOIN Certification c ON #data.CertificationID = c.CertificationID
				INNER JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
				INNER JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
				INNER JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
				INNER JOIN PersonLease pl ON #data.LeaseID = pl.LeaseID
								AND pl.HouseholdStatus IN ('Head of Household', 'Co-Head', 'Family Member - Adult', 'Spouse', 'Other')
				LEFT JOIN
						(SELECT sal.PersonID, sal.CertificationID, ISNULL(SUM(dbo.CalculateAnnual(sal.SalaryAmount, sal.Period)), 0) AS 'Amount', 
							ISNULL(SUM(dbo.CalculateAnnual(CASE WHEN sal.HUDSalaryAmount IS NULL THEN sal.SalaryAmount ELSE sal.HUDSalaryAmount END, sal.Period)), 0) AS 'HUDAmount'
							FROM CertificationSalary sal 
							GROUP BY sal.PersonID, sal.CertificationID) [EmploymentIncome] ON pl.PersonID = [EmploymentIncome].PersonID AND c.CertificationID = [EmploymentIncome].CertificationID
				LEFT JOIN
						(SELECT ass.PersonID, ass.CertificationID, ISNULL(SUM(ass.AnnualIncome), 0) AS 'AssetAmount', 
						ISNULL(SUM(CASE WHEN ass.HUDAnnualIncome IS NULL THEN ass.AnnualIncome ELSE ass.HUDAnnualIncome END), 0) AS 'HUDAssetAmount'
							FROM CertificationAsset ass
							GROUP BY ass.PersonID, ass.CertificationID) [AssetIncome] ON pl.PersonID = [AssetIncome].PersonID AND c.CertificationID = [AssetIncome].CertificationID
				LEFT JOIN
						(SELECT ass.PersonID, ass.CertificationID, ISNULL(SUM(ass.CurrentValue), 0) AS 'CurrentValue'
							FROM CertificationAsset ass
							GROUP BY ass.PersonID, ass.CertificationID) [AssetCashValue] ON pl.PersonID = [AssetCashValue].PersonID AND c.CertificationID = [AssetCashValue].CertificationID
				LEFT JOIN AffordablePerson affPer ON pl.PersonID = affPer.PersonID
				WHERE C.DateCompleted = 1


	UPDATE #FamilyIncome SET AnnualIncome = HUDAnnualIncome, AssetAnnualIncome = HUDAssetAnnualIncome WHERE IsHUD = 1

	UPDATE #TempHUDWorksheetData SET SubsidyType = (SELECT TOP 1 apa.SubsidyType
														FROM AffordableProgramAllocation apa
															INNER JOIN CertificationAffordableProgramAllocation capa ON apa.AffordableProgramAllocationID = capa.AffordableProgramAllocationID
																									AND capa.CertificationID = #TempHUDWorksheetData.CertificationID)

	UPDATE #TempHUDWorksheetData SET TotalCashValueAssets = ISNULL((SELECT SUM(CurrentValue)
																		FROM #FamilyIncome
																		WHERE LeaseID = #TempHUDWorksheetData.LeaseID), 0)

	UPDATE #TempHUDWorksheetData SET TotalAnnualInterest = ISNULL((SELECT SUM(AssetAnnualIncome)
																		FROM #FamilyIncome
																		WHERE LeaseID = #TempHUDWorksheetData.LeaseID), 0)

	-- If the total cash value of the family's assets is greater than $5000 (for now at least), take the greater value of their claimed annual income
	-- or passbook savings rate unless they are in the BMIR program.
	UPDATE #TempHUDWorksheetData SET TotalAnnualInterest = ISNULL(TotalCashValueAssets, 0) * PassbookSavingsRate
		WHERE TotalCashValueAssets > AssetImputationLimit
		  AND (ISNULL(TotalCashValueAssets, 0) * PassbookSavingsRate) > AssetImputationLimit
		  AND SubsidyType NOT IN ('BMIR')

	UPDATE #TempHUDWorksheetData SET GrossRent = (SELECT SUM(lli.Amount)
													  FROM LeaseLedgerItem lli
														  INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
														  INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID AND lit.IsRent = 1
													  WHERE lli.StartDate <= @effectiveDate 
													    AND lli.EndDate >= @effectiveDate)

	UPDATE #TempHUDWorksheetData SET TotalFamilyIncomeLessStudent = (SELECT ISNULL(SUM(CASE WHEN ((IsStudent = 1) AND (AnnualIncome > 480.00))
																							  THEN 480.00
																							ELSE AnnualIncome END), 0)
																		 FROM #FamilyIncome
																		 WHERE LeaseID = #TempHUDWorksheetData.LeaseID)

	UPDATE #TempHUDWorksheetData SET TotalFamilyIncome = (SELECT ISNULL(SUM(AnnualIncome), 0)
															  FROM #FamilyIncome
															  WHERE LeaseID = #FamilyIncome.LeaseID)

	UPDATE #TempHUDWorksheetData SET TotalFamilyIncome = ISNULL(CASE WHEN (TotalFamilyIncomeLessStudent < TotalFamilyIncome)
																		THEN TotalFamilyIncomeLessStudent
																	  ELSE TotalFamilyIncome END, 0)
															+ (SELECT ISNULL(SUM(AssetAnnualIncome), 0)
																   FROM #FamilyIncome
																   WHERE LeaseID = #TempHUDWorksheetData.LeaseID)

	UPDATE #TempHUDWorksheetData SET NumberDependents = (SELECT COUNT(DISTINCT pl.PersonLeaseID)
															FROM PersonLease pl
															WHERE pl.HouseholdStatus IN ('Dependent', 'Dependent (50%)', 'Family Member - Minor')
															  AND pl.LeaseID = #TempHUDWorksheetData.LeaseID)

	UPDATE #TempHUDWorksheetData SET FamilyGetsElderlyDeduction = (SELECT SUM(CASE WHEN (affPer.AffordablePersonID IS NULL)
																					   THEN 1
																				   ELSE 0 END)
																	   FROM PersonLease pl
																		   LEFT JOIN AffordablePerson affPer ON pl.PersonID = affPer.PersonID 
																								AND (affPer.Elderly = 1 OR affPer.DisabledHearing = 1 
																										OR affPer.DisabledMobility = 1 OR affPer.DisabledVisual = 1 OR affPer.DisabledMental = 1)
																		WHERE pl.LeaseID = #TempHUDWorksheetData.LeaseID)

	UPDATE #TempHUDWorksheetData SET DisabilityPersonsCount = (SELECT SUM(CASE WHEN (affPer.AffordablePersonID IS NULL)
																					   THEN 1
																				   ELSE 0 END)
																	   FROM PersonLease pl
																		   LEFT JOIN AffordablePerson affPer ON pl.PersonID = affPer.PersonID 
																					AND (affPer.DisabledHearing = 1 OR affPer.DisabledMobility = 1 OR affPer.DisabledVisual = 1 OR affPer.DisabledMental = 1)
																		WHERE pl.LeaseID = #TempHUDWorksheetData.LeaseID)

	UPDATE #TempHUDWorksheetData SET ChildCareDeduction = (SELECT ISNULL(SUM(dbo.CalculateAnnual(affExpAmt.Amount, affExpAmt.Period)), 0)
															   FROM AffordableExpense affExp
																   INNER JOIN AffordableExpenseAmount affExpAmt ON affExp.AffordableExpenseID = affExpAmt.AffordableExpenseID
																   INNER JOIN PersonLease pl ON affExp.PersonID = pl.PersonID
															   WHERE pl.LeaseID = #TempHUDWorksheetData.LeaseID
															     AND affExpAmt.DateVerified <= @effectiveDate
															     AND affExp.[Type] IN ('CCareS', 'CCareW'))

	-- Only give the ChildCareDeduction if all adults in the household work, or are students
	UPDATE #TempHUD SET ChildCareDeduction = 0.00
		FROM #TempHUDWorksheetData #TempHUD
			LEFT JOIN #FamilyIncome #fa ON #TempHUD.LeaseID = #fa.LeaseID AND #fa.IsStudent = 0 AND (#fa.AnnualIncome <= 0.00 OR #fa.AnnualIncome IS NULL)
							AND #fa.HouseholdStatus IN ('Head of Household', 'Co-Head', 'Family Member - Adult', 'Spouse')
		WHERE #fa.PersonID IS NOT NULL

	-- Check that the ChildCareDeduction is not greater than the second largest income in the household unless that person is a student
	-- If it is greater than what they made, set it equal to what they make.
	UPDATE #TempHUD SET ChildCareDeduction = #fa.AnnualIncome
		FROM #TempHUDWorksheetData #TempHUD
			INNER JOIN #FamilyIncome #fa ON #TempHUD.LeaseID = #fa.LeaseID AND #fa.PersonID = (SELECT TOP 1 PersonID
																								  FROM 
																										(SELECT TOP 2 PersonID, AnnualIncome
																											FROM #TempHUDWorksheetData 
																											WHERE LeaseID = #TempHUD.LeaseID
																											ORDER BY AnnualIncome DESC) [Top2Salaries]
																								  ORDER BY [Top2Salaries].AnnualIncome)
		WHERE #fa.IsStudent = 0
		  AND ChildCareDeduction > #fa.AnnualIncome

	UPDATE #TempHUDWorksheetData SET DisabilityDeduction = (SELECT ISNULL(SUM(dbo.CalculateAnnual(affExpAmt.Amount, affExpAmt.Period)), 0)
															   FROM AffordableExpense affExp
																   INNER JOIN AffordableExpenseAmount affExpAmt ON affExp.AffordableExpenseID = affExpAmt.AffordableExpenseID
																   INNER JOIN PersonLease pl ON affExp.PersonID = pl.PersonID
															   WHERE pl.LeaseID = #TempHUDWorksheetData.LeaseID
															     AND affExpAmt.DateVerified <= @effectiveDate
															     AND affExp.[Type] IN ('Dis'))

	UPDATE #TempHUDWorksheetData SET MedicalDeduction = (SELECT ISNULL(SUM(dbo.CalculateAnnual(affExpAmt.Amount, affExpAmt.Period)), 0)
															FROM AffordableExpense affExp
																INNER JOIN AffordableExpenseAmount affExpAmt ON affExp.AffordableExpenseID = affExpAmt.AffordableExpenseID
																INNER JOIN PersonLease pl ON affExp.PersonID = pl.PersonID
															WHERE pl.LeaseID = #TempHUDWorksheetData.LeaseID
															    AND affExpAmt.DateVerified <= @effectiveDate
															    AND affExp.[Type] IN ('Med'))

	UPDATE #TempHUDWorksheetData SET MedicalDisabilityExclusionFactor = MedicalDisabilityExclusionFactor * TotalFamilyIncome

	UPDATE #TempHUDWorksheetData SET MedicalDeduction = ISNULL(MedicalDeduction, 0) - ISNULL(MedicalDisabilityExclusionFactor, 0)
		WHERE MedicalDeduction > 0.00

	UPDATE #TempHUDWorksheetData SET DisabilityDeduction = ISNULL(DisabilityDeduction, 0) - ISNULL(MedicalDisabilityExclusionFactor, 0)
		WHERE DisabilityDeduction > 0.00
		  AND DisabilityPersonsCount > 0

	-- A person is a dependent if they are any of the following:
	-- 1- Under the age of 18.
	-- 2- Disabled.
	-- 3- A full time student of any age.
	UPDATE #TempHUDWorksheetData SET DependentHUDDeduction = DependentHUDDeduction * (ISNULL(NumberDependents, 0) + ISNULL(DisabilityPersonsCount, 0)
																						+ ISNULL((SELECT COUNT(*)
																									FROM #FamilyIncome
																									WHERE LeaseID = #TempHUDWorksheetData.LeaseID
																									  AND IsStudent = 1
																									  AND HouseholdStatus NOT IN ('Dependent')), 0))

	UPDATE #TempHUDWorksheetData SET ElderlyDisabledHUDDeduction = 0.00
		WHERE FamilyGetsElderlyDeduction = 0

	UPDATE #TempHUDWorksheetData SET AdjustedIncome = TotalFamilyIncome - ISNULL(DependentHUDDeduction, 0) - ISNULL(DisabilityDeduction, 0) - ISNULL(ChildCareDeduction, 0)

	-- As per section 5.9 B, Note 2 - Only a family in which the Head, Spouse, Co-Head is elderly or disabled, can the family claim the following family deductions.
	UPDATE #TempHUD SET AdjustedIncome = AdjustedIncome - ISNULL(ElderlyDisabledHUDDeduction, 0) - ISNULL(MedicalDeduction, 0)
		FROM #TempHUDWorksheetData #TempHUD
			INNER JOIN #FamilyIncome #fa ON #TempHUD.LeaseID = #fa.LeaseID 
			INNER JOIN AffordablePerson affPer ON #fa.PersonID = affPer.PersonID 
							AND (affPer.Elderly = 1 OR affPer.DisabledHearing = 0 OR affPer.DisabledMobility = 0 OR affPer.DisabledVisual = 0 OR affPer.DisabledMental = 0)
		WHERE #fa.HouseholdStatus IN ('Head of Household', 'Co-Head', 'Spouse')

	UPDATE #TempHUDWorksheetData
		SET Calc30PercentAdjustedIncome = Calc30PercentAdjustedIncome * CASE WHEN (AdjustedIncome < 0) THEN 0 ELSE AdjustedIncome END,
			Calc10PercentGrossIncome = Calc10PercentGrossIncome * GrossIncome,
			Calc30PercentGrossRent = Calc30PercentGrossRent * GrossRent
		
	-- Return our data.  Subsidy types are as follows:
	-- IN ('Section 8', 'Section 236', 'Section 202 PRAC', 'Rent Supplement', 'RAP', 'Section 811 PRAC', 'Section 202/162 PAC', 'BMIR'))
	SELECT	CertificationID AS 'CertificationID', LeaseID AS 'LeaseID', SubsidyType AS 'SubsidyType', ISNULL(AdjustedIncome, 0) AS 'AdjustedIncome',
											ISNULL(GrossIncome, 0) AS 'GrossIncome', ISNULL(UtilityAllowance, 0) AS 'UtilityAllowance', EffectiveDate,
			ISNULL(CASE WHEN (SubsidyType IN ('Section 8'))
							THEN CASE WHEN (Calc30PercentAdjustedIncome >= Calc10PercentGrossIncome AND Calc30PercentAdjustedIncome > 25.00)
										 THEN Calc30PercentAdjustedIncome
									  WHEN (Calc10PercentGrossIncome > Calc30PercentAdjustedIncome AND Calc10PercentGrossIncome > 25.00)
										 THEN Calc10PercentGrossIncome
									  ELSE 25.00
									  END
						 WHEN (SubsidyType IN ('Section 202 PRAC', 'RAP', 'Section 811 PRAC', 'Section 202/162 PAC'))
							THEN CASE WHEN (Calc30PercentAdjustedIncome >= Calc10PercentGrossIncome)
										 THEN Calc30PercentAdjustedIncome
									  WHEN (Calc10PercentGrossIncome > Calc30PercentAdjustedIncome)
										 THEN Calc10PercentGrossIncome
									  END 
						 WHEN (SubsidyType IN ('Rent Supplement'))
							THEN CASE WHEN (Calc30PercentAdjustedIncome >= Calc30PercentGrossRent)
										 THEN Calc30PercentAdjustedIncome
									  ELSE Calc30PercentGrossRent 
									  END
						 END, 0) AS 'TotalTenantPayment'
		FROM #TempHUDWorksheetData
END







GO
