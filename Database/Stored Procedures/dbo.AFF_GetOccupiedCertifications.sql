SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[AFF_GetOccupiedCertifications] 
	@accountID bigint,
	@date datetime,
	@propertyIDs GuidCollection READONLY,
	@passbookRate DECIMAL,
	@assetImputationLimit INT
AS

DECLARE @accountingPeriodID uniqueidentifier = null

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	CREATE TABLE #PropertyIDs ( PropertyID uniqueidentifier )
	INSERT INTO #PropertyIDs
		SELECT Value FROM @propertyIDs

	CREATE TABLE #Properties (
		PropertyID uniqueidentifier not null,
		Name nvarchar(50) not null,
		Abbreviation nvarchar(8) not null,
		EnableTaxCreditFeatures bit not null,
		EnableHUDFeatures bit not null
	)

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

	CREATE TABLE #Buildings (
		BuildingID uniqueidentifier not null,
		Name nvarchar(15) not null,
		PropertyID uniqueidentifier not null,
		ApplicableFraction decimal(18,2) null
	)

	CREATE TABLE #Units (
		UnitID uniqueidentifier not null,
		UnitNumber nvarchar (20) not null,
		PaddedUnitNumber nvarchar (20) not null,
		PropertyID uniqueidentifier not null,
		BuildingID uniqueidentifier not null,
		OccupiedUnitLeaseGroupID uniqueidentifier null,
		IsMarket bit not null,
		IsExempt bit not null,
		IsEmployee bit not null,
		OccupiedLeaseID uniqueidentifier null,
		UnitTypeID uniqueidentifier not null,
		UnitTypeName nvarchar (250) not null,
		Bedrooms int not null,
		Bathrooms decimal (3,1) not null,
		UtilityAllowance int null,
		MarketRent money null,
		ContractRent int null,
		HeadOfHousehold nvarchar(81) null,
		MoveInDate date null
	)

	CREATE TABLE #Certifications (
		CertificationID uniqueidentifier not null,
		LeaseID uniqueidentifier not null,
		UnitLeaseGroupID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		UnitID uniqueidentifier not null,
		AffordableProgramAllocationID uniqueidentifier null,
		TenantRent money null,
		HapAmount money null,
		Section8AMI int null,
        IsHud bit not null
	)

	CREATE TABLE #Allocations (
		AffordableProgramAllocationID uniqueidentifier not null,
		PropertyID uniqueidentifier not null,
		ProgramName nvarchar(50) null,
		ProgramType nvarchar(20) null,
		AllocationName nvarchar(50) null,
		SubsidyType nvarchar(20) null,
		ContractNumberOfUnits int null,
		UnitAmount int null,
		UnitAmountIsPercent bit not null,
		ContractNumber nvarchar(20) null,
		IsHud bit not null,
		IsUnitAmountForAllBuildings bit not null
	)

	INSERT #Properties
		SELECT
			p.PropertyID,
			p.[Name],
			p.Abbreviation,
			p.EnableTaxCreditFeatures,
			p.EnableHUDFeatures
		FROM Property p
			INNER JOIN #PropertyIDs #pid ON #pid.PropertyID = p.PropertyID
		WHERE p.AccountID = @accountID

	INSERT #LeasesAndUnits
		EXEC GetConsolodatedOccupancyNumbers @accountID, @date, @accountingPeriodID, @propertyIDs

	INSERT #Buildings
		SELECT
			b.BuildingID AS 'BuildingID',
			b.[Name] AS 'Name',
			p.PropertyID AS 'PropertyID',
			b.ApplicableFraction AS 'ApplicableFraction'
		FROM Building b
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN #PropertyIDs #pid ON #pid.PropertyID = p.PropertyID
		WHERE b.AccountID = @accountID

	INSERT #Units
		SELECT
			u.UnitID AS 'UnitID',
			u.Number AS 'UnitNumber',
			u.PaddedNumber AS 'PaddedUnitNumber',
			p.PropertyID AS 'PropertyID',
			u.BuildingID AS 'BuildingID',
			#lau.OccupiedUnitLeaseGroupID AS 'OccupiedUnitLeaseGroupID',
			u.IsMarket AS 'IsMarket',
			u.IsExempt AS 'IsExempt',
			u.IsEmployee AS 'IsEmployee',
			#lau.OccupiedLastLeaseID AS 'OccupiedLeaseID',
			ut.UnitTypeID AS 'UnitTypeID',
			ut.[Name] AS 'UnitTypeName',
			ut.Bedrooms AS 'Bedrooms',
			ut.Bathrooms AS 'Bathrooms',
			null AS 'UtilityAllowance',
			[MarketRent].Amount,
			null AS 'ContractRent',
			null AS 'HeadOfHousehold',
			null AS 'MoveInDate'
		FROM Unit u
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN #PropertyIDs #pid ON #pid.PropertyID = p.PropertyID
			LEFT JOIN #LeasesAndUnits #lau ON u.UnitID = #lau.UnitID
			INNER JOIN UnitType ut ON u.UnitTypeID = ut.UnitTypeID
			CROSS APPLY GetMarketRentByDate(u.UnitID, @date, 0) [MarketRent]
		WHERE u.AccountID = @accountID
			AND (u.DateRemoved IS NULL OR u.DateRemoved > @date)
			AND u.IsExempt = 0
			AND u.ExcludedFromOccupancy = 0
			AND u.IsHoldingUnit = 0

	UPDATE #Units SET ContractRent = (SELECT TOP 1 cr.Amount
											FROM ContractRent cr
											WHERE cr.ObjectID = #Units.UnitTypeID
												AND cr.DateChanged <= @date
											ORDER BY cr.DateChanged DESC)

	UPDATE #Units
		SET HeadOfHousehold = p.LastName + ', ' + p.PreferredName,
			MoveInDate = pl.MoveInDate
		FROM Person p
			INNER JOIN PersonLease pl ON p.PersonID = pl.PersonID
		WHERE #Units.OccupiedLeaseID = pl.LeaseID
			AND pl.HouseholdStatus = 'Head of Household'

	UPDATE #Units SET UtilityAllowance = (SELECT TOP 1 ua.Amount
											FROM UtilityAllowance ua 
											WHERE ua.ObjectID = #Units.UnitID
												AND ua.DateChanged <= @date
											ORDER BY ua.DateChanged DESC)

	UPDATE #Units SET UtilityAllowance = (SELECT TOP 1 ua.Amount
											FROM UtilityAllowance ua 
											WHERE ua.ObjectID = #Units.UnitTypeID
												AND ua.DateChanged <= @date
											ORDER BY ua.DateChanged DESC)
					WHERE UtilityAllowance IS NULL

	INSERT #Certifications
		SELECT
			c.CertificationID AS 'CertificationID',
			c.LeaseID AS 'LeaseID',
			c.UnitLeaseGroupID AS 'UnitLeaseGroupID',
			p.PropertyID AS 'PropertyID',
			u.UnitID AS 'UnitID',
			apa.AffordableProgramAllocationID AS 'AffordableProgramAllocationID',
			ISNULL(c.HUDTenantRent, c.TaxCreditTenantRent) AS 'TenantRent',
			ISNULL(c.HUDAssistancePayment, c.TaxCreditRentalAssistance) AS 'HapAmount',
			(CASE WHEN (apa.SubsidyType = 'Section 8') THEN [dbo].[CalculateSection8AMI](c.CertificationID, @accountID, @passbookRate, @assetImputationLimit)
				ELSE null
			END) as 'Section8AMI',
			ap.IsHUD as 'IsHud'
		FROM Certification c
			INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN #PropertyIDs #pid ON #pid.PropertyID = p.PropertyID
			LEFT JOIN CertificationAffordableProgramAllocation capa ON c.CertificationID = capa.CertificationID
			LEFT JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
			INNER JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
			INNER JOIN #LeasesAndUnits #lau ON C.UnitLeaseGroupID = #lau.OccupiedUnitLeaseGroupID
		WHERE c.AccountID = @accountID
			AND c.CertificationID IN (SELECT TOP 1 c2.CertificationID
										FROM Certification c2
										WHERE c2.CertificationGroupID = c.CertificationGroupID
											AND c2.EffectiveDate < @date
											AND c2.DateCompleted IS NOT NULL
											AND (SELECT COUNT(cs.CertificationStatusID)
																FROM CertificationStatus cs
																WHERE cs.CertificationID = c2.CertificationID
																	AND cs.[Status] = 'Cancelled') = 0
									ORDER BY c2.EffectiveDate DESC)

	INSERT #Allocations
		SELECT
			apa.AffordableProgramAllocationID AS 'AffordableProgramAllocationID',
			ap.PropertyID AS 'PropertyID',
			ap.[Name] AS 'ProgramName',
			ap.[Type] AS 'ProgramType',
			apa.[Name] AS 'AllocationName',
			apa.SubsidyType AS 'SubsidyType',
			apa.NumberOfUnits AS 'ContractNumberOfUnits',
			apa.UnitAmount AS 'UnitAmount',
			apa.UnitAmountIsPercent AS 'UnitAmountIsPercent',
			apa.ContractNumber AS 'ContractNumber',
			ap.IsHUD AS 'IsHUD',
			apa.IsUnitAmountForAllBuildings AS 'IsUnitAmountForAllBuildings'
		FROM AffordableProgramAllocation apa 
			INNER JOIN AffordableProgram ap ON apa.AffordableProgramID = ap.AffordableProgramID
			INNER JOIN Property p ON ap.PropertyID = p.PropertyID
			INNER JOIN #PropertyIDs #pid ON #pid.PropertyID = p.PropertyID
		WHERE apa.AccountID = @accountID
			AND (ap.EndDate IS NULL OR ap.EndDate > @date)
			AND (apa.ExpirationDate IS NULL OR apa.ExpirationDate > @date)

	SELECT * FROM #Properties ORDER BY Name
	SELECT * FROM #Buildings ORDER BY Name
	SELECT * FROM #Units ORDER BY PaddedUnitNumber
	SELECT * FROM #Certifications
	SELECT * FROM #Allocations ORDER BY IsHud, ProgramName, SubsidyType
	SELECT * FROM AffordableProgramAllocationBuilding apab
		WHERE apab.BuildingID IN (SELECT BuildingID
									FROM #Buildings)
END
GO
