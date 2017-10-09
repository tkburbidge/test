SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[AFF_GetCertificationVerifications]
	@accountID bigint,
	@propertyIDs GuidCollection READONLY,
	@date date,
	@accountingPeriodID uniqueidentifier = null
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @certificationIDs GuidCollection
	DECLARE @personIDs GuidCollection

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		EndDate [Date] NOT NULL)

	CREATE TABLE #Certifications (
		CertificationID uniqueidentifier NOT NULL,
		PropertyID uniqueidentifier NOT NULL,
		IsHud bit not null,
		IsTaxCredit bit not null,
		NeedsVerification bit NOT NULL,
		NeedsSignature bit NOT NULL
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
	

    CREATE TABLE #Verifications
	(
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		VerificationsNeeded int null,
		SignaturesNeeded int null
	)

	INSERT #PropertiesAndDates 
		SELECT #pids.PropertyID, COALESCE(pap.EndDate, @date)
			FROM #PropertyIDs #pids 
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	INSERT #Certifications
		SELECT c.CertificationID,
			#pad.PropertyID,
			0 AS 'IsHud',
			0 AS 'TaxCredit',
			0 AS 'NeedsVerification',
			0 AS 'NeedsSignature'
		FROM Certification c
			INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN #PropertiesAndDates #pad ON b.PropertyID = #pad.PropertyID
			INNER JOIN CertificationStatus cs ON c.CertificationID = cs.CertificationID
		WHERE c.AccountID  = @accountID
			AND c.EffectiveDate <= #pad.EndDate
			AND cs.CertificationStatusID IN (SELECT TOP 1 cs2.CertificationStatusID
												FROM CertificationStatus cs2
												WHERE cs2.CertificationID = cs.CertificationID
												ORDER BY cs2.DateCreated DESC)
			AND cs.[Status] IN ('NotStarted', 'PendingVerification', 'PendingApproval', 'CorrectionsNeeded')

	INSERT @certificationIDs
		SELECT CertificationID
		FROM #Certifications

	UPDATE #c
		SET IsHud = ap.IsHUD
		FROM #Certifications #c
			INNER JOIN CertificationAffordableProgramAllocation capa ON #c.CertificationID = capa.CertificationID
			INNER JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
			INNER JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
		WHERE ap.IsHUD = 1

	UPDATE #c
		SET IsTaxCredit = ~ap.IsHUD
		FROM #Certifications #c
			INNER JOIN CertificationAffordableProgramAllocation capa ON #c.CertificationID = capa.CertificationID
			INNER JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
			INNER JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
		WHERE ap.IsHUD = 0

	UPDATE #c
		SET NeedsSignature = (CASE
								WHEN #c.IsHud = 1 
									AND #c.IsTaxCredit = 1 
									AND (c.NoSignatureReason IS NOT NULL OR (c.Signed50059Date IS NOT NULL AND c.SignedTicDate IS NOT NULL))
									AND c.OwnerSigned50059Date IS NOT NULL
									THEN 0
								WHEN #c.IsHud = 1 
									AND #c.IsTaxCredit = 0
									AND (c.NoSignatureReason IS NOT NULL OR c.Signed50059Date IS NOT NULL)
									AND c.OwnerSigned50059Date IS NOT NULL
									THEN 0
								WHEN #c.IsHud = 0 
									AND #c.IsTaxCredit = 1
									AND (c.NoSignatureReason IS NOT NULL OR c.SignedTicDate IS NOT NULL)
									THEN 0
								ELSE 1
								END)
		FROM #Certifications #c
			INNER JOIN Certification c ON #c.CertificationID = c.CertificationID

	INSERT #Residents EXEC AFF_GetCertificationResidents @accountID, @certificationIDs

	INSERT @personIDs SELECT PersonID FROM #Residents

	UPDATE #c
		SET NeedsVerification = (CASE
									WHEN (SELECT COUNT (*)
											FROM #Residents #r
											WHERE #r.CertificationID = #c.CertificationID
												AND #r.DateVerified IS NULL) <> 0
									THEN 1
									ELSE #c.NeedsVerification
									END)
		FROM #Certifications #c

	INSERT INTO #Assets EXEC AFF_GetResidentAssets @accountID, @personIDs
	
	UPDATE #c
		SET NeedsVerification = (CASE
									WHEN (SELECT COUNT (*)
											FROM #Assets #a
												INNER JOIN #Residents #r ON #a.PersonID = #r.PersonID
											WHERE #r.CertificationID = #c.CertificationID
												AND #a.DateVerified IS NULL
												AND #a.EffectiveDate <= c.EffectiveDate
												AND (#a.EndDate IS NULL OR #a.EndDate > c.EffectiveDate)) <> 0
									THEN 1
									ELSE #c.NeedsVerification
									END)
		FROM #Certifications #c
			JOIN Certification c ON #c.CertificationID = c.CertificationID

	INSERT INTO #Employments EXEC AFF_GetResidentEmployments @accountID, @personIDs

	UPDATE #c
		SET NeedsVerification = (CASE
									WHEN (SELECT COUNT (*)
											FROM #Employments #e
												INNER JOIN #Residents #r ON #e.PersonID = #r.PersonID
											WHERE #r.CertificationID = #c.CertificationID
												AND #e.VerifiedDate IS NULL
												AND #e.SalaryEffectiveDate <= c.EffectiveDate
												AND (#e.EndDate IS NULL OR #e.EndDate > c.EffectiveDate)) <> 0
									THEN 1
									ELSE #c.NeedsVerification
									END)
		FROM #Certifications #c
			JOIN Certification c ON #c.CertificationID = c.CertificationID

	INSERT INTO #Expenses EXEC AFF_GetResidentExpenses @accountID, @personIDs

	UPDATE #c
		SET NeedsVerification = (CASE
									WHEN (SELECT COUNT (*)
											FROM #Expenses #e
												INNER JOIN #Residents #r ON #e.PersonID = #r.PersonID
											WHERE #r.CertificationID = #c.CertificationID
												AND #e.DateVerified IS NULL
												AND #e.AmountEffectiveDate <= c.EffectiveDate
												AND (#e.EndDate IS NULL OR #e.EndDate > c.EffectiveDate)) <> 0
									THEN 1
									ELSE #c.NeedsVerification
									END)
		FROM #Certifications #c
			JOIN Certification c ON #c.CertificationID = c.CertificationID

	INSERT #Verifications
		SELECT #pad.PropertyID AS 'PropertyID',
			p.Name AS 'PropertyName',
			0 AS 'VerificationsNeeded',
			0 AS 'SignaturesNeeded'
		FROM Property p
			INNER JOIN #PropertiesAndDates #pad ON p.PropertyID = #pad.PropertyID
		WHERE p.AccountID = @accountID

	UPDATE #v
		SET VerificationsNeeded = (SELECT COUNT (*)
									FROM #Certifications #c
									WHERE #c.PropertyID = #v.PropertyID
										AND #c.NeedsVerification = 1)
		FROM #Verifications #v

	UPDATE #v
		SET SignaturesNeeded = (SELECT COUNT (*)
									FROM #Certifications #c
									WHERE #c.PropertyID = #v.PropertyID
										AND #c.NeedsSignature = 1)
		FROM #Verifications #v

	SELECT * FROM #Verifications
END
GO
