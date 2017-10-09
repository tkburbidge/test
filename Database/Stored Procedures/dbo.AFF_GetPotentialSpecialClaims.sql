SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[AFF_GetPotentialSpecialClaims]
	@accountID bigint,
	@propertyID uniqueidentifier,
	@date date
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @rentLedgerItemTypeIDs GuidCollection -- This is used to calculate Unpaid Rent
	DECLARE @residentDamageLedgerItemTypeIDs GuidCollection -- This is used to calculate Tenant Damages

	CREATE TABLE #MoveOutCertifications (
		CertificationID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		EffectiveDate date not null
	)

	CREATE TABLE #MoveInCertifications (
		CertificationID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		EffectiveDate date not null
	)

	CREATE TABLE #ExistingSpecialClaims (
		SpecialClaimID uniqueidentifier not null,
		[Type] nvarchar(100) not null,
		ObjectID uniqueidentifier not null,
		ObjectType nvarchar(20) not null,
		EndDate date not null
	)

	CREATE TABLE #PotentialSpecialClaims (
		PersonID uniqueidentifier null,
		PersonName nvarchar (81) null,
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar (20) not null,
		PaddedUnitNumber nvarchar (20) not null,
		Program nvarchar (20) null,
		[Type] nvarchar (100) not null,
		Amount int not null,
		UnitLeaseGroupID uniqueidentifier null,
		UnitTypeID uniqueidentifier not null,
		ObjectID uniqueidentifier not null,
		ObjectType nvarchar(20) not null,
		AffordableProgramAllocationID uniqueidentifier not null,
		SubsidyType nvarchar(20) not null
	)

	-- This is used to calculate Unpaid Rent and Tenant Damages
	CREATE TABLE #FormerResidents (
		PersonID uniqueidentifier not null,
		PersonName nvarchar(81) not null,
		UnitLeaseGroupID uniqueidentifier not null,
		UnitNumber nvarchar(20) not null,
		PaddedUnitNumber nvarchar(20) not null,
		SubsidyType nvarchar(20) not null,
		UnitID uniqueidentifier not null,
		MoveOutDate date not null,
		CertificationID uniqueidentifier not null
	)

	-- This is used to calculate Unpaid Rent
	CREATE TABLE #OutstandingCharges (
		ObjectID uniqueidentifier not null,
		TransactionID uniqueidentifier not null,
		OriginalAmount money not null,
		TaxAmount money not null,
		UnpaidAmount money not null,
		TaxUnpaidAmount money not null,
		[Description] nvarchar(500) null,
		TransactionDate datetime2 not null,
		GLAccountID uniqueidentifier not null,
		OrderBy smallint null,
		TaxRateGroupID uniqueidentifier null,
		LedgerItemTypeID uniqueidentifier null,
		LedgerItemTypeAbbr nvarchar(50) null,
		GLNumber nvarchar(50) null,
		IsWriteOffable bit not null,
		Notes nvarchar(max) null,
		TaxRateID uniqueidentifier null,
	)

	-- This is used to calculate Regular Vacancy amounts
	CREATE TABLE #UnitStatuses (
		UnitID uniqueidentifier not null,
		[Date] date not null,
		[Status] nvarchar(20) null,
		ContractRentAmount int null,
		DailyContractRent int null
	)

	-- This is used to calculate Regular Vacancy amounts
	CREATE TABLE #UnitNotes (
		UnitID uniqueidentifier not null,
		PickListItemName nvarchar(50) not null,
		CertificationID uniqueidentifier not null,
		StartDate date not null,
		EndDate date null,
		SubsidyType nvarchar(20) not null
	)

	INSERT @rentLedgerItemTypeIDs
		SELECT lit.LedgerItemTypeID
		FROM LedgerItemType lit
		WHERE lit.AccountID = @accountID
			AND lit.IsRent = 1

	INSERT @residentDamageLedgerItemTypeIDs
		SELECT lit.LedgerItemTypeID
		FROM LedgerItemType lit
		WHERE lit.AccountID = @accountID
			AND lit.IsResidentDamage = 1

	INSERT #ExistingSpecialClaims
		SELECT sc.SpecialClaimID,
			sc.[Type],
			sc.ObjectID,
			sc.ObjectType,
			sc.[Date] AS 'EndDate'
		FROM SpecialClaim sc
		WHERE sc.AccountID = @accountID
			AND sc.PropertyID = @propertyID

	-- Get all move-out certs within the past 180 days that have not had a special claim created for them yet
	INSERT #MoveOutCertifications
		SELECT DISTINCT
			c.CertificationID,
			u.UnitID,
			c.EffectiveDate
		FROM Certification c
			JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			JOIN Unit u ON ulg.UnitID = u.UnitID
			JOIN Building b ON u.BuildingID = b.BuildingID
			JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
			JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
		WHERE c.AccountID = @accountID
			AND b.PropertyID = @propertyID
			AND c.[Type] = 'Move-out'
			AND apa.SubsidyType IN ('Section 8', 'Section 202/162 PAC', 'Section 202 PRAC', 'Section 811 PRAC')
			AND c.EffectiveDate > DATEADD(DAY, -180, @date)
			AND c.DateCompleted IS NOT NULL

	-- Get all initial/move-in/market certs that are in the same units as the move-out certs and after the earliest move-out cert for the unit
	INSERT #MoveInCertifications
		SELECT DISTINCT
			c.CertificationID,
			u.UnitID,
			c.EffectiveDate
		FROM Certification c
			JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			JOIN Unit u ON ulg.UnitID = u.UnitID
			JOIN Building b ON u.BuildingID = b.BuildingID
			JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
			JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
			JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
			JOIN #MoveOutCertifications #moc ON ulg.UnitID = #moc.UnitID
		WHERE c.AccountID = @accountID
			AND b.PropertyID = @propertyID
			AND c.[Type] IN ('Move-in', 'Initial', 'Market')
			AND ap.IsHUD = 1
			AND c.EffectiveDate > #moc.EffectiveDate
			AND c.EffectiveDate <= @date
			AND c.DateCompleted IS NOT NULL

	INSERT #UnitNotes
		SELECT DISTINCT
			u.UnitID,
			pli.[Name] AS 'PickListItemName',
			#moc.CertificationID,
			un.[Date] AS 'StartDate',
			null AS 'EndDate',
			apa.SubsidyType
		FROM UnitNote un
			JOIN Unit u ON un.UnitID = u.UnitID
			JOIN PickListItem pli ON un.NoteTypeID = pli.PickListItemID
			JOIN Building b ON u.BuildingID = b.BuildingID
			JOIN #MoveOutCertifications #moc ON u.UnitID = #moc.UnitID
			JOIN CertificationAffordableProgramAllocation capa ON #moc.CertificationID = capa.CertificationID
			JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
		WHERE un.AccountID = @accountID
			AND pli.IsSystem = 1
			AND b.PropertyID = @propertyID
			AND un.[Date] >= #moc.EffectiveDate
			AND un.[Date] <= (ISNULL((SELECT MIN(#mic.EffectiveDate)
								FROM #MoveInCertifications #mic
								WHERE #mic.UnitID = u.UnitID
									AND #mic.EffectiveDate > #moc.EffectiveDate), @date))

	UPDATE #un
		SET EndDate = DATEADD(DAY, -1, (ISNULL((SELECT MIN(#mic.EffectiveDate)
													FROM #MoveInCertifications #mic
													WHERE #mic.UnitID = #un.UnitID
														AND #mic.EffectiveDate > #un.StartDate), DATEADD(DAY, 1, @date))))
		FROM #UnitNotes #un

	INSERT #FormerResidents
		SELECT p.PersonID,
			p.PreferredName + ' ' + p.LastName AS 'PersonName',
			ulg.UnitLeaseGroupID,
			u.Number AS 'UnitNumber',
			u.PaddedNumber AS 'PaddedUnitNumber',
			apa.SubsidyType,
			u.UnitID,
			c.EffectiveDate,
			c.CertificationID AS 'CertificationID'
		FROM PersonLease pl
			JOIN Person p ON pl.PersonID = p.PersonID
			JOIN Lease l ON pl.LeaseID = l.LeaseID
			JOIN Certification c ON l.LeaseID = c.LeaseID
			JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
			JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
			JOIN UnitLeaseGroup ulg ON l.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			JOIN Unit u ON ulg.UnitID = u.UnitID
			JOIN Building b ON u.BuildingID = b.BuildingID
			JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
		WHERE pl.AccountID = @accountID
			AND l.LeaseStatus IN ('Cancelled', 'Former', 'Denied', 'Evicted')
			AND b.PropertyID = @propertyID
			AND pl.HouseholdStatus = 'Head of Household'
			AND ap.IsHUD = 1
			AND c.DateCompleted IS NOT NULL
			AND c.[Type] = 'Move-out'
			AND c.EffectiveDate > DATEADD(DAY, -180, @date)
			AND c.EffectiveDate <= @date

	DECLARE @earliestMoveOutDate date = (SELECT MIN(EffectiveDate) FROM #MoveOutCertifications)

	WHILE @earliestMoveOutDate <= @date
	BEGIN
		INSERT #UnitStatuses
			SELECT DISTINCT
				#moc.UnitID,
				@earliestMoveOutDate AS 'Date',
				null AS 'Status',
				null AS 'ContractRentAmount',
				null AS 'DailyContractRent'
			FROM #MoveOutCertifications #moc

		SET @earliestMoveOutDate = DATEADD(DAY, 1, @earliestMoveOutDate)
	END

	UPDATE #us
		SET [Status] = (SELECT [Status] FROM GetUnitStatusByUnitID(#us.UnitID, #us.[Date]))
		FROM #UnitStatuses #us

	UPDATE #us
		SET ContractRentAmount = cr.Amount
		FROM #UnitStatuses #us
			JOIN Unit u ON #us.UnitID = u.UnitID
			JOIN ContractRent cr ON u.UnitTypeID = cr.ObjectID
		WHERE cr.ContractRentID IN (SELECT TOP 1 ContractRentID
										FROM ContractRent crt
										WHERE crt.ObjectID = u.UnitTypeID
											AND crt.DateChanged <= #us.[Date]
										ORDER BY crt.DateChanged desc, crt.DateCreated desc)

	UPDATE #us
		SET DailyContractRent = ROUND(CAST(#us.ContractRentAmount AS MONEY) / DAY((EOMONTH(#us.[Date]))), 0)
		FROM #UnitStatuses #us

	INSERT #OutstandingCharges EXEC GetOutstandingCharges @accountID, @propertyID, null, 'Lease', 0, @date

	-- Calculate "Unpaid Rent" special claims
	INSERT #PotentialSpecialClaims
		SELECT #fr.PersonID,
			#fr.PersonName,
			#fr.UnitID,
			#fr.UnitNumber,
			#fr.PaddedUnitNumber,
			#fr.SubsidyType AS 'Program',
			'Unpaid Rent' AS 'Type',
			0 AS 'Amount',
			#fr.UnitLeaseGroupID,
			u.UnitTypeID,
			#fr.CertificationID AS 'ObjectID',
			'Certification' AS 'ObjectType',
			capa.AffordableProgramAllocationID AS 'AffordableProgramAllocationID',
			apa.SubsidyType AS 'SubsidyType'
		FROM #FormerResidents #fr
			JOIN Unit u ON #fr.UnitID = u.UnitID
			LEFT JOIN #ExistingSpecialClaims #esc ON #fr.CertificationID = #esc.ObjectID
				AND #esc.ObjectType = 'Certification'
				AND #esc.[Type] = 'Unpaid Rent'
			JOIN #UnitStatuses #us ON u.UnitID = #us.UnitID
			JOIN CertificationAffordableProgramAllocation capa ON #fr.CertificationID = capa.CertificationID
			JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
			JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
		WHERE EXISTS(SELECT * 
						FROM #OutstandingCharges
						WHERE LedgerItemTypeID IN (SELECT Value FROM @rentLedgerItemTypeIDs)
							AND ObjectID = #fr.UnitLeaseGroupID)
			AND #esc.ObjectID IS NULL
			AND #us.[Date] = (SELECT TOP 1 [Date]
								FROM #UnitStatuses
								WHERE UnitID = u.UnitID
									AND [Status] = 'Ready'
									AND [Date] > #fr.MoveOutDate
								ORDER BY [Date])
			AND ap.IsHUD = 1

	UPDATE #psc
		SET Amount = (SELECT SUM(#oc.UnpaidAmount)
							FROM #OutstandingCharges #oc
							WHERE #psc.UnitLeaseGroupID = #oc.ObjectID
								AND #oc.LedgerItemTypeID IN (SELECT Value FROM @rentLedgerItemTypeIDs))
		FROM #PotentialSpecialClaims #psc
		WHERE #psc.[Type] = 'Unpaid Rent'
			
	-- Calculate "Tenant Damages" special claims
	INSERT #PotentialSpecialClaims
		SELECT #fr.PersonID,
			#fr.PersonName,
			#fr.UnitID,
			#fr.UnitNumber,
			#fr.PaddedUnitNumber,
			#fr.SubsidyType AS 'Program',
			'Tenant Damages' AS 'Type',
			0 AS 'Amount',
			#fr.UnitLeaseGroupID,
			u.UnitTypeID,
			#fr.CertificationID AS 'ObjectID',
			'Certification' AS 'ObjectType',
			capa.AffordableProgramAllocationID AS 'AffordableProgramAllocationID',
			apa.SubsidyType AS 'SubsidyType'
		FROM #FormerResidents #fr
			JOIN Unit u ON #fr.UnitID = u.UnitID
			LEFT JOIN #ExistingSpecialClaims #esc ON #fr.CertificationID = #esc.ObjectID
				AND #esc.ObjectType = 'Certification'
				AND #esc.[Type] = 'Tenant Damages'
			JOIN #UnitStatuses #us ON u.UnitID = #us.UnitID
			JOIN CertificationAffordableProgramAllocation capa ON #fr.CertificationID = capa.CertificationID
			JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
			JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
		WHERE EXISTS(SELECT *
						FROM #OutstandingCharges
						WHERE LedgerItemTypeID IN (SELECT Value FROM @residentDamageLedgerItemTypeIDs)
							AND ObjectID = #fr.UnitLeaseGroupID)
			AND #esc.ObjectID IS NULL
			AND #us.[Date] = (SELECT TOP 1 [Date]
								FROM #UnitStatuses
								WHERE UnitID = u.UnitID
									AND [Status] = 'Ready'
									AND [Date] > #fr.MoveOutDate
								ORDER BY [Date])
			AND ap.IsHUD = 1

	UPDATE #psc
		SET Amount = (SELECT SUM(#oc.UnpaidAmount)
							FROM #OutstandingCharges #oc
							WHERE #psc.UnitLeaseGroupID = #oc.ObjectID
								AND #oc.LedgerItemTypeID IN (SELECT Value FROM @residentDamageLedgerItemTypeIDs))
		FROM #PotentialSpecialClaims #psc
		WHERE #psc.[Type] = 'Tenant Damages'

	-- Calculate "Regular Vacancy" special claims
	INSERT #PotentialSpecialClaims
		SELECT DISTINCT
			p.PersonID AS 'PersonID',
			p.PreferredName + ' ' + p.LastName AS 'PersonName',
			u.UnitID,
			u.Number,
			u.PaddedNumber,
			#un.SubsidyType AS 'Program',
			'Regular Vacancy' AS 'Type',
			0 AS Amount,
			null AS 'UnitLeaseGroupID',
			u.UnitTypeID,
			#un.CertificationID AS 'ObjectID',
			'Certification' AS 'ObjectType',
			capa.AffordableProgramAllocationID AS 'AffordableProgramAllocationID',
			apa.SubsidyType AS 'SubsidyType'
		FROM Unit u
			JOIN Building b ON u.BuildingID = b.BuildingID
			JOIN #UnitNotes #un ON u.UnitID = #un.UnitID
			JOIN #FormerResidents #fr ON u.UnitID = #fr.UnitID
			JOIN Certification c ON #fr.CertificationID = c.CertificationID AND #un.CertificationID = c.CertificationID
			JOIN Person p ON c.HeadOfHouseholdPersonID = p.PersonID
			LEFT JOIN #ExistingSpecialClaims #esc ON c.CertificationID = #esc.ObjectID
				AND #esc.ObjectType = 'Certification'
				AND #esc.[Type] = 'Regular Vacancy'
			JOIN #UnitStatuses #us ON u.UnitID = #us.UnitID
			JOIN CertificationAffordableProgramAllocation capa ON #fr.CertificationID = capa.CertificationID
			JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
			JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
		WHERE u.AccountID = @accountID
			AND b.PropertyID = @propertyID
			AND #un.PickListItemName = 'Made Ready'
			AND #us.[Date] = (SELECT TOP 1 [Date]
								FROM #UnitStatuses
								WHERE UnitID = u.UnitID
									AND [Status] = 'Ready'
									AND [Date] > #fr.MoveOutDate
								ORDER BY [Date])
			-- Make sure that either someone has moved into the unit or it's been 60 days since the unit was made ready
			AND (EXISTS (SELECT *
							FROM #UnitNotes #unmi
							WHERE #unmi.UnitID = #un.UnitID
								AND #unmi.PickListItemName = 'Moved In'
								AND #unmi.StartDate > #un.StartDate)
				OR #us.[Date] <= DATEADD(DAY, -60, @date))
			AND #esc.ObjectID IS NULL
			AND #un.StartDate > c.EffectiveDate
			AND ap.IsHUD = 1

	UPDATE #psc
		SET Amount = ISNULL((SELECT ROUND(SUM(DailyContractRent), 0)
						FROM (SELECT TOP(60) #us.DailyContractRent
								FROM #UnitStatuses #us
									JOIN #UnitNotes #un ON #psc.ObjectID = #un.CertificationID
								WHERE [Status] = 'Ready'
									AND #psc.UnitID = #us.UnitID
									AND #us.[Date] >= #un.StartDate
									AND #us.[Date] <= #un.EndDate
									AND #un.PickListItemName = 'Made Ready'
								ORDER BY #us.[Date] DESC) us), 0)
		FROM #PotentialSpecialClaims #psc
		WHERE #psc.[Type] = 'Regular Vacancy'

	DELETE 
		FROM #PotentialSpecialClaims
		WHERE Amount = 0
			
	SELECT DISTINCT *
		FROM #PotentialSpecialClaims
END
GO
