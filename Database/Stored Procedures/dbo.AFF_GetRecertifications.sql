SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[AFF_GetRecertifications] 
	@accountID bigint,
	@startDate datetime,
	@endDate datetime,
	@propertyIDs GuidCollection READONLY,
	@accountingPeriodID uniqueidentifier = null,
	@passbookRate DECIMAL,
	@assetImputationLimit INT
AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs

	CREATE TABLE #PropertiesAndDates (
		PropertyID uniqueidentifier NOT NULL,
		StartDate [Date] NOT NULL,
		EndDate [Date] NOT NULL)

	CREATE TABLE #Certifications (
		CertificationID uniqueidentifier not null,
		LeaseID uniqueidentifier null,
		UnitLeaseGroupID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar(20) not null,
		PaddedUnitNumber nvarchar(20) not null,
		PersonID uniqueidentifier null,
		HeadOfHousehold nvarchar(100) null,
		InitialEffectiveDate date not null,
		EffectiveDate date not null,
		RecertificationDate date not null,
		[Type] nvarchar(50) not null,
		[Status] nvarchar(50) not null,
		MembersVerified bit not null,
		IncomeNotRequired bit not null,
		IncomesVerified bit not null,
		AssetsVerified bit not null,
		ExpensesVerified bit not null,
		Signed bit not null,
		Programs nvarchar(250) null,
		HasTaxCreditProgram bit not null,
		HasHudProgram bit not null,
		SignedTicDate date null,
		Signed50059Date date null,
		OwnerSigned50059Date date null,
		NoSignatureReason nvarchar(100) null,
		MoveInDate date null
	)

	CREATE TABLE #MostRecentCertifications (
		CertificationID uniqueidentifier not null
	)


	INSERT #PropertiesAndDates 
		SELECT #pids.PropertyID,
			COALESCE(pap.StartDate, @startDate),
			COALESCE(pap.EndDate, @endDate)
			FROM #PropertyIDs #pids 
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	INSERT #MostRecentCertifications
		SELECT c.CertificationID
		FROM CertificationGroup cg 
		CROSS APPLY (SELECT TOP 1 * FROM Certification WHERE cg.CertificationGroupID = CertificationGroupId ORDER BY EffectiveDate, CreatedDate) c
			

	-- Get non-completed recertifications due within the date range
	INSERT #Certifications
		SELECT
			c.CertificationID AS 'CertificationID',
			c.LeaseID AS 'LeaseID',
			c.UnitLeaseGroupID AS 'UnitLeaseGroupID',
			b.PropertyID AS 'PropertyID',
			p.Name AS 'PropertyName',
			ulg.UnitID AS 'UnitID',
			u.Number AS 'UnitNumber',
			u.PaddedNumber AS 'PaddedUnitNumber',
			[HeadOfHousehold].PersonID AS 'PersonID',
			[HeadOfHousehold].HeadOfHousehold AS 'HeadOfHousehold',
			cg.InitialEffectiveDate AS 'InitialEffectiveDate',
			c.EffectiveDate AS 'EffectiveDate',
			c.RecertificationDate AS 'RecertificationDate',
			c.[Type] AS 'Type',
			(SELECT TOP 1 cs.[Status]
				FROM CertificationStatus cs
				WHERE cs.CertificationID = c.CertificationID
				ORDER BY cs.DateCreated DESC) AS 'Status',
			(CASE WHEN EXISTS(SELECT * FROM AffordablePerson ap
								INNER JOIN PersonLease pl ON ap.PersonID = pl.PersonID
								WHERE pl.LeaseID = c.LeaseID
									AND ap.DateVerified IS NULL) THEN 0 ELSE 1 END) AS 'MembersVerified',
			0 AS 'IncomeNotRequired',
			(CASE WHEN ((SELECT COUNT (s.SalaryID)
							FROM Salary s
								INNER JOIN Employment e ON s.EmploymentID = e.EmploymentID
								INNER JOIN Person pe ON e.PersonID = pe.PersonID
								INNER JOIN PersonLease pl ON pe.PersonID = pl.PersonID
							WHERE pl.LeaseID = c.LeaseID
								AND s.DateVerified IS NULL) > 0) THEN 0 ELSE 1 END) AS 'IncomesVerified',
			(CASE WHEN ((SELECT COUNT (av.AssetValueID)
							FROM AssetValue av
								INNER JOIN Asset a ON av.AssetID = a.AssetID
								INNER JOIN Person pe ON a.PersonID = pe.PersonID
								INNER JOIN PersonLease pl ON pe.PersonID = pl.PersonID
							WHERE pl.LeaseID = c.LeaseID
								AND av.DateVerified IS NULL) > 0) THEN 0 ELSE 1 END) AS 'AssetsVerified',
			(CASE WHEN ((SELECT COUNT (aea.AffordableExpenseAmountID)
							FROM AffordableExpenseAmount aea
								INNER JOIN AffordableExpense ae ON aea.AffordableExpenseID = ae.AffordableExpenseID
								INNER JOIN Person pe ON ae.PersonID = pe.PersonID
								INNER JOIN PersonLease pl ON pe.PersonID = pl.PersonID
							WHERE pl.LeaseID = c.LeaseID
								AND aea.DateVerified IS NULL) > 0) THEN 0 ELSE 1 END) AS 'ExpensesVerified',
			0 AS 'Signed',
			null AS 'Programs',
			(CASE WHEN ((SELECT COUNT (ap.AffordableProgramID)
							FROM AffordableProgram ap
								INNER JOIN AffordableProgramAllocation apa ON ap.AffordableProgramID = apa.AffordableProgramID
								INNER JOIN CertificationAffordableProgramAllocation capa ON apa.AffordableProgramAllocationID = capa.AffordableProgramAllocationID
							WHERE capa.CertificationID = c.CertificationID
								AND ap.IsHUD = 0) > 0) THEN 1 ELSE 0 END) AS 'HasTaxCreditProgram',
			(CASE WHEN ((SELECT COUNT (ap.AffordableProgramID)
							FROM AffordableProgram ap
								INNER JOIN AffordableProgramAllocation apa ON ap.AffordableProgramID = apa.AffordableProgramID
								INNER JOIN CertificationAffordableProgramAllocation capa ON apa.AffordableProgramAllocationID = capa.AffordableProgramAllocationID
							WHERE capa.CertificationID = c.CertificationID
								AND ap.IsHUD = 1) > 0) THEN 1 ELSE 0 END) AS 'HasHudProgram',
		c.SignedTicDate AS 'SignedTicDate',
		c.Signed50059Date AS 'Signed50059Date',
		c.OwnerSigned50059Date AS 'OwnerSigned50059Date',
		c.NoSignatureReason AS 'NoSignatureReason',
		[HeadOfHousehold].MoveInDate
		FROM Certification c
			INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			LEFT JOIN (SELECT DISTINCT l.UnitLeaseGroupID,
							pl.PersonID, pe.LastName + ', '+ pe.FirstName AS 'HeadOfHousehold',
							pl.MoveInDate
							FROM PersonLease pl
								INNER JOIN Person pe ON pl.PersonID = pe.PersonID
							INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
						WHERE pl.HouseholdStatus = 'Head of Household') [HeadOfHousehold] ON c.UnitLeaseGroupID = [HeadOfHousehold].UnitLeaseGroupID
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
			INNER JOIN CertificationGroup cg ON c.CertificationGroupID = cg.CertificationGroupID
		WHERE c.AccountID = @accountID
			AND c.DateCompleted IS NULL
			AND c.EffectiveDate >= #pad.StartDate
			AND c.EffectiveDate <= #pad.EndDate
			AND c.[Type] = 'Recertification'
			AND (SELECT COUNT(cs.CertificationStatusID)
					FROM CertificationStatus cs
					WHERE cs.CertificationID = c.CertificationID
						AND cs.[Status] = 'Cancelled') = 0
			AND c.CertificationID IN (SELECT CertificationID FROM #MostRecentCertifications)
			AND ([HeadOfHousehold] IS NULL OR [HeadOfHousehold].PersonID IN (SELECT TOP 1 PersonID
																				FROM PersonLease pl
																					JOIN Lease l ON pl.LeaseID = l.LeaseID
																				WHERE l.UnitLeaseGroupID = c.UnitLeaseGroupID
																					AND pl.HouseholdStatus = 'Head of Household'
																				ORDER BY pl.MoveInDate))

	-- Get the most-recent initial, interim, and recert certifications that have a recertification date within the date range
	INSERT #Certifications
		SELECT
			c.CertificationID AS 'CertificationID',
			c.LeaseID AS 'LeaseID',
			c.UnitLeaseGroupID AS 'UnitLeaseGroupID',
			b.PropertyID AS 'PropertyID',
			p.Name AS 'PropertyName',
			ulg.UnitID AS 'UnitID',
			u.Number AS 'UnitNumber',
			u.PaddedNumber AS 'PaddedUnitNumber',
			[HeadOfHousehold].PersonID AS 'PersonID',
			[HeadOfHousehold].HeadOfHousehold AS 'HeadOfHousehold',
			cg.InitialEffectiveDate AS 'InitialEffectiveDate',
			c.EffectiveDate AS 'EffectiveDate',
			c.RecertificationDate AS 'RecertificationDate',
			c.[Type] AS 'Type',
			'NotStarted' AS 'Status',
			(CASE WHEN EXISTS(SELECT * FROM AffordablePerson ap
								INNER JOIN PersonLease pl ON ap.PersonID = pl.PersonID
								WHERE pl.LeaseID = c.LeaseID
									AND ap.DateVerified IS NULL) THEN 0 ELSE 1 END) AS 'MembersVerified',
			0 AS 'IncomeNotRequired',
			0 AS 'IncomesVerified',
			0 AS 'AssetsVerified',
			0 AS 'ExpensesVerified',
			0 AS 'Signed',
			null AS 'Programs',
			(CASE WHEN ((SELECT COUNT (ap.AffordableProgramID)
							FROM AffordableProgram ap
								INNER JOIN AffordableProgramAllocation apa ON ap.AffordableProgramID = apa.AffordableProgramID
								INNER JOIN CertificationAffordableProgramAllocation capa ON apa.AffordableProgramAllocationID = capa.AffordableProgramAllocationID
							WHERE capa.CertificationID = c.CertificationID
								AND ap.IsHUD = 0) > 0) THEN 1 ELSE 0 END) AS 'HasTaxCreditProgram',
			(CASE WHEN ((SELECT COUNT (ap.AffordableProgramID)
							FROM AffordableProgram ap
								INNER JOIN AffordableProgramAllocation apa ON ap.AffordableProgramID = apa.AffordableProgramID
								INNER JOIN CertificationAffordableProgramAllocation capa ON apa.AffordableProgramAllocationID = capa.AffordableProgramAllocationID
							WHERE capa.CertificationID = c.CertificationID
								AND ap.IsHUD = 1) > 0) THEN 1 ELSE 0 END) AS 'HasHudProgram',
		null AS 'SignedTicDate',
		null AS 'Signed50059Date',
		null AS 'OwnerSigned50059Date',
		null AS 'NoSignatureReason',
		[HeadOfHousehold].MoveInDate
		FROM Certification c
			INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			LEFT JOIN (SELECT DISTINCT l.UnitLeaseGroupID,
							pl.PersonID, pe.LastName + ', '+ pe.FirstName AS 'HeadOfHousehold',
							pl.MoveInDate
							FROM PersonLease pl
								INNER JOIN Person pe ON pl.PersonID = pe.PersonID
							INNER JOIN Lease l ON pl.LeaseID = l.LeaseID
						WHERE pl.HouseholdStatus = 'Head of Household') [HeadOfHousehold] ON c.UnitLeaseGroupID = [HeadOfHousehold].UnitLeaseGroupID
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
			INNER JOIN CertificationGroup cg ON c.CertificationGroupID = cg.CertificationGroupID
		WHERE c.AccountID = @accountID
			AND c.RecertificationDate >= #pad.StartDate
			AND c.RecertificationDate <= #pad.EndDate
			AND (c.[Type] = 'Initial'
				OR c.[Type] = 'Move-in'
				OR c.[Type] = 'Interim'
				OR c.[Type] = 'Recertification'
				OR c.[Type] = 'Gross Rent Change Interim'
				OR c.[Type] = 'Transfer Interim')
			AND (SELECT COUNT(cs.CertificationStatusID)
					FROM CertificationStatus cs
					WHERE cs.CertificationID = c.CertificationID
						AND cs.[Status] = 'Cancelled') = 0
			AND c.CertificationID IN (SELECT CertificationID FROM #MostRecentCertifications)
			AND c.CertificationID NOT IN (SELECT CertificationID FROM #Certifications)
			AND (SELECT COUNT(fl.LeaseID)
					FROM Lease fl
					WHERE fl.UnitLeaseGroupID = c.UnitLeaseGroupID
						AND fl.LeaseStatus IN ('Former', 'Evicted')) = 0
			AND ([HeadOfHousehold] IS NULL OR [HeadOfHousehold].PersonID IN (SELECT TOP 1 PersonID
																				FROM PersonLease pl
																					JOIN Lease l ON pl.LeaseID = l.LeaseID
																				WHERE l.UnitLeaseGroupID = c.UnitLeaseGroupID
																					AND pl.HouseholdStatus = 'Head of Household'
																				ORDER BY pl.MoveInDate))


	UPDATE #Certifications
		SET Programs = (SELECT ProgramName
							FROM GetAffordableProgramName(#Certifications.CertificationID, 1, 1, null, @accountID, @passbookRate, @assetImputationLimit))

	-- Income is required if the program requires recertifications or if the program only requires 1 recertification and there is not a completed recertification for the UnitLeaseGroup
	UPDATE c 
		SET IncomeNotRequired = CASE WHEN ((SELECT TOP 1 ap.FirstYearRecertificationOnly
												FROM AffordableProgram ap
													INNER JOIN AffordableProgramAllocation apa ON ap.AffordableProgramID = apa.AffordableProgramID
													INNER JOIN CertificationAffordableProgramAllocation capa ON apa.AffordableProgramAllocationID = capa.AffordableProgramAllocationID
												WHERE capa.CertificationID = c.CertificationID
													AND apa.AmiPercent IS NOT NULL
												ORDER BY apa.AmiPercent) = 1
											AND (SELECT COUNT(r.CertificationID)
													FROM Certification r
														INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
														INNER JOIN Lease l2 ON ulg.UnitLeaseGroupID = l2.UnitLeaseGroupID
													WHERE l2.LeaseID = c.LeaseID
														AND r.[Type] = 'Recertification'
														AND r.DateCompleted IS NOT NULL) > 0)
										OR
											(SELECT TOP 1 ap.DoesNotRequireRecertification
												FROM AffordableProgram ap
													INNER JOIN AffordableProgramAllocation apa ON ap.AffordableProgramID = apa.AffordableProgramID
													INNER JOIN CertificationAffordableProgramAllocation capa ON apa.AffordableProgramAllocationID = capa.AffordableProgramAllocationID
												WHERE capa.CertificationID = c.CertificationID
													AND apa.AmiPercent IS NOT NULL
												ORDER BY apa.AmiPercent) = 1
									THEN 1
									ELSE 0
								END
		FROM #Certifications c

	UPDATE #Certifications
		SET Signed = CASE WHEN (HasTaxCreditProgram = 1 AND HasHudProgram = 1 AND OwnerSigned50059Date IS NOT NULL AND ((SignedTicDate IS NOT NULL AND Signed50059Date IS NOT NULL) OR NoSignatureReason IS NOT NULL)) THEN 1
						  WHEN (HasTaxCreditProgram = 1 AND HasHudProgram = 0 AND (SignedTicDate IS NOT NULL OR NoSignatureReason IS NOT NULL)) THEN 1
						  WHEN (HasTaxCreditProgram = 0 AND HasHudProgram = 1 AND OwnerSigned50059Date IS NOT NULL AND (Signed50059Date IS NOT NULL OR NoSignatureReason IS NOT NULL)) THEN 1
						  ELSE 0
					 END
		WHERE [Status] = 'NotStarted'

	SELECT * FROM #Certifications ORDER BY RecertificationDate, UnitNumber
END
GO
