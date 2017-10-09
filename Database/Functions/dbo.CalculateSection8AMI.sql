SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[CalculateSection8AMI]
(
	-- Add the parameters for the function here
	@certificationID UNIQUEIDENTIFIER,
	@accountID BIGINT,
	@passbookRate DECIMAL,
	@assetImputationLimit INT
)
RETURNS INT
AS
BEGIN
	IF (SELECT COUNT(*) FROM CertificationAffordableProgramAllocation capa 
							 JOIN AffordableProgramAllocation apa ON capa.AffordableProgramAllocationID = apa.AffordableProgramAllocationID
							 WHERE CertificationID = @certificationID AND apa.SubsidyType = 'Section 8' AND capa.AccountID = @accountID) > 0
	BEGIN
 
		DECLARE @employments BIGINT
		DECLARE @assets TABLE(
			CashValueSum BIGINT,
			AnnualIncomeSum BIGINT)
		DECLARE @assetValue BIGINT
		DECLARE @income BIGINT
		DECLARE @people INT
		DECLARE @values TABLE (
			[Percent] INT NULL,
			Value1 MONEY NULL,
			Value2 MONEY NULL,
			Value3 MONEY NULL,
			Value4 MONEY NULL,
			Value5 MONEY NULL,
			Value6 MONEY NULL,
			Value7 MONEY NULL,
			Value8 MONEY NULL
		)


		IF (SELECT DateCompleted FROM Certification WHERE CertificationID = @certificationID AND AccountID = @accountID) IS NULL
		BEGIN
			DECLARE @personIDs TABLE (
				PersonID UNIQUEIDENTIFIER
			 )
			DECLARE @certificationEffectiveDate DATETIME = (SELECT EffectiveDate FROM Certification WHERE CertificationID = @certificationID AND AccountID = @accountID)

			INSERT @personIDs SELECT PersonID FROM Certification c 
					JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
					JOIN Lease l ON ulg.UnitLeaseGroupID = l.UnitLeaseGroupID
					JOIN PersonLease pl ON l.LeaseID = pl.LeaseID 
						AND pl.ResidencyStatus NOT IN ('Denied', 'Cancelled', 'Former', 'Evicted', 'Renewed') 
						AND (pl.MoveOutDate IS NULL OR pl.MoveOutDate >= c.effectiveDate)
						WHERE c.CertificationID = @certificationID AND c.AccountID = @accountID

			SET @employments = (SELECT SUM(ROUND(dbo.CalculateAnnual (ISNULL(HudAmount, Amount), s.SalaryPeriod), 0)) FROM @personIDs p
				JOIN Employment e ON p.PersonID = e.PersonID AND (e.EndDate IS NULL OR e.EndDate >= @certificationEffectiveDate)
				CROSS APPLY (SELECT TOP 1 * FROM salary WHERE EmploymentID = e.EmploymentID AND EffectiveDate <= @certificationEffectiveDate ORDER BY EffectiveDate DESC) AS s)
			
			INSERT @assets SELECT SUM(ROUND(CashValue, 0)), SUM(ROUND(ISNULL(HUDAnnualIncome, AnnualIncome), 0)) FROM @personIDs p
				JOIN Asset a ON p.PersonID = a.PersonID AND (a.EndDate IS NULL OR a.EndDate >= @certificationEffectiveDate)
				CROSS APPLY (SELECT TOP 1 * FROM AssetValue WHERE AssetID = a.AssetID AND [date] <= @certificationEffectiveDate ORDER BY [date] DESC) AS av


			IF (SELECT TOP 1 CashValueSum FROM @assets) >= @assetImputationLimit AND (SELECT TOP 1 CashValueSum FROM @assets) * @passbookRate > (SELECT TOP 1 AnnualIncomeSum FROM @assets)
			BEGIN
				SET @assetValue = (SELECT TOP 1 CashValueSum FROM @assets) * @passbookRate
			END 
			ELSE
			BEGIN
				SET @assetValue = (SELECT TOP 1 AnnualIncomeSum FROM @assets)
			END

			SET @income = ISNULL(@employments, 0) + ISNULL(@assetValue, 0)
			
			SET @people = (SELECT (SELECT COUNT(*) FROM @personIDs) + ah.UnbornChildren + ah.ExpectedAdoptions +ah.ExpectedFosterChildren 
			FROM Certification c 
				JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				JOIN AffordableHousehold ah ON ulg.UnitLeaseGroupID = ah.ObjectID
			WHERE CertificationID = @certificationID AND c.AccountID = @accountID) 
		END 
		ELSE
		BEGIN
			SET @employments = (SELECT SUM(ROUND(dbo.CalculateAnnual (ISNULL(HudSalaryAmount, SalaryAmount), Period), 0)) FROM CertificationSalary
					WHERE CertificationID = @certificationID AND AccountID = @accountID)
			
			INSERT @assets SELECT SUM(ROUND(CashValue, 0)), SUM(ROUND(ISNULL(HUDAnnualIncome, AnnualIncome), 0)) FROM CertificationAsset
					WHERE CertificationID = @certificationID AND AccountID = @accountID


			IF (SELECT TOP 1 CashValueSum FROM @assets) >= @assetImputationLimit AND (SELECT TOP 1 CashValueSum FROM @assets) * @passbookRate > (SELECT TOP 1 AnnualIncomeSum FROM @assets)
			BEGIN
				SET @assetValue = (SELECT TOP 1 CashValueSum FROM @assets) * @passbookRate
			END 
			ELSE
			BEGIN
				SET @assetValue = (SELECT TOP 1 AnnualIncomeSum FROM @assets)
			END

			SET @income = ISNULL(@employments, 0) + ISNULL(@assetValue, 0)
			
			SET @people = (SELECT TOP 1 (SELECT COUNT(*) FROM CertificationPerson WHERE CertificationID = c.CertificationID) + ah.UnbornChildren + ah.ExpectedAdoptions +ah.ExpectedFosterChildren 
			FROM Certification c 
				JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
				JOIN AffordableHousehold ah ON ulg.UnitLeaseGroupID = ah.ObjectID
			WHERE CertificationID = @certificationID AND c.AccountID = @accountID) 
		END


		
		INSERT @values SELECT aptr.[Percent], aptr.Value1, aptr.Value2, aptr.Value3, aptr.Value4, aptr.Value5, aptr.Value6, aptr.Value7, aptr.Value8 
		FROM Certification c 
			JOIN UnitLeaseGroup ulg ON c.UnitLeaseGroupID = ulg.UnitLeaseGroupID
			JOIN Unit u ON ulg.UnitID = u.UnitID
			JOIN Building b ON u.BuildingID = b.BuildingID
			JOIN AffordableProgram ap ON b.PropertyID = ap.PropertyID AND ap.IsHUD = 1
			JOIN AffordableProgramAllocation apa ON ap.AffordableProgramID = apa.AffordableProgramID AND apa.SubsidyType = 'Section 8'
			JOIN AffordableProgramTableGroup aptg ON b.PropertyID = aptg.PropertyID AND aptg.IsHUD = 1
			CROSS APPLY (SELECT TOP 1 * FROM AffordableProgramTable apt2
							WHERE aptg.AffordableProgramTableGroupID = apt2.AffordableProgramTableGroupID AND apt2.[Type] = 'Income'
							 ORDER BY apt2.EffectiveDate DESC) as apt
			JOIN AffordableProgramTableRow aptr ON apt.AffordableProgramTableID = aptr.AffordableProgramTableID  
				AND (aptr.[Percent] = 30 OR aptr.[Percent] = 50 OR (aptr.[Percent] = 80 AND apa.Before1981 = 1))
		WHERE CertificationID = @certificationID AND c.AccountID = @accountID
		
		DECLARE @tier INT = (	
			CASE WHEN @people = 0 THEN NULL
				WHEN @people = 1 THEN 
					(SELECT MIN([Percent]) FROM @values WHERE Value1 >= @income)
				WHEN @people = 2 THEN 
					(SELECT MIN([Percent]) FROM @values WHERE Value2 >= @income)
				WHEN @people = 3 THEN 
					(SELECT MIN([Percent]) FROM @values WHERE Value3 >= @income)
				WHEN @people = 4 THEN 
					(SELECT MIN([Percent]) FROM @values WHERE Value4 >= @income)
				WHEN @people = 5 THEN 
					(SELECT MIN([Percent]) FROM @values WHERE Value5 >= @income)
				WHEN @people = 6 THEN 
					(SELECT MIN([Percent]) FROM @values WHERE Value6 >= @income)
				WHEN @people = 7 THEN 
					(SELECT MIN([Percent]) FROM @values WHERE Value7 >= @income)
				WHEN @people > 7 THEN
					(SELECT MIN([Percent]) FROM @values WHERE Value8 >= @income)
			END
		)

		RETURN ISNULL(@tier, (SELECT MAX([Percent]) FROM @values))
	END
	
	RETURN 0
END



GO
