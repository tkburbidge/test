SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[AFF_GetIncomeTargeting] 
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
		PropertyID uniqueidentifier,
		AmiPercent int null
	)

	CREATE TABLE #IncomeTargeting (
		PropertyID uniqueidentifier not null,
		PropertyName nvarchar(50) not null,
		EliCount int not null,
		VliCount int not null,
		LiCount int not null,
		OiCount int not null
	)

	INSERT #PropertiesAndDates 
		SELECT #pids.PropertyID, COALESCE(pap.StartDate, @startDate), COALESCE(pap.EndDate, @endDate)
			FROM #PropertyIDs #pids 
				LEFT JOIN PropertyAccountingPeriod pap ON #pids.PropertyID = pap.PropertyID AND pap.AccountingPeriodID = @accountingPeriodID

	-- Get completed initial/move-in certs within the date range
	INSERT #Certifications
		SELECT
			p.PropertyID AS 'PropertyID',
			(CASE WHEN (apa.SubsidyType = 'Section 8') THEN [dbo].[CalculateSection8AMI](c.CertificationID, @accountID, @passbookRate, @assetImputationLimit)
				ELSE apa.AmiPercent
			END) AS 'AmiPercent'
			FROM Certification c
			INNER JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			INNER JOIN Unit u ON ulg.UnitID = u.UnitID
			INNER JOIN Building b ON u.BuildingID = b.BuildingID
			INNER JOIN Property p ON b.PropertyID = p.PropertyID
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID
			INNER JOIN CertificationAffordableProgramAllocation capa ON C.CertificationID = capa.CertificationID
			INNER JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
			INNER JOIN AffordableProgram ap ON ap.AffordableProgramID = apa.AffordableProgramID
		WHERE c.AccountID = @accountID
			AND c.DateCompleted IS NOT NULL
			AND c.EffectiveDate >= #pad.StartDate
			AND c.EffectiveDate <= #pad.EndDate
			AND c.[Type] IN ('Initial', 'Move-in')
			AND (SELECT COUNT(cs.CertificationStatusID)
					FROM CertificationStatus cs
					WHERE cs.CertificationID = c.CertificationID
						AND cs.[Status] = 'Cancelled') = 0
			AND apa.AmiPercent IS NOT NULL
			AND ap.IsHUD = 1

	INSERT #IncomeTargeting
		SELECT
			p.PropertyID AS 'PropertyID',
			p.Name,
			0 AS 'EliCount',
			0 AS 'VliCount',
			0 AS 'LiCount',
			0 AS 'OiCount'
		FROM Property p
			INNER JOIN #PropertiesAndDates #pad ON #pad.PropertyID = p.PropertyID

		UPDATE #IncomeTargeting
			SET EliCount = (SELECT COUNT (*)
							FROM #Certifications c
							WHERE #IncomeTargeting.PropertyID = c.PropertyID
								AND c.AmiPercent <= 30)

		UPDATE #IncomeTargeting 
			SET VliCount = (SELECT COUNT (*)
							FROM #Certifications c
							WHERE #IncomeTargeting.PropertyID = c.PropertyID
								AND c.AmiPercent <= 50
								AND c.AmiPercent > 30)

		UPDATE #IncomeTargeting 
			SET LiCount = (SELECT COUNT (*)
							FROM #Certifications c
							WHERE #IncomeTargeting.PropertyID = c.PropertyID
								AND c.AmiPercent <= 80
								AND c.AmiPercent > 50)

		UPDATE #IncomeTargeting 
			SET OiCount = (SELECT COUNT (*)
							FROM #Certifications c
							WHERE #IncomeTargeting.PropertyID = c.PropertyID
								AND c.AmiPercent > 80)

	SELECT * FROM #IncomeTargeting
END
GO
