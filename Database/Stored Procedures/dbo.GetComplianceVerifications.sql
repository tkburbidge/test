SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Craig Perkins
-- Create date: May 24, 2016
-- Description:	Gets a collection of compliance verification objects
-- =============================================
CREATE PROCEDURE [dbo].[GetComplianceVerifications] 
	-- Add the parameters for the stored procedure here
	@accountID bigint = null,
	@certificationIDs GuidCollection READONLY,
	@passbookRate DECIMAL,
	@assetImputationLimit INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @personIDs GuidCollection

	CREATE TABLE #Certifications 
	(
		CertificationID uniqueidentifier not null,
		CertificationGroupID uniqueidentifier not null,
		ProgramName nvarchar(500) null,
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(250) not null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(20) not null,
		NumberOfBedrooms int not null,
		LeaseID uniqueidentifier null,
		UnitLeaseGroupID uniqueidentifier not null,
		LeaseStartDate date null,
		LeaseEndDate date null,
		LeaseStatus nvarchar(20) null,
		NonOptionalFees money not null,
		CertificationEffectiveDate date not null,
		RecertificationDate date not null,
		CertificationType nvarchar(50) not null,
		TicSignedDate date null,
		HudSignedDate date null,
		OwnerSignedDate date null,
		NoSignatureReason nvarchar(100) null,
		TaxCreditRentalAssistance money null,
		SubsidyLeaseLeaseLedgerItemID uniqueidentifier null,
		UtilityAllowance int null,
		ContractRent int not null,
		HUDTotalTenantPaymentOverride money null,
		Section8LIException nvarchar(25) null,
		TerminationReason nvarchar(50) null,
		CorrectedByCertificationID uniqueidentifier null,
		DateCompleted datetime null,
		InitialIncome money null,
		TaxCreditTenantRent money null,
		HudUtilityReimbursement money null,
		HudGrossRent money null,
		HudAssistancePayment money null,
		TaxCreditMaxRent money null,
		TaxCreditGrossRent money null,
		IncomeLimit money null,
		HudAdjustedIncome money null, 
		HudTotalTenantPayment money null,
		HudTenantRent money null,
		UnbornChildren int not null,
		ExpectedAdoptions int not null,
		ExpectedFosterChildren int not null,
		Concessions money null,
		IsCorrection bit not null,
		BuildingRentUp bit not null,
		RentLeaseLedgerItemID uniqueidentifier null,
		IsBaseline bit not null,
		FlaggedForRepayment bit not null,
		AnticipatedVoucherDate datetime null
	)

	CREATE TABLE #Residents
	(
		CertificationID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		LeaseID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		Name nvarchar(81) not null,
		Relationship nvarchar(35) not null,
		Race int null,
		Ethnicity int null,
		IsDisabled bit not null,
		IsElderly bit not null,
		Birthdate date null,
		IsFullTimeStudent bit not null,
		SSN nvarchar(50) null,
		DateVerified datetime null
	)

	CREATE TABLE #AffordableProgramAllocations
	(
		CertificationID uniqueidentifier not null,
		AffordableProgramID uniqueidentifier not null,
		AffordableProgramAllocationID uniqueidentifier not null,
		IsHUD bit not null,
		ProgramName nvarchar(50) null,
		AllocationName nvarchar(50) null,
		ProgramType nvarchar(20) null,
		SubsidyType nvarchar(20) null,
		ContractNumber nvarchar(20) null,
		UnitAmount int null,
		AmiPercent int null,
		IncomeLimit money null,
		MaxRent money null,
		OverIncomePercent int null,
		RentLimitPercent int null,
		IsHighHome bit null,
		Before1981 bit not null
	)

	CREATE TABLE #CertificationStatuses
	(
		CertificationID uniqueidentifier not null,
		CertificationStatusID uniqueidentifier not null,
		[Status] nvarchar(50) not null,
		Notes nvarchar(1000) null,
		PersonID uniqueidentifier not null,
		PersonName nvarchar(81) not null,
		DateCreated datetime not null
	)

	CREATE TABLE #Employments
	(
		EmploymentID uniqueidentifier not null,
		SalaryID uniqueidentifier not null,
		[Type] nvarchar(10) null,
		TaxCreditType nvarchar(100) null,
		PersonID uniqueidentifier not null,
		Resident nvarchar(81) not null,
		Employer nvarchar(100) null,
		EndDate date null,			
		SalaryAmount money not null,
		HUDSalaryAmount money null,
		SalaryPeriod nvarchar(100) null,
		VerificationSource nvarchar(500) null,
		VerifiedPersonName nvarchar(81) null,
		VerifiedDate date null,
		SalaryEffectiveDate date not null, 
		HasDocument bit not null,
		EmploymentEndDate date null
	)

	CREATE TABLE #Assets
	(
		AssetID uniqueidentifier not null,
		AssetValueID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		[Type] nvarchar(max) null,
		EndDate date null,			
		PersonName nvarchar(81) not null,
		AnnualIncome money not null,
		HUDAnnualIncome money null,
		CurrentValue money not null,
		AnnualInterestRate money not null,
		VerificationSource nvarchar(500) null,
		VerifiedByPersonName nvarchar(81) null,
		DateVerified date null,
		[Description] nvarchar(500) null,
		[Status] nvarchar(25) not null,
		EffectiveDate date not null,
		CashValue money not null, 
		HasDocument bit not null
	)

	CREATE TABLE #Expenses
	(
		AffordableExpenseID uniqueidentifier not null,
		AffordableExpenseAmountID uniqueidentifier not null,
		PersonID uniqueidentifier not null,
		PersonName nvarchar(81) not null,
		[Type] nvarchar(10) not null,
		EndDate date null,			
		Amount money null,
		AmountEffectiveDate date null,
		Period nvarchar(100) not null,
		DateVerified date null,
		VerifiedPersonName nvarchar(81) null, 
		HasDocument bit not null,
		VerificationSources nvarchar(500) null
	)
	
	CREATE TABLE #CertificationCounter
	(
		CertificationID uniqueidentifier not null,
		ResidentCount int not null
	)
	CREATE TABLE #AnticipatedVoucherDates
	(
		CertificationID uniqueidentifier not null,
		AnticipatedVoucherDate datetime null
	)

	INSERT INTO #Certifications
		SELECT	
			c.CertificationID AS 'CertificationID',
			c.CertificationGroupID AS 'CertificationGroupID',
			pn.ProgramName AS 'ProgramName',
			p.PropertyID,
			p.Name AS 'PropertyName',
			u.UnitID AS 'UnitID',
			u.Number AS 'UnitNumber',
			ut.Bedrooms AS 'NumberOfBedrooms',
			c.LeaseID AS 'LeaseID',
			c.UnitLeaseGroupID AS 'UnitLeaseGroupID',
			l.LeaseStartDate AS 'LeaseStartDate',
			l.LeaseEndDate AS 'LeaseEndDate',
			l.LeaseStatus AS 'LeaseStatus',
			ISNULL((SELECT SUM(lli.Amount)
				FROM LeaseLedgerItem lli
					INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
					INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
				WHERE l.LeaseID IS NOT NULL
					AND lli.LeaseID = l.LeaseID
					AND lit.IsCharge = 1
					AND lli.StartDate <= c.EffectiveDate
					AND lli.IsNonOptionalCharge = 1), 0) AS 'NonOptionalFees',
			c.EffectiveDate AS 'CertificationEffectiveDate',
			c.RecertificationDate AS 'RecertificationDate',
			c.[Type] AS 'CertificationType',
			c.SignedTicDate AS 'TicSignedDate',
			c.Signed50059Date AS 'HudSignedDate',
			c.OwnerSigned50059Date AS 'OwnerSignedDate',
			c.NoSignatureReason AS 'NoSignatureReason',
			CASE
				WHEN c.SubsidyLeaseLeaseLedgerItemID IS NULL
				THEN c.TaxCreditRentalAssistance
				ELSE (SELECT Amount
						FROM LeaseLedgerItem
						WHERE LeaseLedgerItem.LeaseLedgerItemID = c.SubsidyLeaseLeaseLedgerItemID)
				END AS 'TaxCreditRentalAssistance',
			c.SubsidyLeaseLeaseLedgerItemID AS 'SubsidyLeaseLeaseLedgerItemID',
			CASE
				WHEN c.DateCompleted IS NULL 
				THEN ISNULL((SELECT TOP(1) ua.Amount
						FROM UtilityAllowance ua
						WHERE (ua.ObjectID = u.UnitID OR ua.ObjectID = ut.UnitTypeID)
							AND ua.DateChanged <= c.EffectiveDate
						ORDER BY ua.DateChanged DESC, ua.DateCreated DESC), 0)
				ELSE
					c.UtilityAllowance
				END AS 'UtilityAllowance',

			ISNULL((SELECT TOP(1) cr.Amount
				FROM ContractRent cr
				WHERE cr.ObjectID = u.UnitTypeID
					AND	cr.DateChanged <= c.EffectiveDate
				ORDER BY cr.DateChanged DESC, cr.DateCreated DESC), 0) AS 'ContractRent',
			c.HUDTotalTenantPaymentOverride AS 'HUDTotalTenantPaymentOverride',
			c.Section8LIException AS 'Section8LIException',
			c.TerminationReason AS 'TerminationReason',
			c.CorrectedByCertificationID AS 'CorrectedByCertificationID',
			c.DateCompleted AS 'DateCompleted',
			cg.InitialIncome AS 'InitialIncome',
			c.TaxCreditTenantRent AS 'TaxCreditTenantRent',
			c.HUDUtilityReimbursement AS 'HudUtilityReimbursement',
			c.HUDGrossRent AS 'HudGrossRent',
			c.HUDAssistancePayment AS 'HudAssistancePayment',
			c.TaxCreditMaxRent AS 'TaxCreditMaxRent',
			c.TaxCreditGrossRent AS 'TaxCreditGrossRent',
			c.TaxCreditIncomeLimit AS 'IncomeLimit',
			c.HUDAdjustedIncome AS 'HudAdjustedIncome', 
			c.HUDTotalTenantPayment AS 'HudTotalTenantPayment',
			c.HUDTenantRent AS 'HudTenantRent',
			ISNULL(ah.UnbornChildren, 0) AS 'UnbornChildren',
			ISNULL(ah.ExpectedAdoptions, 0) AS 'ExpectedAdoption',
			ISNULL(ah.ExpectedFosterChildren, 0) AS 'ExpectedFosterChildren',
			(SELECT SUM(lli.Amount)
				FROM LeaseLedgerItem lli
					INNER JOIN LedgerItem li ON lli.LedgerItemID = li.LedgerItemID
					INNER JOIN LedgerItemType lit ON li.LedgerItemTypeID = lit.LedgerItemTypeID
				WHERE l.LeaseID IS NOT NULL
					AND lli.LeaseID = l.LeaseID
					AND p.TenantRentShouldDeductRentConcessions = 1
					AND lit.IsRecurringMonthlyRentConcession = 1
					AND lli.StartDate <= c.EffectiveDate
					AND lli.EndDate >= c.EffectiveDate) AS 'Concessions',
			c.IsCorrection AS 'IsCorrection',
			b.RentUp AS 'BuildingRentUp',
			c.RentLeaseLedgerItemID AS 'RentLeaseLedgerItemID',
			ISNULL(asi.IsBaseline, 0) AS 'IsBaseline',
			ISNULL(c.FlaggedForRepayment, 0) AS 'FlaggedForRepayment',
			null AS 'AnticipatedVoucherDate'
		FROM Certification c
			LEFT JOIN Lease l ON c.LeaseID = l.LeaseID
			INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			LEFT JOIN AffordableHousehold ah ON c.UnitLeaseGroupID = ah.ObjectID
			LEFT JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
			LEFT JOIN AffordableSubmissionItem asi ON capa.CertificationAffordableProgramAllocationID = asi.ObjectID
			CROSS APPLY dbo.GetAffordableProgramName(c.CertificationID, 1, 1, null, @accountID, @passbookRate, @assetImputationLimit) pn
			INNER JOIN CertificationGroup cg ON c.CertificationGroupID = cg.CertificationGroupID
		WHERE c.AccountID = @accountID
			AND (c.CertificationID IN (SELECT Value FROM @certificationIDs))
	

	INSERT #AnticipatedVoucherDates EXEC GetAnticipatedVoucherDates @accountID, @certificationIDs

	UPDATE #Certifications SET AnticipatedVoucherDate = (SELECT TOP 1 AnticipatedVoucherDate FROM #AnticipatedVoucherDates a WHERE CertificationID = a.CertificationID)

	INSERT #Residents EXEC AFF_GetCertificationResidents @accountID, @certificationIDs

	INSERT @personIDs SELECT PersonID FROM #Residents

	INSERT INTO #CertificationCounter
		SELECT
			r.CertificationID,
			COUNT(DISTINCT r.PersonID) + MAX(ISNULL(ah.UnbornChildren, 0)) + MAX(ISNULL(ah.ExpectedAdoptions,0)) + MAX(ISNULL(ah.ExpectedFosterChildren,0)) AS 'ResidentCount'

		FROM #Residents r
			INNER JOIN Lease l on r.LeaseID = l.LeaseID
			LEFT JOIN AffordableHousehold ah on ah.ObjectID = l.UnitLeaseGroupID
		GROUP BY r.CertificationID, r.LeaseID

	INSERT INTO #AffordableProgramAllocations
		SELECT
			c.CertificationID AS 'CertificationID',
			apa.AffordableProgramID AS 'AffordableProgramID',
			apa.AffordableProgramAllocationID AS 'AffordableProgramAllocationID',
			ap.IsHUD AS 'IsHUD',
			ap.Name AS 'ProgramName',
			apa.Name AS 'AllocationName',
			ap.[Type] AS 'ProgramType',
			apa.SubsidyType AS 'SubsidyType',
			apa.ContractNumber AS 'ContractNumber',
			apa.UnitAmount AS 'UnitAmount',
			apa.AmiPercent AS 'AmiPercent',
			ISNULL((CASE WHEN (cc.ResidentCount = 1) THEN iaptr.Value1
				 WHEN (cc.ResidentCount = 2) THEN iaptr.Value2
				 WHEN (cc.ResidentCount = 3) THEN iaptr.Value3
				 WHEN (cc.ResidentCount = 4) THEN iaptr.Value4
				 WHEN (cc.ResidentCount = 5) THEN iaptr.Value5
				 WHEN (cc.ResidentCount = 6) THEN iaptr.Value6
				 WHEN (cc.ResidentCount = 7) THEN iaptr.Value7
				 ELSE iaptr.Value8
			END), 0) AS 'IncomeLimit',
			ISNULL((CASE WHEN (ct.NumberOfBedrooms = 0) THEN raptr.Value1
				 WHEN (ct.NumberOfBedrooms = 1) THEN raptr.Value2
				 WHEN (ct.NumberOfBedrooms = 2) THEN raptr.Value3
				 WHEN (ct.NumberOfBedrooms = 3) THEN raptr.Value4
				 WHEN (ct.NumberOfBedrooms = 4) THEN raptr.Value5
				 ELSE raptr.Value6
			END), 0) AS 'MaxRent',
			apa.OverIncomePercent AS 'OverIncomePercent',
			apa.RentLimitPercent AS 'RentLimitPercent',
			apa.IsHighHome AS 'IsHighHome',
			apa.Before1981 AS 'Before1981'
		FROM Certification c
			INNER JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
			INNER JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
			INNER JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID AND ap.IsHUD = 0
			INNER JOIN #CertificationCounter cc ON c.CertificationID = cc.CertificationID
			INNER JOIN #Certifications ct on c.CertificationID = ct.CertificationID
			LEFT JOIN AffordableProgramTableGroup aptg on ap.IncomeAffordableProgramTableGroupID = aptg.AffordableProgramTableGroupID
			LEFT JOIN AffordableProgramTable iapt ON (SELECT TOP 1 AffordableProgramTableID
															FROM AffordableProgramTable
															WHERE AffordableProgramTableGroupID = aptg.AffordableProgramTableGroupID
																AND EffectiveDate <= c.EffectiveDate 
																AND [Type] = 'Income'
															ORDER BY EffectiveDate DESC) = iapt.AffordableProgramTableID AND iapt.[Type] = 'Income'
			LEFT JOIN AffordableProgramTableRow iaptr ON iapt.AffordableProgramTableID = iaptr.AffordableProgramTableID AND apa.AmiPercent = iaptr.[Percent]
			LEFT JOIN AffordableProgramTable rapt ON iaptr.AffordableProgramTableID = rapt.ParentAffordableProgramTableID AND rapt.[Type] = 'Rent'
			LEFT JOIN AffordableProgramTableRow raptr ON rapt.AffordableProgramTableID = raptr.AffordableProgramTableID AND ((apa.RentLimitPercent IS NOT NULL AND apa.RentLimitPercent = raptr.[Percent]) OR (apa.RentLimitPercent IS NULL AND apa.AmiPercent = raptr.[Percent]))
		WHERE c.AccountID = @accountID
			AND (c.CertificationID IN (SELECT Value FROM @certificationIDs))

		UNION

		SELECT
			c.CertificationID AS 'CertificationID',
			apa.AffordableProgramID AS 'AffordableProgramID',
			apa.AffordableProgramAllocationID AS 'AffordableProgramAllocationID',
			ap.IsHUD AS 'IsHUD',
			ap.Name AS 'ProgramName',
			apa.Name AS 'AllocationName',
			ap.[Type] AS 'ProgramType',
			apa.SubsidyType AS 'SubsidyType',
			apa.ContractNumber AS 'ContractNumber',
			apa.UnitAmount AS 'UnitAmount',
			(CASE WHEN (apa.SubsidyType = 'Section 8') THEN [dbo].[CalculateSection8AMI](c.CertificationID, @accountID, @passbookRate, @assetImputationLimit)
				ELSE apa.AmiPercent
			END) AS 'AmiPercent',
			ISNULL((CASE WHEN (cc.ResidentCount = 1) THEN iaptr.Value1
				 WHEN (cc.ResidentCount = 2) THEN iaptr.Value2
				 WHEN (cc.ResidentCount = 3) THEN iaptr.Value3
				 WHEN (cc.ResidentCount = 4) THEN iaptr.Value4
				 WHEN (cc.ResidentCount = 5) THEN iaptr.Value5
				 WHEN (cc.ResidentCount = 6) THEN iaptr.Value6
				 WHEN (cc.ResidentCount = 7) THEN iaptr.Value7
				 ELSE iaptr.Value8
			END), 0) AS 'IncomeLimit',
			ISNULL((CASE WHEN (ct.NumberOfBedrooms = 0) THEN raptr.Value1
				 WHEN (ct.NumberOfBedrooms = 1) THEN raptr.Value2
				 WHEN (ct.NumberOfBedrooms = 2) THEN raptr.Value3
				 WHEN (ct.NumberOfBedrooms = 3) THEN raptr.Value4
				 WHEN (ct.NumberOfBedrooms = 4) THEN raptr.Value5
				 ELSE iaptr.Value6
			END), 0) AS 'MaxRent',
			apa.OverIncomePercent AS 'OverIncomePercent',
			apa.RentLimitPercent AS 'RentLimitPercent',
			apa.IsHighHome AS 'IsHighHome',
			apa.Before1981 AS 'Before1981'
		FROM Certification c
			INNER JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
			INNER JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
			INNER JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID AND ap.IsHUD = 1
			INNER JOIN #CertificationCounter cc ON c.CertificationID = cc.CertificationID
			INNER JOIN #Certifications ct on c.CertificationID = ct.CertificationID
			INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			LEFT JOIN AffordableProgramTable iapt ON iapt.[Type] = 'Income'
					AND iapt.AffordableProgramTableID = (SELECT TOP 1 t.AffordableProgramTableID
															FROM AffordableProgramTableGroup g JOIN AffordableProgramTable t ON g.AffordableProgramTableGroupID = t.AffordableProgramTableGroupID
															WHERE g.IsHUD = 1
																AND t.EffectiveDate <= c.EffectiveDate
																AND t.[Type] = 'Income'
																AND g.PropertyID = b.PropertyID
															ORDER BY t.EffectiveDate DESC)
			LEFT JOIN AffordableProgramTableRow iaptr ON iapt.AffordableProgramTableID = iaptr.AffordableProgramTableID AND ((apa.SubsidyType = 'Section 8' AND [dbo].[CalculateSection8AMI](c.CertificationID, @accountID, @passbookRate, @assetImputationLimit) = iaptr.[Percent]) OR (apa.SubsidyType <> 'Section 8' AND apa.AmiPercent = iaptr.[Percent])) -- Match on Certification.AMI for Section 8 certifications, otherwise match on AffordableProgramAllocation.AmiPercent
			LEFT JOIN AffordableProgramTable rapt ON iaptr.AffordableProgramTableID = rapt.ParentAffordableProgramTableID AND rapt.[Type] = 'Rent'
			LEFT JOIN AffordableProgramTableRow raptr ON rapt.AffordableProgramTableID = raptr.AffordableProgramTableID AND ((apa.RentLimitPercent IS NOT NULL AND apa.RentLimitPercent = raptr.[Percent]) OR (apa.RentLimitPercent IS NULL AND apa.AmiPercent = raptr.[Percent]))
		WHERE c.AccountID = @accountID
			AND (c.CertificationID IN (SELECT Value FROM @certificationIDs))

	INSERT INTO #CertificationStatuses
		SELECT
			c.CertificationID AS 'CertificationID',
			cs.CertificationStatusID AS 'CertificationStatusID',
			cs.[Status] AS 'Status',
			cs.Notes AS 'Notes',
			cs.PersonID AS 'PersonID',
			p.PreferredName + ' ' + p.LastName AS 'PersonName',
			cs.DateCreated AS 'DateCreated'
		FROM Certification c
			INNER JOIN CertificationStatus cs ON c.CertificationID = cs.CertificationID
			INNER JOIN Person p ON cs.PersonID = p.PersonID
		WHERE c.AccountID = @accountID
			AND (c.CertificationID IN (SELECT Value FROM @certificationIDs))

	INSERT INTO #Employments EXEC AFF_GetResidentEmployments @accountID, @personIDs

	INSERT INTO #Assets EXEC AFF_GetResidentAssets @accountID, @personIDs
	
	INSERT INTO #Expenses EXEC AFF_GetResidentExpenses @accountID, @personIDs



	SELECT * FROM #Certifications
	SELECT * FROM #Residents
	SELECT * FROM #AffordableProgramAllocations
	SELECT * FROM #CertificationStatuses
	SELECT * FROM #Employments
	SELECT * FROM #Assets
	SELECT * FROM #Expenses
	
	SELECT c.*, p.PreferredName + ' ' + p.LastName AS 'PersonName' FROM CertificationSalary c
			JOIN Person p ON c.PersonID = p.PersonID
			WHERE c.AccountID = @accountID
			AND (c.CertificationID IN (SELECT Value FROM @certificationIDs))
			
	SELECT av.AssetID, c.*, p.PreferredName + ' ' + p.LastName AS 'PersonName' FROM CertificationAsset c
			JOIN AssetValue av ON av.AssetValueID = c.AssetValueID
			JOIN Person p ON c.PersonID = p.PersonID
			WHERE c.AccountID = @accountID
			AND (c.CertificationID IN (SELECT Value FROM @certificationIDs))
			
	SELECT c.*, p.PreferredName + ' ' + p.LastName AS 'PersonName' FROM CertificationExpense c
			JOIN Person p ON c.PersonID = p.PersonID
			WHERE c.AccountID = @accountID
			AND (c.CertificationID IN (SELECT Value FROM @certificationIDs))
END
GO
